# Oxload - RDF/SPARQL Integration for Typst

**Seamlessly integrate RDF data into your Typst documents using SPARQL queries.**

Oxload provides native RDF processing in Typst through a WebAssembly plugin powered by Oxigraph. Load Turtle/N3 data into in-memory stores and query them with SPARQL directly in your templates—no external tools required.

## Quick Start

```typst
#import "@preview/oxload:0.1.0": load-turtle, query-memory

// Load RDF data
#load-turtle("
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ex: <http://example.org/> .

ex:alice foaf:name 'Alice Johnson' ;
         foaf:age 28 ;
         foaf:mbox <mailto:alice@example.org> .

ex:bob foaf:name 'Bob Smith' ;
       foaf:age 32 ;
       foaf:mbox <mailto:bob@example.org> .
")

// Query the data
#let people = query-memory("
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  SELECT ?name ?age WHERE {
    ?person foaf:name ?name ;
            foaf:age ?age
  }
  ORDER BY ?age
")

= People Directory

#for person in people [
  - *#person.name* is #person.age years old
]
```

## Features

- **🚀 Native Integration**: Pure WebAssembly plugin—no external dependencies
- **💾 In-Memory Stores**: Fast RDF processing with named store support
- **🎯 Smart Type Handling**: RDF datatypes automatically converted to appropriate JSON types
- **🏷️ Prefix Support**: Automatic URI shortening with common RDF prefixes
- **⚡ Full SPARQL SELECT**: Query data with complete SPARQL SELECT support
- **📊 Multiple Stores**: Manage different datasets independently

## Installation

Import the package in your Typst document:

```typst
#import "@preview/oxload:0.1.0": load-turtle, query-memory, oxload-turtle, oxquery
```

## API Reference

### Core Functions

#### `oxload-turtle(store-name, turtle-content)`
Load Turtle/N3 RDF data into a named store.

**Parameters:**
- `store-name` (string): Name of the store
- `turtle-content` (string): RDF data in Turtle format

**Example:**
```typst
#oxload-turtle("mydata", "
@prefix ex: <http://example.org/> .
ex:item1 ex:name 'Item 1' ; ex:value 42 .
")
```

#### `oxquery(store-name, sparql-query)`
Execute a SPARQL SELECT query against a named store.

**Parameters:**
- `store-name` (string): Name of the store to query
- `sparql-query` (string): SPARQL SELECT query

**Returns:** Array of objects with query results

**Example:**
```typst
#let results = oxquery("mydata", "
  PREFIX ex: <http://example.org/>
  SELECT ?name ?value WHERE {
    ?item ex:name ?name ; ex:value ?value
  }
")
```

#### `oxclear(store-name)`
Clear all data from a store.

**Example:**
```typst
#oxclear("mydata")
```

#### `oxlist-stores()`
List all available stores.

**Returns:** Array of store names

**Example:**
```typst
#let stores = oxlist-stores()
Available stores: #stores.join(", ")
```

#### `oxstore-size(store-name)`
Get the number of triples in a store.

**Returns:** Integer

**Example:**
```typst
Store contains #oxstore-size("mydata") triples
```

### Convenience Functions

For simple use cases, these functions operate on the default "memory" store:

- **`load-turtle(content)`** - Load data into default store
- **`query-memory(sparql)`** - Query the default store
- **`clear-memory()`** - Clear the default store

## Examples

### Basic Usage

```typst
#import "@preview/oxload:0.1.0": load-turtle, query-memory

#load-turtle("
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ex: <http://example.org/> .

ex:alice foaf:name 'Alice' ; foaf:age 28 .
ex:bob foaf:name 'Bob' ; foaf:age 32 .
")

#let people = query-memory("
  SELECT ?name ?age WHERE {
    ?person foaf:name ?name ; foaf:age ?age
  }
  ORDER BY ?age
")

#table(
  columns: 2,
  [*Name*], [*Age*],
  ..people.map(p => (p.name, str(p.age))).flatten()
)
```

### Multiple Named Stores

```typst
#import "@preview/oxload:0.1.0": oxload-turtle, oxquery

// Load employee data
#oxload-turtle("employees", "
@prefix ex: <http://example.org/> .
ex:emp1 ex:name 'Alice' ; ex:dept 'Engineering' .
ex:emp2 ex:name 'Bob' ; ex:dept 'Marketing' .
")

// Load project data
#oxload-turtle("projects", "
@prefix ex: <http://example.org/> .
ex:proj1 ex:title 'Project Alpha' ; ex:lead 'Alice' .
ex:proj2 ex:title 'Project Beta' ; ex:lead 'Bob' .
")

// Query each store independently
#let employees = oxquery("employees", "
  SELECT ?name ?dept WHERE {
    ?emp ex:name ?name ; ex:dept ?dept
  }
")

#let projects = oxquery("projects", "
  SELECT ?title ?lead WHERE {
    ?proj ex:title ?title ; ex:lead ?lead
  }
")
```

