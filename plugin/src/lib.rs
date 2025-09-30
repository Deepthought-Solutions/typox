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

// Typox WASM Plugin - Option 2: Direct oxigraph dependency with WASM target
// Full RDF and SPARQL support using oxigraph as the backend

use wasm_minimal_protocol::{initiate_protocol, wasm_func};
use alloc::{
    collections::BTreeMap,
    format,
    string::{String, ToString},
    vec::Vec,
};
use oxigraph::store::Store;
use oxigraph::io::RdfFormat;
use oxigraph::sparql::QueryResults;
use serde_json::{json, Value};

extern crate alloc;

// Custom getrandom implementation for WASM
// This is required for wasm32-unknown-unknown target
// In getrandom 0.3, we need to provide a function named __getrandom_custom
#[cfg(all(target_arch = "wasm32", target_os = "unknown"))]
pub fn __getrandom_custom(buf: &mut [u8]) -> Result<(), getrandom::Error> {
    // For WASM, we use a simple deterministic RNG based on a counter
    // This is acceptable for our use case since we need deterministic behavior in Typst
    static mut COUNTER: u64 = 0;
    unsafe {
        for byte in buf.iter_mut() {
            COUNTER = COUNTER.wrapping_mul(6364136223846793005).wrapping_add(1);
            *byte = (COUNTER >> 56) as u8;
        }
    }
    Ok(())
}

initiate_protocol!();

use core::sync::atomic::{AtomicBool, Ordering};

// Global state management for WASM plugin
// Using BTreeMap instead of HashMap for no_std compatibility
static mut STORES: Option<BTreeMap<String, Store>> = None;
static INITIALIZED: AtomicBool = AtomicBool::new(false);

// Initialize stores
fn ensure_stores() {
    if !INITIALIZED.load(Ordering::Acquire) {
        unsafe {
            if STORES.is_none() {
                let mut stores = BTreeMap::new();
                // Create default "memory" store
                stores.insert("memory".to_string(), Store::new().unwrap());
                STORES = Some(stores);
                INITIALIZED.store(true, Ordering::Release);
            }
        }
    }
}

// Get mutable reference to stores
fn with_stores_mut<F, R>(f: F) -> Result<R, String>
where
    F: FnOnce(&mut BTreeMap<String, Store>) -> Result<R, String>,
{
    ensure_stores();
    unsafe {
        if let Some(ref mut stores) = STORES {
            f(stores)
        } else {
            Err("Failed to initialize stores".to_string())
        }
    }
}

// Helper function to get or create a store
fn get_or_create_store<'a>(stores: &'a mut BTreeMap<String, Store>, store_name: &str) -> Result<&'a mut Store, String> {
    if !stores.contains_key(store_name) {
        let store = Store::new().map_err(|e| format!("Failed to create store: {}", e))?;
        stores.insert(store_name.to_string(), store);
    }
    stores.get_mut(store_name).ok_or_else(|| "Failed to get store".to_string())
}

// Load Turtle data into a named store
#[wasm_func]
pub fn load_turtle(store_name: &[u8], turtle_data: &[u8]) -> Vec<u8> {
    let store_name = match String::from_utf8(store_name.to_vec()) {
        Ok(name) => name,
        Err(e) => return format!("ERROR: Invalid store name: {}", e).into_bytes(),
    };

    match with_stores_mut(|stores| {
        let store = get_or_create_store(stores, &store_name)?;

        // Parse and load Turtle data
        store
            .load_from_reader(RdfFormat::Turtle, turtle_data)
            .map_err(|e| format!("Failed to parse Turtle data: {}", e))?;

        Ok(())
    }) {
        Ok(_) => b"OK".to_vec(),
        Err(e) => format!("ERROR: {}", e).into_bytes(),
    }
}

// Load RDF/XML data into a named store
#[wasm_func]
pub fn load_rdf_xml(store_name: &[u8], rdf_xml_data: &[u8]) -> Vec<u8> {
    let store_name = match String::from_utf8(store_name.to_vec()) {
        Ok(name) => name,
        Err(e) => return format!("ERROR: Invalid store name: {}", e).into_bytes(),
    };

    match with_stores_mut(|stores| {
        let store = get_or_create_store(stores, &store_name)?;

        // Parse and load RDF/XML data
        store
            .load_from_reader(RdfFormat::RdfXml, rdf_xml_data)
            .map_err(|e| format!("Failed to parse RDF/XML data: {}", e))?;

        Ok(())
    }) {
        Ok(_) => b"OK".to_vec(),
        Err(e) => format!("ERROR: {}", e).into_bytes(),
    }
}

