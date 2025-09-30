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

#import "typst-package/lib.typ": oxload-file
//#import "@preview/tablex:0.0.8": tablex, cellx, colspanx, rowspanx

= Typox: RDF Data Integration Demo

This document demonstrates the complete workflow of loading Turtle files into Oxigraph stores and querying them for use in Typst documents.

== Overview

Typox is a tool that bridges the semantic web and document generation by:
1. Loading RDF data from Turtle files into Oxigraph stores
2. Executing SPARQL queries against the stored data
3. Formatting results as JSON for consumption by Typst documents

== Setup Process

Before generating this document, run the setup script:

```bash
./setup_demo.sh
```

This script will:
- Build the typox binary
- Load sample Turtle files into Oxigraph stores
- Execute sample queries and save results as JSON
- Prepare data for this demonstration

== Sample Datasets

We've created five diverse RDF datasets to showcase different vocabularies and use cases:

=== 1. People Data (FOAF Vocabulary)

The people dataset uses the FOAF (Friend of a Friend) vocabulary to represent software professionals and their relationships.

#let people_data = oxload-file("../demo/results/people_basic.json")

#table(
  columns: 4,
    [*Name*], [*Age*], [*Title*], [*Department*],
  ..people_data.map(person => (person.name, str(person.age), person.title, "Engineering")).flatten()
)

*Network of Professional Relationships:*

#let relationships = oxload-file("../demo/results/people_relationships.json")

#for rel in relationships [
  - *#rel.person1* knows *#rel.person2*
]

=== 2. Product Catalog (Schema.org)

Our e-commerce dataset demonstrates product information using Schema.org vocabulary.

#let products_data = oxload-file("../demo/results/products_basic.json")

==== Featured Products

#table(
  columns: 4,
    [*Product*], [*Price*], [*Brand*], [*Category*],
  ..products_data.map(product => (product.name, "$" + str(product.price), product.brand, product.category)).flatten()
)

==== Top Rated Products

#let ratings_data = oxload-file("../demo/results/products_ratings.json")

#for product in ratings_data.slice(0, 3) [
  === #product.name
  - Rating: #product.rating/5.0 stars
  - Based on #product.reviews reviews

]

=== 3. Academic Publications

Academic publication data using Dublin Core and BIBO ontologies.

#let publications_data = oxload-file("../demo/results/publications_basic.json")

#table(
  columns: 3,
    [*Title*], [*Author*], [*Year*],
  ..publications_data.map(pub => (pub.title, pub.author, str(pub.year))).flatten()
)

=== 4. Geographic Locations

Location data using GeoNames ontology with coordinates and population data.

#let locations_data = oxload-file("../demo/results/locations_basic.json")

==== Major Cities

#for city in locations_data [
  === #city.name, #city.country
  - Population: #city.population
  - Coordinates: #city.lat°, #city.long°

]

=== 5. Datatype Examples

Comprehensive examples of XSD datatypes in RDF.

#let datatypes_data = oxload-file("../demo/results/datatypes_numeric.json")

#table(
  columns: 3,

    [*Example*], [*Decimal*], [*Float*],
  ..datatypes_data.map(dt => (dt.label, str(dt.decimal), str(dt.float))).flatten()
)

== Technical Architecture

=== Data Loading Process

1. **Turtle Files**: RDF data stored in Turtle format (.ttl files)
2. **Oxigraph Store**: High-performance RDF store for data persistence
3. **SPARQL Queries**: Standard RDF query language for data retrieval
4. **JSON Output**: Structured data for Typst consumption

=== Command Line Interface

The typox CLI provides two main commands:

```bash
# Load Turtle files into a store
typox load -s store_path -f file1.ttl file2.ttl --create

# Query a store and output JSON
typox query -s store_path -q "SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 10"
```

=== Integration with Typst

The `oxload-file()` function reads JSON query results directly into Typst:

```typ
#let data = oxload-file("results.json")
#for item in data [
  - #item.name: #item.value
]
```

== Advanced Features

=== Datatype Preservation

Numeric values are automatically converted to Typst numbers for calculations:

#let numeric_data = oxload-file("../demo/results/datatypes_numeric.json")
#let total_decimal = numeric_data.fold(0, (acc, item) => acc + item.decimal)

Total of all decimal values: *#total_decimal*

=== Complex Queries

SPARQL supports sophisticated queries across multiple datasets:

