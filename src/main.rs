/*
 * Copyright (c) 2024 Typox Project Contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

use anyhow::{Context, Result};
use clap::{Arg, Command};
use oxigraph::io::RdfFormat;
use oxigraph::model::*;
use oxigraph::store::Store;
use serde_json::Value;
use std::collections::HashMap;
use std::fs;
use std::path::Path;

const VERSION: &str = env!("CARGO_PKG_VERSION");
const XSD_NS: &str = "http://www.w3.org/2001/XMLSchema#";

// XSD datatype constants
const XSD_INTEGER: &str = "http://www.w3.org/2001/XMLSchema#integer";
const XSD_INT: &str = "http://www.w3.org/2001/XMLSchema#int";
const XSD_LONG: &str = "http://www.w3.org/2001/XMLSchema#long";
const XSD_SHORT: &str = "http://www.w3.org/2001/XMLSchema#short";
const XSD_BYTE: &str = "http://www.w3.org/2001/XMLSchema#byte";
const XSD_NON_NEGATIVE_INTEGER: &str = "http://www.w3.org/2001/XMLSchema#nonNegativeInteger";
const XSD_POSITIVE_INTEGER: &str = "http://www.w3.org/2001/XMLSchema#positiveInteger";
const XSD_UNSIGNED_INT: &str = "http://www.w3.org/2001/XMLSchema#unsignedInt";
const XSD_UNSIGNED_LONG: &str = "http://www.w3.org/2001/XMLSchema#unsignedLong";
const XSD_UNSIGNED_SHORT: &str = "http://www.w3.org/2001/XMLSchema#unsignedShort";
const XSD_UNSIGNED_BYTE: &str = "http://www.w3.org/2001/XMLSchema#unsignedByte";
const XSD_DECIMAL: &str = "http://www.w3.org/2001/XMLSchema#decimal";
const XSD_DOUBLE: &str = "http://www.w3.org/2001/XMLSchema#double";
const XSD_FLOAT: &str = "http://www.w3.org/2001/XMLSchema#float";

enum DataSource {
    LocalStore(Store),
    HttpEndpoint(String),
}

#[tokio::main]
async fn main() -> Result<()> {
    let matches = Command::new("typox")
        .version(VERSION)
        .about("Query and load RDF data from Oxigraph stores for Typst")
        .subcommand(
            Command::new("query")
                .about("Query RDF data from an Oxigraph store")
                .arg(
                    Arg::new("store")
                        .short('s')
                        .long("store")
                        .value_name("STORE_URL_OR_PATH")
                        .help("Oxigraph store URL (http://) or file path")
                        .required(true),
                )
                .arg(
                    Arg::new("query")
                        .short('q')
                        .long("query")
                        .value_name("SPARQL_QUERY")
                        .help("SPARQL SELECT query to execute")
                        .required(true),
                )
                .arg(
                    Arg::new("output")
                        .short('o')
                        .long("output")
                        .value_name("OUTPUT_FILE")
                        .help("Output file path (optional, defaults to stdout)")
                        .required(false),
                ),
        )
        .subcommand(
            Command::new("load")
                .about("Load Turtle files into an Oxigraph store")
                .arg(
                    Arg::new("store")
                        .short('s')
                        .long("store")
                        .value_name("STORE_PATH")
                        .help("Path where to create or update the Oxigraph store")
                        .required(true),
                )
                .arg(
                    Arg::new("files")
                        .short('f')
                        .long("files")
                        .value_name("TURTLE_FILES")
                        .help("Turtle files to load (supports glob patterns)")
                        .required(true)
                        .num_args(1..),
                )
                .arg(
                    Arg::new("create")
                        .short('c')
                        .long("create")
                        .help("Create new store (removes existing store if present)")
                        .action(clap::ArgAction::SetTrue),
                )
                .arg(
                    Arg::new("base-iri")
                        .short('b')
                        .long("base-iri")
                        .value_name("BASE_IRI")
                        .help("Base IRI for resolving relative IRIs in Turtle files")
                        .required(false),
                ),
        )
        // Support legacy direct query format for backwards compatibility
        .arg(
            Arg::new("store")
                .short('s')
                .long("store")
                .value_name("STORE_URL_OR_PATH")
                .help("Oxigraph store URL (http://) or file path")
                .required(false),
        )
        .arg(
            Arg::new("query")
                .short('q')
                .long("query")
                .value_name("SPARQL_QUERY")
                .help("SPARQL SELECT query to execute")
                .required(false),
        )
        .arg(
            Arg::new("output")
                .short('o')
                .long("output")
                .value_name("OUTPUT_FILE")
                .help("Output file path (optional, defaults to stdout)")
                .required(false),
        )
        .get_matches();

    match matches.subcommand() {
        Some(("query", query_matches)) => {
            let store_param = query_matches.get_one::<String>("store").unwrap();
            let query = query_matches.get_one::<String>("query").unwrap();
            let output_file = query_matches.get_one::<String>("output");

            let results = execute_query(store_param, query).await?;
            output_results(&results, output_file)?;
        }
        Some(("load", load_matches)) => {
            let store_path = load_matches.get_one::<String>("store").unwrap();
            let files: Vec<&String> = load_matches.get_many::<String>("files").unwrap().collect();
            let create_new = load_matches.get_flag("create");
            let base_iri = load_matches.get_one::<String>("base-iri");

            load_turtle_files(store_path, &files, create_new, base_iri)?;
        }
        _ => {
            // Legacy mode: direct query without subcommand
            if let (Some(store_param), Some(query)) = (
                matches.get_one::<String>("store"),
                matches.get_one::<String>("query"),
            ) {
                let output_file = matches.get_one::<String>("output");
                let results = execute_query(store_param, query).await?;
                output_results(&results, output_file)?;
            } else {
                eprintln!("Error: Use 'typox query' or 'typox load' subcommands, or provide both --store and --query for legacy mode");
                std::process::exit(1);
            }
        }
    }

    Ok(())
}

fn output_results(results: &Value, output_file: Option<&String>) -> Result<()> {
    let json_output = serde_json::to_string_pretty(results)?;

    match output_file {
        Some(file_path) => {
            std::fs::write(file_path, json_output)
                .with_context(|| format!("Failed to write to file: {}", file_path))?;
            println!("Results written to: {}", file_path);
        }
        None => {
            println!("{}", json_output);
        }
    }
    Ok(())
}

fn load_turtle_files(
    store_path: &str,
    files: &[&String],
    create_new: bool,
    base_iri: Option<&String>,
) -> Result<()> {
    let store_path = Path::new(store_path);

    // Handle store creation/cleanup
    if create_new && store_path.exists() {
        println!("Removing existing store at: {}", store_path.display());
        fs::remove_dir_all(store_path).with_context(|| {
            format!("Failed to remove existing store: {}", store_path.display())
        })?;
    }

    // Create parent directory if it doesn't exist
    if let Some(parent) = store_path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("Failed to create parent directory: {}", parent.display()))?;
    }

    // Open or create the store
    let store = if create_new || !store_path.exists() {
        println!("Creating new Oxigraph store at: {}", store_path.display());
        Store::open(store_path)
            .with_context(|| format!("Failed to create store at: {}", store_path.display()))?
    } else {
        println!(
            "Opening existing Oxigraph store at: {}",
            store_path.display()
        );
        Store::open(store_path)
            .with_context(|| format!("Failed to open store at: {}", store_path.display()))?
    };

    let mut total_triples = 0;
    let _base_iri_str = base_iri.map(|s| s.as_str());

    // Load each file
    for file_pattern in files {
        let expanded_files = expand_glob_pattern(file_pattern)?;

        for file_path in expanded_files {
            println!("Loading file: {}", file_path.display());

            let file_content = fs::read(&file_path)
                .with_context(|| format!("Failed to read file: {}", file_path.display()))?;

            let file_reader = std::io::Cursor::new(file_content);

            let triples_before = store.len()?;

            store
                .load_from_reader(RdfFormat::Turtle, file_reader)
                .with_context(|| format!("Failed to load turtle file: {}", file_path.display()))?;

            let triples_after = store.len()?;
            let new_triples = triples_after - triples_before;
            total_triples += new_triples;

            println!("  → Loaded {} triples", new_triples);
        }
    }

    println!(
        "\nSuccessfully loaded {} total triples into store",
        total_triples
    );
    println!("Store now contains {} triples", store.len()?);

    Ok(())
}

fn expand_glob_pattern(pattern: &str) -> Result<Vec<std::path::PathBuf>> {
    use glob::glob;

    let mut paths = Vec::new();

    // If pattern doesn't contain glob characters, treat as single file
    if !pattern.contains('*') && !pattern.contains('?') && !pattern.contains('[') {
        let path = std::path::PathBuf::from(pattern);
        if path.exists() {
            paths.push(path);
        } else {
            anyhow::bail!("File does not exist: {}", pattern);
        }
        return Ok(paths);
    }

    // Use glob to expand pattern
    for entry in glob(pattern).with_context(|| format!("Invalid glob pattern: {}", pattern))? {
        match entry {
            Ok(path) => {
                if path.is_file() {
                    // Check if file has .ttl extension
                    if let Some(ext) = path.extension() {
                        if ext == "ttl" || ext == "turtle" {
                            paths.push(path);
                        }
                    }
                }
            }
            Err(e) => eprintln!("Warning: Error reading path: {}", e),
        }
    }

    if paths.is_empty() {
        anyhow::bail!("No turtle files found matching pattern: {}", pattern);
    }

    paths.sort();
    Ok(paths)
}

async fn execute_query(store_param: &str, query: &str) -> Result<Value> {
    let data_source = connect_to_store(store_param).await?;

    // Extract prefixes from the query for URI shortening
    let prefixes = extract_prefixes(query);

    match data_source {
        DataSource::LocalStore(store) => {
            #[allow(deprecated)]
            let query_results = store
                .query(query)
                .with_context(|| format!("Failed to execute query: {}", query))?;
            format_results(query_results, &prefixes)
        }
        DataSource::HttpEndpoint(endpoint_url) => {
            execute_http_query(&endpoint_url, query, &prefixes).await
        }
    }
}

async fn connect_to_store(store_param: &str) -> Result<DataSource> {
    if store_param.starts_with("http://") || store_param.starts_with("https://") {
        // For HTTP endpoints, just return the URL - we'll validate it when executing queries
        Ok(DataSource::HttpEndpoint(store_param.to_string()))
    } else {
        let path = Path::new(store_param);
        if !path.exists() {
            anyhow::bail!("Store path does not exist: {}", store_param);
        }
        let store = Store::open(path).with_context(|| format!("Failed to open store at: {}", store_param))?;
        Ok(DataSource::LocalStore(store))
    }
}

async fn execute_http_query(endpoint_url: &str, query: &str, prefixes: &HashMap<String, String>) -> Result<Value> {
    let client = reqwest::Client::new();

    // Create form data for SPARQL query
    let mut form = HashMap::new();
    form.insert("query", query);

    let response = client
        .post(endpoint_url)
        .form(&form)
        .header("Accept", "application/sparql-results+json")
        .send()
        .await
        .with_context(|| format!("Failed to send HTTP request to: {}", endpoint_url))?;

    if !response.status().is_success() {
        anyhow::bail!("HTTP request failed with status: {} for endpoint: {}", response.status(), endpoint_url);
    }

    let json_response: Value = response
        .json()
        .await
        .with_context(|| "Failed to parse JSON response from HTTP endpoint")?;

    // Convert SPARQL JSON response directly to our target format
    convert_sparql_json_to_typox_format(json_response, prefixes)
}

fn convert_sparql_json_to_typox_format(json: Value, prefixes: &HashMap<String, String>) -> Result<Value> {
    if let Some(results) = json.get("results").and_then(|r| r.get("bindings")) {
        if let Some(bindings_array) = results.as_array() {
            let mut json_array = Vec::new();

            for binding in bindings_array {
                if let Some(binding_obj) = binding.as_object() {
                    let mut row_object = serde_json::Map::new();

                    for (var, value_obj) in binding_obj {
                        if let Some(value_map) = value_obj.as_object() {
                            if let Some(value_str) = value_map.get("value").and_then(|v| v.as_str()) {
                                let formatted_value = format_http_term_typed(value_str, value_map, prefixes);
                                row_object.insert(var.clone(), formatted_value);
                            }
                        }
                    }

                    json_array.push(Value::Object(row_object));
                }
            }

            if json_array.is_empty() {
                anyhow::bail!("No records found for the given query");
            }

            return Ok(Value::Array(json_array));
        }
    }

    anyhow::bail!("Invalid SPARQL JSON response format")
}

fn format_http_term_typed(value_str: &str, value_map: &serde_json::Map<String, Value>, prefixes: &HashMap<String, String>) -> Value {
    match value_map.get("type").and_then(|t| t.as_str()) {
        Some("uri") => {
            // Try to shorten URI using known prefixes
            for (prefix, namespace) in prefixes {
                if value_str.starts_with(namespace) {
                    return Value::String(format!("{}:{}", prefix, &value_str[namespace.len()..]));
                }
            }
            Value::String(value_str.to_string())
        }
        Some("bnode") => Value::String(format!("_:{}", value_str)),
        Some("literal") => {
            // Handle datatyped literals
            if let Some(datatype) = value_map.get("datatype").and_then(|dt| dt.as_str()) {
                match datatype {
                    "http://www.w3.org/2001/XMLSchema#integer"
                    | "http://www.w3.org/2001/XMLSchema#int"
                    | "http://www.w3.org/2001/XMLSchema#long"
                    | "http://www.w3.org/2001/XMLSchema#short"
                    | "http://www.w3.org/2001/XMLSchema#byte"
                    | "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"
                    | "http://www.w3.org/2001/XMLSchema#positiveInteger"
                    | "http://www.w3.org/2001/XMLSchema#unsignedInt"
                    | "http://www.w3.org/2001/XMLSchema#unsignedLong"
                    | "http://www.w3.org/2001/XMLSchema#unsignedShort"
                    | "http://www.w3.org/2001/XMLSchema#unsignedByte" => {
                        if let Ok(num) = value_str.parse::<i64>() {
                            return Value::Number(serde_json::Number::from(num));
                        }
                    }
                    "http://www.w3.org/2001/XMLSchema#decimal"
                    | "http://www.w3.org/2001/XMLSchema#double"
                    | "http://www.w3.org/2001/XMLSchema#float" => {
                        if let Ok(num) = value_str.parse::<f64>() {
                            if let Some(json_num) = serde_json::Number::from_f64(num) {
                                return Value::Number(json_num);
                            }
                        }
                    }
                    _ => {}
                }
            }

            // Try to parse as number if no explicit datatype or if parsing failed
            if let Ok(num) = value_str.parse::<i64>() {
                Value::Number(serde_json::Number::from(num))
            } else if let Ok(num) = value_str.parse::<f64>() {
                if let Some(json_num) = serde_json::Number::from_f64(num) {
                    Value::Number(json_num)
                } else {
                    Value::String(value_str.to_string())
                }
            } else {
                Value::String(value_str.to_string())
            }
        }
        _ => Value::String(value_str.to_string())
    }
}

fn format_results(
    results: oxigraph::sparql::QueryResults,
    prefixes: &HashMap<String, String>,
) -> Result<Value> {
    match results {
        oxigraph::sparql::QueryResults::Solutions(solutions) => {
            let mut json_array = Vec::new();

            for solution in solutions {
                let solution = solution?;
                let mut row_object = serde_json::Map::new();

                for (var, term) in solution.iter() {
                    let value = format_term_typed(term, prefixes);
                    row_object.insert(var.as_str().to_string(), value);
                }

                json_array.push(Value::Object(row_object));
            }

            if json_array.is_empty() {
                anyhow::bail!("No records found for the given query");
            }

            Ok(Value::Array(json_array))
        }
        _ => {
            anyhow::bail!("Only SELECT queries are supported");
        }
    }
}

fn format_term_typed(term: &Term, prefixes: &HashMap<String, String>) -> Value {
    match term {
        Term::NamedNode(node) => {
            let uri = node.as_str();
            // Try to shorten URI using known prefixes
            for (prefix, namespace) in prefixes {
                if uri.starts_with(namespace) {
                    return Value::String(format!("{}:{}", prefix, &uri[namespace.len()..]));
                }
            }
            Value::String(uri.to_string())
        }
        Term::BlankNode(node) => Value::String(format!("_:{}", node.as_str())),
        Term::Literal(literal) => {
            // Remove language tags, return just the value
            let value_str = literal.value();

            // Check if it's a numeric literal
            let datatype = literal.datatype();
            let datatype_str = datatype.as_str();
            match datatype_str {
                XSD_INTEGER
                | XSD_INT
                | XSD_LONG
                | XSD_SHORT
                | XSD_BYTE
                | XSD_NON_NEGATIVE_INTEGER
                | XSD_POSITIVE_INTEGER
                | XSD_UNSIGNED_INT
                | XSD_UNSIGNED_LONG
                | XSD_UNSIGNED_SHORT
                | XSD_UNSIGNED_BYTE => {
                    if let Ok(num) = value_str.parse::<i64>() {
                        return Value::Number(serde_json::Number::from(num));
                    }
                }
                XSD_DECIMAL | XSD_DOUBLE | XSD_FLOAT => {
                    if let Ok(num) = value_str.parse::<f64>() {
                        if let Some(json_num) = serde_json::Number::from_f64(num) {
                            return Value::Number(json_num);
                        }
                    }
                }
                _ => {}
            }

            // Try to parse as number if no explicit datatype
            if let Ok(num) = value_str.parse::<i64>() {
                Value::Number(serde_json::Number::from(num))
            } else if let Ok(num) = value_str.parse::<f64>() {
                if let Some(json_num) = serde_json::Number::from_f64(num) {
                    Value::Number(json_num)
                } else {
                    Value::String(value_str.to_string())
                }
            } else {
                Value::String(value_str.to_string())
            }
        }
    }
}

fn extract_prefixes(query: &str) -> HashMap<String, String> {
    let mut prefixes = HashMap::new();

    // Add common prefixes
    prefixes.insert(
        "rdf".to_string(),
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#".to_string(),
    );
    prefixes.insert(
        "rdfs".to_string(),
        "http://www.w3.org/2000/01/rdf-schema#".to_string(),
    );
    prefixes.insert(
        "owl".to_string(),
        "http://www.w3.org/2002/07/owl#".to_string(),
    );
    prefixes.insert("xsd".to_string(), XSD_NS.to_string());
    prefixes.insert("foaf".to_string(), "http://xmlns.com/foaf/0.1/".to_string());
    prefixes.insert(
        "dc".to_string(),
        "http://purl.org/dc/elements/1.1/".to_string(),
    );
    prefixes.insert(
        "dcterms".to_string(),
        "http://purl.org/dc/terms/".to_string(),
    );
    prefixes.insert(
        "skos".to_string(),
        "http://www.w3.org/2004/02/skos/core#".to_string(),
    );

    // Parse PREFIX declarations from the query
    for line in query.lines() {
        let line = line.trim();
        if line.to_uppercase().starts_with("PREFIX") {
            if let Some(rest) = line.get(6..).map(|s| s.trim()) {
                if let Some(colon_pos) = rest.find(':') {
                    let prefix = rest[..colon_pos].trim();
                    let remainder = rest[colon_pos + 1..].trim();
                    if remainder.starts_with('<') && remainder.ends_with('>') {
                        let namespace = &remainder[1..remainder.len() - 1];
                        prefixes.insert(prefix.to_string(), namespace.to_string());
                    }
                }
            }
        }
    }

    prefixes
}