// Load N-Triples data into a named store
#[wasm_func]
pub fn load_ntriples(store_name: &[u8], ntriples_data: &[u8]) -> Vec<u8> {
    let store_name = match String::from_utf8(store_name.to_vec()) {
        Ok(name) => name,
        Err(e) => return format!("ERROR: Invalid store name: {}", e).into_bytes(),
    };

    match with_stores_mut(|stores| {
        let store = get_or_create_store(stores, &store_name)?;

        // Parse and load N-Triples data
        store
            .load_from_reader(RdfFormat::NTriples, ntriples_data)
            .map_err(|e| format!("Failed to parse N-Triples data: {}", e))?;

        Ok(())
    }) {
        Ok(_) => b"OK".to_vec(),
        Err(e) => format!("ERROR: {}", e).into_bytes(),
    }
}

// Execute SPARQL SELECT query against a named store
#[wasm_func]
pub fn query(store_name: &[u8], sparql_query: &[u8]) -> Vec<u8> {
    let store_name = match String::from_utf8(store_name.to_vec()) {
        Ok(name) => name,
        Err(e) => return format!("ERROR: Invalid store name: {}", e).into_bytes(),
    };

    let sparql = match String::from_utf8(sparql_query.to_vec()) {
        Ok(query) => query,
        Err(e) => return format!("ERROR: Invalid SPARQL query: {}", e).into_bytes(),
    };

    match with_stores_mut(|stores| {
        let store = stores
            .get(&store_name)
            .ok_or_else(|| format!("Store '{}' not found", store_name))?;

        // Execute SPARQL query
        let results = store
            .query(&sparql)
            .map_err(|e| format!("SPARQL query execution failed: {}", e))?;

        // Convert results to JSON
        match results {
            QueryResults::Solutions(solutions) => {
                let mut result_rows = Vec::new();

                for solution in solutions {
                    let solution = solution.map_err(|e| format!("Error reading solution: {}", e))?;
                    let mut row = serde_json::Map::new();

                    for (var, term) in solution.iter() {
                        let var_name = var.as_str().to_string();
                        let value = match term {
                            oxigraph::model::Term::NamedNode(n) => Value::String(n.as_str().to_string()),
                            oxigraph::model::Term::BlankNode(b) => Value::String(format!("_:{}", b.as_str())),
                            oxigraph::model::Term::Literal(l) => {
                                // Try to parse as number if it's an integer/decimal
                                if l.datatype() == oxigraph::model::vocab::xsd::INTEGER
                                    || l.datatype() == oxigraph::model::vocab::xsd::INT
                                    || l.datatype() == oxigraph::model::vocab::xsd::LONG {
                                    if let Ok(num) = l.value().parse::<i64>() {
                                        json!(num)
                                    } else {
                                        Value::String(l.value().to_string())
                                    }
                                } else if l.datatype() == oxigraph::model::vocab::xsd::DECIMAL
                                    || l.datatype() == oxigraph::model::vocab::xsd::DOUBLE
                                    || l.datatype() == oxigraph::model::vocab::xsd::FLOAT {
                                    if let Ok(num) = l.value().parse::<f64>() {
                                        json!(num)
                                    } else {
                                        Value::String(l.value().to_string())
                                    }
                                } else if l.datatype() == oxigraph::model::vocab::xsd::BOOLEAN {
                                    if let Ok(b) = l.value().parse::<bool>() {
                                        Value::Bool(b)
                                    } else {
                                        Value::String(l.value().to_string())
                                    }
                                } else {
                                    Value::String(l.value().to_string())
                                }
                            },
                            _ => Value::String(term.to_string()),
                        };
                        row.insert(var_name, value);
                    }

                    result_rows.push(Value::Object(row));
                }

                serde_json::to_string(&result_rows)
                    .map_err(|e| format!("JSON serialization error: {}", e))
            }
            QueryResults::Boolean(b) => {
                Ok(json!({"boolean": b}).to_string())
            }
            QueryResults::Graph(_) => {
                Err("CONSTRUCT queries should use query_construct function".to_string())
            }
        }
    }) {
        Ok(json_result) => json_result.into_bytes(),
        Err(e) => format!("ERROR: {}", e).into_bytes(),
    }
}

