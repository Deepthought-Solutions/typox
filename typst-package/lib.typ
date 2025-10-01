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

/// Load RDF data from an Oxigraph store using SPARQL queries
///
/// This package provides both WASM plugin-based native functions and legacy CLI functions
/// to query RDF data from Oxigraph stores and use the results directly in Typst documents.

// Load the WASM plugin
#let typox = plugin("typox.wasm")

// =============================================================================
// WASM Plugin Functions (Recommended)
// =============================================================================

/// Load turtle data into a named store
/// Parameters:
///   - store-name: String - Name of the store ("memory" for default)
///   - turtle-content: String - Turtle/N3 RDF data
#let oxload-turtle(store-name, turtle-content) = {
  let result = str(typox.load_turtle(bytes(store-name), bytes(turtle-content)))
  if result.starts-with("ERROR:") {
    panic("Failed to load turtle data: " + result)
  }
}

/// Execute SPARQL query against named store
/// Parameters:
///   - store-name: String - Name of the store to query
///   - query: String - SPARQL SELECT query
/// Returns: Array of objects with query results
#let oxquery(store-name, query) = {
  let json-result = str(typox.query(bytes(store-name), bytes(query)))
  if json-result.starts-with("ERROR:") {
    panic("Query failed: " + json-result)
  }
  json(bytes(json-result))
}

/// Clear all data from a store
#let oxclear(store-name) = {
  let result = str(typox.clear_store(bytes(store-name)))
  if result.starts-with("ERROR:") {
    panic("Failed to clear store: " + result)
  }
}

/// List all available stores
#let oxlist-stores() = {
  let stores-json = str(typox.list_stores())
  json(bytes(stores-json))
}

/// Get the size of a store (number of triples)
#let oxstore-size(store-name) = {
  let result = str(typox.get_store_size(bytes(store-name)))
  if result.starts-with("ERROR:") {
    panic("Failed to get store size: " + result)
  }
  int(result)
}

// =============================================================================
// Convenience Functions
// =============================================================================

// Default store operations
#let load-turtle(content) = oxload-turtle("memory", content)
#let query-memory(sparql) = oxquery("memory", sparql)
#let clear-memory() = oxclear("memory")

// =============================================================================
// Legacy CLI Functions (OBSOLETE - For Local Development Only)
// =============================================================================
//
// WARNING: These functions require the Typox CLI binary and will NOT work
// when this package is installed via Typst's package manager.
// They are preserved only for backwards compatibility in local development.
//
// For package users: Use the WASM plugin functions above (oxload-turtle, oxquery, etc.)
// For CLI functionality: Install the Typox binary separately from:
// https://github.com/deepthought-solutions/typox
//
// =============================================================================

/// Load RDF data from an Oxigraph store or HTTP SPARQL endpoint using SPARQL queries
///
/// ⚠️ OBSOLETE: This function requires the Typox CLI binary and only works in local
/// development environments. It will NOT work when installed via @preview/oxload.
/// Use oxload-turtle() and oxquery() instead for package-based usage.
///
/// This function executes a SPARQL query against either a local Oxigraph store or a remote
/// HTTP SPARQL endpoint and returns the results directly in Typst.
///
/// Usage:
/// ```typ
/// #import "typst-package/lib.typ": oxload
///
/// // Query a local Oxigraph store
/// #let local_data = oxload("demo/stores/people", "SELECT ?name ?age WHERE { ?person foaf:name ?name ; foaf:age ?age }")
///
/// // Query a remote SPARQL endpoint
/// #let remote_data = oxload("https://dbpedia.org/sparql", "SELECT ?city ?population WHERE { ?city a dbo:City ; dbo:populationTotal ?population } LIMIT 5")
///
/// #for row in local_data [
///   - Name: #row.name, Age: #row.age
/// ]
/// ```
///
/// Parameters:
/// - store: String - Path to local Oxigraph store or HTTP SPARQL endpoint URL
/// - query: String - SPARQL SELECT query to execute
///
/// Returns: Array of objects with string keys and mixed-type values

#let oxload(store, query) = {
  // Create a deterministic filename for caching based on store and query
  let store-hash = str(calc.rem(hash(store), 1000000))
  let query-hash = str(calc.rem(hash(query), 1000000))
  let filename = ".typox-cache-" + store-hash + "-" + query-hash + ".json"

  // First try to read cached result
  let data = none
  if sys.inputs.at(filename, default: none) != none {
    data = json(filename)
    return data
  }
  // Cache miss, need to execute query

  // Execute the typox binary to get results
  // First try to find typox binary in common locations
  let typox-paths = (
    "../target/release/typox",    // From typst-package/ dir
    "./target/release/typox",     // From project root
    "target/release/typox",       // Relative to current
    "../target/debug/typox",      // Debug build from typst-package/
    "./target/debug/typox",       // Debug build from project root
    "target/debug/typox",         // Debug build relative
    "typox"                       // In PATH
  )

  let typox-cmd = none
  for path in typox-paths {
    // Try to execute each path to see if it exists
    let result = none
    // Test if the binary exists and works by running version check
    let cmd-result = shell(path + " --version", default: "")
    if cmd-result != "" {
      typox-cmd = path
      break
    }
  }

  if typox-cmd == none {
    panic("Could not find typox binary. Please ensure it's built (run 'cargo build --release') and accessible.")
  }

  // Escape query for shell execution
  let escaped-query = query.replace("\"", "\\\"").replace("`", "\\`").replace("$", "\\$")

  // Execute typox command
  let cmd = typox-cmd + " query -s \"" + store + "\" -q \"" + escaped-query + "\" -o " + filename
  let result = shell(cmd)

  // Read the generated file
  if sys.inputs.at(filename, default: none) != none {
    data = json(filename)
    return data
  } else {
    panic("Failed to execute query or read results. Command: " + cmd)
  }
}

/// Load RDF data from a pre-generated JSON file
///
/// ⚠️ OBSOLETE: This function is for use with the Typox CLI binary only.
/// Use oxload-turtle() and oxquery() instead for package-based usage.
///
/// This is a simpler alternative when you want to specify the exact file path.
///
/// Usage:
/// ```bash
/// # Generate the data file:
/// typox -s /path/to/store -q "SELECT ?name ?age WHERE { ?person foaf:name ?name ; foaf:age ?age }" -o my-data.json
/// ```
///
/// ```typ
/// #import "@preview/oxload:0.1.0": oxload-file
/// #let data = oxload-file("my-data.json")
/// ```
///
/// Parameters:
/// - json-file: String - Path to the JSON file containing query results
///
/// Returns: Array of objects with string keys and mixed-type values

#let oxload-file(json-file) = {
  json(json-file)
}