```sparql
# Cross-dataset query example
SELECT ?name ?type (COUNT(?relation) as ?connections) WHERE {
  { ?entity foaf:name ?name . ?entity a ?type . ?entity foaf:knows ?relation . }
  UNION
  { ?entity gn:name ?name . ?entity a ?type . ?entity gn:parentCountry ?relation . }
}
GROUP BY ?name ?type
ORDER BY DESC(?connections)
```

== Performance Considerations

- **Oxigraph**: Optimized RDF storage with fast query performance
- **Batch Loading**: Efficient loading of multiple Turtle files
- **Query Caching**: Pre-computed results avoid runtime query overhead
- **JSON Format**: Lightweight data exchange between typox and Typst

== Use Cases

=== Documentation Generation
- API documentation from RDF schemas
- Database schema documentation
- Configuration documentation

=== Report Generation
- Business intelligence reports from RDF data warehouses
- Scientific publication summaries
- Survey and analytics reports

=== Data Visualization
- Charts and graphs from RDF datasets
- Geographic data visualization
- Network relationship diagrams

== Getting Started

1. **Install Dependencies**
   ```bash
   # Install Rust and Cargo
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

   # Install Typst
   cargo install typst-cli
   ```

2. **Clone and Build**
   ```bash
   git clone <repository-url>
   cd typox
   cargo build --release
   ```

3. **Run Demo**
   ```bash
   ./setup_demo.sh
   typst compile demo.typ demo.pdf
   ```

4. **Create Your Own Data**
   ```bash
   # Create your Turtle file
   echo "@prefix ex: <http://example.org/> .
   ex:myData ex:hasValue 42 ." > my_data.ttl

   # Load into store
   ./target/release/typox load -s my_store -f my_data.ttl -c

   # Query the data
   ./target/release/typox query -s my_store \
     -q "SELECT ?s ?p ?o WHERE { ?s ?p ?o }" \
     -o my_results.json
   ```

=== 6. Remote SPARQL Endpoints

The new `oxload` function also supports querying remote HTTP SPARQL endpoints, allowing you to integrate external data sources directly into your Typst documents.

#let dbpedia_cities = oxload-file("../demo/results/dbpedia_cities.json")

==== Major World Cities (from DBpedia)

#table(
  columns: 2,
    [*City*], [*Population*],
  ..dbpedia_cities.map(city => {
    let city_name = city.city.replace("http://dbpedia.org/resource/", "")
    (city_name, city.population)
  }).flatten()
)

==== Mixed Data Sources Example

You can combine local store data with remote endpoint data in a single document:

```bash
# Query local store
./target/release/typox query -s demo/stores/locations \\
  -q "SELECT ?name ?population WHERE { ?city gn:name ?name ; gn:population ?population }"

# Query remote endpoint
./target/release/typox query -s "https://dbpedia.org/sparql" \\
  -q "SELECT ?city ?population WHERE { ?city a dbo:City ; dbo:populationTotal ?population }"
```

== HTTP Endpoint Usage

=== Command Line Examples

```bash
# Query DBpedia for cities
./target/release/typox query -s "https://dbpedia.org/sparql" \\
  -q "PREFIX dbo: <http://dbpedia.org/ontology/>
      SELECT ?city ?population WHERE {
        ?city a dbo:City ;
              dbo:populationTotal ?population ;
              rdfs:label ?label .
        FILTER(lang(?label) = 'en' && ?population > 8000000)
      } LIMIT 5" \\
  -o cities.json

# Query Wikidata
./target/release/typox query -s "https://query.wikidata.org/sparql" \\
  -q "SELECT ?item ?itemLabel WHERE {
        ?item wdt:P31 wd:Q5 .
        SERVICE wikibase:label { bd:serviceParam wikibase:language 'en' }
      } LIMIT 10" \\
  -o people.json
```

=== Typst Integration

The `oxload` function automatically detects HTTP URLs and queries them as SPARQL endpoints:

```typst
#import "typst-package/lib.typ": oxload

// This would query a remote endpoint (but requires pre-generated JSON for Typst)
// Remote data must be pre-generated using the command line tool
#let remote_data = oxload-file("remote_cities.json")
```

== Conclusion

Typox now provides a seamless bridge between local RDF stores, remote SPARQL endpoints, and document generation, enabling powerful data-driven documents with minimal setup. The combination of:

- **Local Oxigraph stores** for fast, consistent data access
- **Remote SPARQL endpoints** for accessing external knowledge bases like DBpedia and Wikidata
- **RDF's expressiveness** and **SPARQL's query capabilities**
- **Typst's typesetting excellence**

opens new possibilities for automated documentation and reporting that can incorporate both private and public data sources.

*Try it yourself with your own RDF data and remote endpoints!*