// Execute SPARQL CONSTRUCT query against a named store
#[wasm_func]
pub fn query_construct(store_name: &[u8], sparql_query: &[u8]) -> Vec<u8> {
    let store_name = match String::from_utf8(store_name.to_vec()) {
        Ok(name) => name,
        Err(e) => return format!("ERROR: Invalid store name: {}", e).into_bytes(),
    };

    let sparql = match String::from_utf8(sparql_query.to_vec()) {
        Ok(query) => query,
        Err(e) => return format!("ERROR: Invalid SPARQL query: {}", e).into_bytes(),
    };

    match with_stores_mut(|stores| {
        let store = stores
            .get(&store_name)
            .ok_or_else(|| format!("Store '{}' not found", store_name))?;

        // Execute SPARQL query
        let results = store
            .query(&sparql)
            .map_err(|e| format!("SPARQL query execution failed: {}", e))?;

        // Convert graph results to Turtle
        match results {
            QueryResults::Graph(triples) => {
                // Collect all triples and serialize them directly
                use oxigraph::io::RdfSerializer;
                let mut output = Vec::new();
                let mut serializer = RdfSerializer::from_format(RdfFormat::Turtle)
                    .for_writer(&mut output);

                for triple_result in triples {
                    let triple = triple_result.map_err(|e| format!("Error reading triple: {}", e))?;
                    serializer.serialize_triple(triple.as_ref())
                        .map_err(|e| format!("Error serializing triple: {}", e))?;
                }

                serializer.finish().map_err(|e| format!("Error finishing serialization: {}", e))?;

                String::from_utf8(output).map_err(|e| format!("UTF-8 error: {}", e))
            }
            QueryResults::Solutions(_) => {
                Err("SELECT queries should use query function".to_string())
            }
            QueryResults::Boolean(_) => {
                Err("ASK queries should use query_ask function".to_string())
            }
        }
    }) {
        Ok(turtle_result) => turtle_result.into_bytes(),
        Err(e) => format!("ERROR: {}", e).into_bytes(),
    }
}

// Execute SPARQL ASK query against a named store
#[wasm_func]
pub fn query_ask(store_name: &[u8], sparql_query: &[u8]) -> Vec<u8> {
    let store_name = match String::from_utf8(store_name.to_vec()) {
        Ok(name) => name,
        Err(e) => return format!("ERROR: Invalid store name: {}", e).into_bytes(),
    };

    let sparql = match String::from_utf8(sparql_query.to_vec()) {
        Ok(query) => query,
        Err(e) => return format!("ERROR: Invalid SPARQL query: {}", e).into_bytes(),
    };

    match with_stores_mut(|stores| {
        let store = stores
            .get(&store_name)
            .ok_or_else(|| format!("Store '{}' not found", store_name))?;

        // Execute SPARQL query
        let results = store
            .query(&sparql)
            .map_err(|e| format!("SPARQL query execution failed: {}", e))?;

        // Get boolean result
        match results {
            QueryResults::Boolean(b) => Ok(if b { "true" } else { "false" }.to_string()),
            QueryResults::Solutions(_) => {
                Err("SELECT queries should use query function".to_string())
            }
            QueryResults::Graph(_) => {
                Err("CONSTRUCT queries should use query_construct function".to_string())
            }
        }
    }) {
        Ok(result) => result.into_bytes(),
        Err(e) => format!("ERROR: {}", e).into_bytes(),
    }
}

// Clear all data from a store
#[wasm_func]
pub fn clear_store(store_name: &[u8]) -> Vec<u8> {
    let store_name = match String::from_utf8(store_name.to_vec()) {
        Ok(name) => name,
        Err(e) => return format!("ERROR: Invalid store name: {}", e).into_bytes(),
    };

    match with_stores_mut(|stores| {
        let store = stores
            .get_mut(&store_name)
            .ok_or_else(|| format!("Store '{}' not found", store_name))?;

        // Clear the store by removing all quads
        store.clear().map_err(|e| format!("Failed to clear store: {}", e))?;

        Ok(())
    }) {
        Ok(_) => b"OK".to_vec(),
        Err(e) => format!("ERROR: {}", e).into_bytes(),
    }
}

// List all available stores
#[wasm_func]
pub fn list_stores() -> Vec<u8> {
    match with_stores_mut(|stores| {
        let store_names: Vec<String> = stores.keys().cloned().collect();
        serde_json::to_string(&store_names)
            .map_err(|e| format!("JSON serialization error: {}", e))
    }) {
        Ok(json_result) => json_result.into_bytes(),
        Err(e) => format!("ERROR: {}", e).into_bytes(),
    }
}

// Get the size of a store (number of triples)
#[wasm_func]
pub fn get_store_size(store_name: &[u8]) -> Vec<u8> {
    let store_name = match String::from_utf8(store_name.to_vec()) {
        Ok(name) => name,
        Err(e) => return format!("ERROR: Invalid store name: {}", e).into_bytes(),
    };

    match with_stores_mut(|stores| {
        let store = stores
            .get(&store_name)
            .ok_or_else(|| format!("Store '{}' not found", store_name))?;

        // Count quads in the store
        let count = store.len().map_err(|e| format!("Failed to get store size: {}", e))?;

        Ok(count.to_string())
    }) {
        Ok(size_str) => size_str.into_bytes(),
        Err(e) => format!("ERROR: {}", e).into_bytes(),
    }
}
