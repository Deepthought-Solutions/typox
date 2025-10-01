# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Typox is a Rust tool and Typst package for integrating RDF data from Oxigraph stores into Typst documents. It bridges semantic data (RDF/SPARQL) with document generation, offering two implementations:

1. **CLI Version (Stable)**: Full-featured CLI tool with local Oxigraph stores and HTTP SPARQL endpoint support
2. **WASM Plugin (Beta)**: Native Typst integration with in-memory RDF processing

## Build Commands

### CLI Version
```bash
# Build debug version
cargo build

# Build release version (recommended)
cargo build --release

# Install globally
cargo install --path .

# Run tests
cargo test

# Binary location after build
./target/release/typox
```

### WASM Plugin
```bash
# Build WASM plugin (requires wasm32-unknown-unknown target)
./build-wasm.sh

# Manually install WASM target first (if needed)
rustup target add wasm32-unknown-unknown

# Build manually (without script)
cd plugin && cargo build --target wasm32-unknown-unknown --release
```

### Testing
```bash
# Run CLI on test data
cargo run -- query -s /path/to/store -q "SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 5"

# Test WASM plugin by compiling demo
typst compile demo-wasm.typ
```

## Architecture

### Two-Implementation Design

#### CLI (`src/main.rs`)
- **Purpose**: Production-ready querying of RDF stores and HTTP endpoints
- **Data Sources**:
  - Local Oxigraph stores (persistent on-disk RDF databases)
  - HTTP SPARQL endpoints (DBpedia, Wikidata, custom endpoints)
- **Key Components**:
  - `DataSource` enum: Abstracts local vs HTTP data sources
  - `execute_query()`: Unified query execution entry point
  - `format_term_typed()`: Local store RDF term conversion to JSON
  - `format_http_term_typed()`: HTTP endpoint term conversion
  - `extract_prefixes()`: Parses SPARQL queries for URI shortening
- **Subcommands**:
  - `query`: Execute SPARQL SELECT queries
  - `load`: Load Turtle files into local stores

#### WASM Plugin (`plugin/src/lib.rs`)
- **Purpose**: Native Typst integration without external dependencies
- **Architecture**: In-memory stores using oxigraph with custom WASM protocol
- **Global State**: Uses static `BTreeMap<String, Store>` for named stores
- **Key Functions** (exposed via wasm_minimal_protocol):
  - `load_turtle()`: Load Turtle data into named store
  - `query()`: Execute SPARQL SELECT queries
  - `query_construct()`: Execute CONSTRUCT queries (returns Turtle)
  - `query_ask()`: Execute ASK queries (returns boolean)
  - `clear_store()`: Clear store data
  - `list_stores()`: List all named stores
  - `get_store_size()`: Get triple count
- **Custom getrandom**: Implements `__getrandom_custom()` for WASM compatibility using deterministic counter-based RNG

### Typst Package (`typst-package/lib.typ`)
- **WASM Functions** (recommended):
  - `oxload-turtle(store-name, content)`: Load RDF data
  - `oxquery(store-name, sparql)`: Query named store
  - `oxclear(store-name)`: Clear store
  - `oxlist-stores()`: List stores
  - `oxstore-size(store-name)`: Get triple count
  - **Convenience**: `load-turtle()`, `query-memory()`, `clear-memory()` for default "memory" store
- **Legacy CLI Functions**:
  - `oxload(store, query)`: Shell-based execution of typox binary
  - `oxload-file(json-file)`: Load pre-generated JSON files

### Type Handling Strategy

Both implementations preserve RDF datatypes when converting to JSON:
- **Integers** (xsd:integer, xsd:int, xsd:long, etc.) → JSON numbers
- **Decimals** (xsd:decimal, xsd:double, xsd:float) → JSON numbers
- **Strings** (literals without datatype, language-tagged) → JSON strings (language tags removed)
- **URIs** → Shortened using prefixes (e.g., `foaf:name`) or full URI strings
- **Blank nodes** → String format `_:b123`

### Prefix System

Built-in prefixes (defined in `extract_prefixes()`):
- Standard: rdf, rdfs, owl, xsd
- Vocabularies: foaf, dc, dcterms, skos

Prefixes are extracted from SPARQL queries and used for URI shortening in results.

## Development Workflow

### Adding New RDF Format Support (WASM)

Add new `load_*()` function in `plugin/src/lib.rs`:
```rust
#[wasm_func]
pub fn load_ntriples(store_name: &[u8], data: &[u8]) -> Vec<u8> {
    // Follow pattern from load_turtle()
    store.load_from_reader(RdfFormat::NTriples, data)
}
```

Then expose in `typst-package/lib.typ`:
```typ
#let oxload-ntriples(store-name, content) = {
  let result = str(typox.load_ntriples(bytes(store-name), bytes(content)))
  if result.starts-with("ERROR:") { panic(...) }
}
```

### Adding New Prefix

Edit `extract_prefixes()` in `src/main.rs`:
```rust
prefixes.insert("schema".to_string(), "https://schema.org/".to_string());
```

### Adding New XSD Datatype Conversion

Update both:
1. `format_term_typed()` in `src/main.rs` (CLI)
2. `query()` match arm in `plugin/src/lib.rs` (WASM)

Add constant at top of `src/main.rs` if needed:
```rust
const XSD_DATE: &str = "http://www.w3.org/2001/XMLSchema#date";
```

## Important Implementation Details

### WASM Plugin Specifics
- **No threading**: Uses single-threaded in-memory stores
- **No filesystem**: All data must be loaded via function calls
- **Getrandom workaround**: Custom implementation required for wasm32-unknown-unknown target
- **Size optimization**: Uses `lto = true` and `opt-level = "s"` in release profile
- **Post-build optimization**: `wasm-opt -Oz` if binaryen tools available

### CLI Specifics
- **Async runtime**: Uses Tokio for HTTP endpoint support
- **Error propagation**: Uses `anyhow` for error handling with context
- **Glob support**: The `load` subcommand supports glob patterns for batch loading Turtle files
- **Legacy mode**: Top-level `-s`/`-q` flags supported for backwards compatibility (avoid in new usage)

### Testing Strategies
- CLI: Use small local stores or public SPARQL endpoints with LIMIT clauses
- WASM: Use demo files (`demo-wasm.typ`) with embedded Turtle data
- Integration: Generate JSON with CLI, verify consumption in Typst documents

## Common Patterns

### Query Execution Flow (CLI)
1. `execute_query()` → `connect_to_store()` → returns `DataSource` enum
2. Extract prefixes from query string
3. Match on DataSource:
   - LocalStore: `store.query()` → `format_results()` → `format_term_typed()`
   - HttpEndpoint: `execute_http_query()` → POST request → `convert_sparql_json_to_typox_format()`
4. Return unified JSON Value array

### Store Management (WASM)
1. First access: `ensure_stores()` creates default "memory" store
2. Lazy creation: Stores created on first `load_*()` call to that store name
3. Thread-safe: Uses `AtomicBool` flag with unsafe static mutable access
4. Access pattern: `with_stores_mut()` closure pattern for safe mutation

## Error Handling Philosophy

- **CLI**: Return meaningful exit codes, write errors to stderr
- **WASM**: Return "ERROR:" prefixed strings, let Typst panic with context
- **Both**: Preserve source error messages with context about operation being performed

## File Organization
- `src/main.rs`: CLI implementation
- `plugin/src/lib.rs`: WASM plugin implementation
- `typst-package/lib.typ`: Typst wrapper functions
- `build-wasm.sh`: WASM build automation
- `demo.typ`: CLI usage examples
- `demo-wasm.typ`: WASM plugin usage examples
