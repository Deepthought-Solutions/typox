/*
 * Demo for Typox WASM Plugin
 * Copyright (c) 2024 Typox Project Contributors
 * Licensed under the MIT License
 */

#import "typst-package/lib.typ": load-turtle, query-memory, oxload-turtle, oxquery, oxclear, oxlist-stores, oxstore-size

// Demo RDF data in Turtle format
#let foaf-data = "
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ex: <http://example.org/> .

ex:alice foaf:name 'Alice Johnson' ;
         foaf:age 28 ;
         foaf:email 'alice@example.org' .

ex:bob foaf:name 'Bob Smith' ;
       foaf:age 32 ;
       foaf:email 'bob@example.org' .

ex:charlie foaf:name 'Charlie Brown' ;
           foaf:age 25 ;
           foaf:email 'charlie@example.org' .
"

// Load data into the default memory store
#load-turtle(foaf-data)

// Query the loaded data
#let people = query-memory("
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  SELECT ?name ?age ?email WHERE {
    ?person foaf:name ?name ;
            foaf:age ?age ;
            foaf:email ?email
  }
  ORDER BY ?age
")

= Typox WASM Plugin Demo

This document demonstrates the Typox WebAssembly plugin for native RDF data processing in Typst.

== People Data

#table(
  columns: 3,
  [*Name*], [*Age*], [*Email*],
  ..people.map(p => (p.name, str(p.age), p.email)).flatten()
)

== Multi-Store Demo

// Load different datasets into named stores
#oxload-turtle("projects", "
@prefix ex: <http://example.org/> .
ex:proj1 ex:title 'Typox Plugin' ;
         ex:status 'In Progress' ;
         ex:lead 'Alice' .
ex:proj2 ex:title 'Documentation' ;
         ex:status 'Complete' ;
         ex:lead 'Bob' .
")

#oxload-turtle("locations", "
@prefix gn: <http://www.geonames.org/ontology#> .
@prefix ex: <http://example.org/> .
ex:paris gn:name 'Paris' ; gn:population 2161000 .
ex:london gn:name 'London' ; gn:population 8982000 .
")

// Query each store separately
#let projects = oxquery("projects", "
  PREFIX ex: <http://example.org/>
  SELECT ?title ?status ?lead WHERE {
    ?project ex:title ?title ;
             ex:status ?status ;
             ex:lead ?lead
  }
  ORDER BY ?title
")

#let cities = oxquery("locations", "
  PREFIX gn: <http://www.geonames.org/ontology#>
  SELECT ?city ?population WHERE {
    ?c gn:name ?city ; gn:population ?population
  }
  ORDER BY DESC(?population)
")

=== Project Status

#table(
  columns: 3,
  [*Project*], [*Status*], [*Lead*],
  ..projects.map(p => (p.title, p.status, p.lead)).flatten()
)

=== Cities

#for city in cities [
  - *#city.city*: #city.population inhabitants
]

== Store Management

Available stores: #oxlist-stores().join(", ")

Store sizes:
- Memory store: #oxstore-size("memory") triples
- Projects store: #oxstore-size("projects") triples
- Locations store: #oxstore-size("locations") triples

Total triples across all stores: #{oxstore-size("memory") + oxstore-size("projects") + oxstore-size("locations")}

== Usage Examples

This demo shows:
1. Loading Turtle data into the default "memory" store
2. Querying data with SPARQL
3. Using multiple named stores
4. Store management functions
5. Automatic JSON parsing and type conversion

The WASM plugin provides native RDF processing without external dependencies!