### Type Handling

RDF datatypes are automatically converted to appropriate JSON types:

```typst
#load-turtle("
@prefix ex: <http://example.org/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

ex:item ex:name 'Widget' ;
        ex:quantity '10'^^xsd:integer ;
        ex:price '19.99'^^xsd:decimal ;
        ex:active 'true'^^xsd:boolean .
")

#let items = query-memory("
  SELECT ?name ?quantity ?price WHERE {
    ?item ex:name ?name ;
          ex:quantity ?quantity ;
          ex:price ?price
  }
")

// Types are preserved: quantity is number, price is number
#for item in items [
  - #item.name: #item.quantity units at $#item.price each
]
```

## Data Type Conversion

| RDF Type | JSON Type | Example |
|----------|-----------|---------|
| `xsd:integer`, `xsd:int`, `xsd:long` | number | `30` |
| `xsd:decimal`, `xsd:float`, `xsd:double` | number | `5.6` |
| `xsd:string`, plain literals | string | `"text"` |
| Language-tagged literals | string (tag removed) | `"Hello"@en` → `"Hello"` |
| URIs with known prefixes | string (shortened) | `foaf:name` |
| URIs without prefixes | string (full URI) | `"http://example.org/prop"` |
| Blank nodes | string | `"_:b123"` |

## Built-in Prefixes

Common RDF prefixes are automatically recognized:

```
rdf:     http://www.w3.org/1999/02/22-rdf-syntax-ns#
rdfs:    http://www.w3.org/2000/01/rdf-schema#
owl:     http://www.w3.org/2002/07/owl#
xsd:     http://www.w3.org/2001/XMLSchema#
foaf:    http://xmlns.com/foaf/0.1/
dc:      http://purl.org/dc/elements/1.1/
dcterms: http://purl.org/dc/terms/
skos:    http://www.w3.org/2004/02/skos/core#
```

Define custom prefixes in your SPARQL queries:

```sparql
PREFIX ex: <http://example.org/>
PREFIX vocab: <http://myproject.org/vocab#>

SELECT ?item ?property WHERE {
  ?item vocab:hasProperty ?property
}
```

## Use Cases

### ✅ Ideal For

- Small to medium datasets that fit in memory
- Self-contained documents with embedded RDF data
- Rapid prototyping and testing
- Semantic data integration in reports
- Simple SPARQL SELECT queries
- Educational materials and tutorials

### ⚠️ Not Recommended For

- Very large datasets (>100MB RDF data)
- Persistent RDF stores
- Remote HTTP SPARQL endpoints
- Complex SPARQL queries (CONSTRUCT, ASK, DESCRIBE)

For production use cases with large persistent stores or remote endpoints, see the [Typox CLI tool](https://github.com/deepthought-solutions/typox).

## Error Handling

Functions will panic with descriptive error messages if operations fail:

```typst
// Invalid Turtle syntax
#load-turtle("invalid turtle @#$%") // Panics with parse error

// Querying non-existent store
#oxquery("nonexistent", "SELECT * WHERE { ?s ?p ?o }") // Panics

// Invalid SPARQL syntax
#query-memory("INVALID SPARQL") // Panics with query error
```

Wrap operations in conditionals if you need graceful error handling:

```typst
#let results = query-memory("SELECT ?s WHERE { ?s ?p ?o }")

#if results.len() == 0 [
  _No data found._
] else [
  #for result in results [
    - #result.s
  ]
]
```

## Limitations

- **SPARQL Support**: Only SELECT queries are currently supported
- **Storage**: All data is in-memory (cleared when document compilation finishes)
- **Format Support**: Only Turtle/N3 format for loading data
- **Performance**: Best for datasets under 10,000 triples

## Related Projects

- **[Typox](https://github.com/deepthought-solutions/typox)** - Full-featured CLI tool with persistent stores and HTTP endpoint support
- **[Oxigraph](https://github.com/oxigraph/oxigraph)** - The RDF database engine powering this package

## License

MIT License - Copyright (c) 2024 Typox Project Contributors

## Contributing

Issues and contributions welcome at [github.com/deepthought-solutions/typox](https://github.com/deepthought-solutions/typox)
