## Plugin Functions

The WASM plugin exports these functions for use in Typst:

### Core Functions
- `load_turtle(store_name, turtle_data)` - Load Turtle RDF data into named store
- `query(store_name, sparql)` - Execute SPARQL query against named store
- `clear_store(store_name)` - Clear all data from store
- `list_stores()` - List all available stores
- `get_store_size(store_name)` - Get number of triples in store

### Typst Library Functions
- `oxload-turtle(store-name, turtle-content)` - Load turtle data
- `oxquery(store-name, query)` - Execute SPARQL query
- `oxclear(store-name)` - Clear store
- `oxlist-stores()` - List stores
- `oxstore-size(store-name)` - Get store size

### Convenience Functions
- `load-turtle(content)` - Load data into default "memory" store
- `query-memory(sparql)` - Query default memory store
- `clear-memory()` - Clear default memory store

## Usage Examples

### Basic Usage
```typst
#import "typst-package/lib.typ": load-turtle, query-memory

// Load RDF data
#load-turtle("
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
ex:alice foaf:name 'Alice Johnson' ; foaf:age 28 .
")

// Query the data
#let results = query-memory("
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  SELECT ?name ?age WHERE {
    ?person foaf:name ?name ; foaf:age ?age
  }
")

#for person in results [
  - #person.name: #person.age years old
]
```

### Multi-Store Usage
```typst
#import "typst-package/lib.typ": oxload-turtle, oxquery

// Load into named stores
#oxload-turtle("people", "/* turtle data */")
#oxload-turtle("places", "/* turtle data */")

// Query each store
#let staff = oxquery("people", "SELECT ?name WHERE { ?p foaf:name ?name }")
#let cities = oxquery("places", "SELECT ?city WHERE { ?c gn:name ?city }")
```

## Build Instructions

1. **Install WASM target:**
   ```bash
   rustup target add wasm32-unknown-unknown
   ```

2. **Build the plugin:**
   ```bash
   ./build-wasm.sh
   ```

3. **Use in Typst:**
   The built plugin (`typox.wasm`) is automatically copied to the `typst-package/` directory.