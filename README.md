<!--
Copyright (c) 2024 Typox Project Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
-->

# Typox

**A powerful Rust tool and Typst package for seamlessly integrating RDF data from Oxigraph stores into Typst documents.**

Typox bridges the gap between semantic data and document generation, allowing you to query RDF knowledge graphs using SPARQL and directly use the results in your Typst templates with proper type preservation and automatic formatting.

## 🌟 Features

- **🔄 Native Typst Integration**: Use `oxload()` function directly in templates, just like `json()`
- **🎯 Smart Type Preservation**: Numbers stay as numbers, strings as strings
- **🏷️ Intelligent Prefix Handling**: Automatic URI shortening with common RDF prefixes
- **🌐 Clean Language Processing**: Language tags automatically removed
- **⚡ Full SPARQL Support**: Complete SPARQL SELECT query capabilities
- **📁 Flexible Output**: Generate JSON files or pipe to stdout
- **🛡️ Robust Error Handling**: Clear failures for missing stores or empty results
- **📊 Production Ready**: Built with Oxigraph for reliable RDF processing

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
  - [Typst Package Usage](#1-typst-package-usage)
  - [Command Line Usage](#2-command-line-usage)
- [Data Type Handling](#data-type-handling)
- [Prefix Support](#prefix-support)
- [Complete Examples](#complete-examples)
- [Workflow Guide](#workflow-guide)
- [Error Handling](#error-handling)
- [Advanced Features](#advanced-features)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## 🚀 Quick Start

1. **Build the tool:**
   ```bash
   cargo build --release
   ```

2. **Generate data from your RDF store:**
   ```bash
   ./target/release/typox -s /path/to/your/store \
     -q "SELECT ?name ?age WHERE { ?person foaf:name ?name ; foaf:age ?age }" \
     -o people.json
   ```

3. **Use in your Typst document:**
   ```typst
   #import "typst-package/lib.typ": oxload-file
   #let people = oxload-file("people.json")

   #for person in people [
     - *#person.name*: #person.age years old
   ]
   ```

## 🛠️ Installation

### Prerequisites

- **Rust** (1.70 or later): [Install Rust](https://rustup.rs/)
- **Typst** (0.10 or later): [Install Typst](https://typst.app/docs/tutorial/installation/)
- **Oxigraph store**: Either a local directory or HTTP endpoint

### Build from Source

```bash
git clone <repository-url>
cd typox
cargo build --release
```

The binary will be available at `./target/release/typox`.

### Install Globally (Optional)

```bash
cargo install --path .
```

Now you can use `typox` from anywhere.

## 📖 Usage

### 1. Typst Package Usage

#### Method A: Direct Import

Copy the `typst-package` directory to your project and import:

```typst
#import "typst-package/lib.typ": oxload, oxload-file

// Load data using store path and query
#let research-data = oxload("/home/user/research-kb", "
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX dc: <http://purl.org/dc/elements/1.1/>
  SELECT ?title ?author ?year WHERE {
    ?paper dc:title ?title ;
           dc:creator ?author ;
           dc:date ?year
  }
  ORDER BY ?year
  LIMIT 20
")

// Or load from a specific JSON file
#let survey-data = oxload-file("survey-results.json")
```

#### Method B: Package Manager (Future)

```typst
#import "@preview/oxload:0.1.0": oxload, oxload-file
```

### 2. Command Line Usage

#### Basic Query

```bash
typox -s /path/to/store -q "SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 5"
```

#### Save to File

```bash
typox -s /path/to/store \
      -q "SELECT ?name ?email WHERE { ?person foaf:name ?name ; foaf:mbox ?email }" \
      -o contacts.json
```

#### Complex Queries

```bash
typox -s ./knowledge-base \
      -q "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
          PREFIX ex: <http://example.org/>
          SELECT ?category ?count WHERE {
            {
              SELECT ?category (COUNT(?item) as ?count) WHERE {
                ?item ex:category ?category
              }
              GROUP BY ?category
            }
          }
          ORDER BY DESC(?count)" \
      -o category-stats.json
```

#### Pipeline Integration

```bash
# Generate multiple datasets
for query_file in queries/*.sparql; do
    output_file="data/$(basename "$query_file" .sparql).json"
    typox -s ./store -q "$(cat "$query_file")" -o "$output_file"
done

# Then compile your document
typst compile report.typ
```

## 🎭 Data Type Handling

Typox intelligently converts RDF data types to appropriate JSON types:

### Input RDF Data
```turtle
@prefix ex: <http://example.org/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

ex:alice ex:name "Alice Smith" ;
         ex:age "30"^^xsd:integer ;
         ex:height "5.6"^^xsd:float ;
         ex:active "true"^^xsd:boolean ;
         ex:email "alice@example.com" ;
         ex:bio "Researcher"@en .
```

### Output JSON
```json
[
  {
    "name": "Alice Smith",
    "age": 30,
    "height": 5.6,
    "active": "true",
    "email": "alice@example.com",
    "bio": "Researcher"
  }
]
```

### Type Conversion Rules

| RDF Type | JSON Type | Example |
|----------|-----------|---------|
| `xsd:integer`, `xsd:int`, `xsd:long` | `number` | `30` |
| `xsd:decimal`, `xsd:float`, `xsd:double` | `number` | `5.6` |
| `xsd:string`, literals without datatype | `string` | `"Alice"` |
| Language-tagged literals | `string` (tag removed) | `"Hello"@en` → `"Hello"` |
| URIs with known prefixes | `string` (shortened) | `foaf:name` |
| URIs without prefixes | `string` (full URI) | `"http://example.org/name"` |
| Blank nodes | `string` | `"_:b123"` |

## 🏷️ Prefix Support

### Built-in Prefixes

Typox automatically recognizes and uses these common prefixes:

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

### Custom Prefixes

Define prefixes in your SPARQL queries:

```sparql
PREFIX ex: <http://example.org/>
PREFIX vocab: <http://myproject.org/vocabulary#>

SELECT ?person ?skill ?level WHERE {
  ?person vocab:hasSkill ?skillNode .
  ?skillNode ex:skill ?skill ;
             ex:level ?level
}
```

Results will use shortened forms: `vocab:hasSkill`, `ex:skill`

## 📊 Complete Examples

### Academic Publication Database

**Setup:**
```bash
# Generate publication data
typox -s ./academic-kb \
  -q "PREFIX dc: <http://purl.org/dc/elements/1.1/>
      PREFIX dcterms: <http://purl.org/dc/terms/>
      SELECT ?title ?author ?year ?venue WHERE {
        ?paper dc:title ?title ;
               dc:creator ?author ;
               dcterms:date ?year ;
               dcterms:isPartOf ?venue
      }
      ORDER BY DESC(?year)" \
  -o publications.json

# Generate author statistics
typox -s ./academic-kb \
  -q "SELECT ?author (COUNT(?paper) as ?count) WHERE {
        ?paper dc:creator ?author
      }
      GROUP BY ?author
      ORDER BY DESC(?count)" \
  -o author-stats.json
```

**Typst Document:**
```typst
#import "typst-package/lib.typ": oxload-file

= Research Publication Report

== Recent Publications

#let publications = oxload-file("publications.json")

#for pub in publications.slice(0, 10) [
  === #pub.title

  *Author:* #pub.author \
  *Year:* #pub.year \
  *Venue:* #pub.venue
]

== Author Statistics

#let stats = oxload-file("author-stats.json")

#table(
  columns: (1fr, auto),
  [*Author*], [*Publications*],
  ..stats.slice(0, 15).map(s => ([#s.author], [#s.count])).flatten()
)
```

### Product Catalog

**SPARQL Query:**
```sparql
PREFIX ex: <http://shop.example.org/>
PREFIX gr: <http://purl.org/goodrelations/v1#>

SELECT ?product ?name ?price ?category ?inStock WHERE {
  ?product ex:name ?name ;
           gr:hasPriceSpecification/gr:hasCurrencyValue ?price ;
           ex:category ?category ;
           ex:inStock ?inStock
}
ORDER BY ?category ?name
```

**Usage:**
```bash
typox -s ./shop-data -q "$(cat product-query.sparql)" -o catalog.json
```

**Typst Template:**
```typst
#import "typst-package/lib.typ": oxload-file

#let products = oxload-file("catalog.json")

= Product Catalog

#let by-category = products.fold((:), (acc, product) => {
  let cat = product.category
  if cat in acc {
    acc.at(cat).push(product)
  } else {
    acc.insert(cat, (product,))
  }
  acc
})

#for (category, items) in by-category [
  == #category

  #for product in items [
    - *#product.name*: $#product.price
      #if product.inStock == "true" [✓ In Stock] else [❌ Out of Stock]
  ]
]

== Summary

Total products: #products.len() \
Average price: $#calc.round(products.map(p => p.price).sum() / products.len(), digits: 2)
```

### Survey Data Analysis

**Generate Data:**
```bash
typox -s ./survey-kb \
  -q "SELECT ?respondent ?age ?satisfaction ?department WHERE {
        ?resp ex:respondent ?respondent ;
              ex:age ?age ;
              ex:satisfaction ?satisfaction ;
              ex:department ?department
      }" \
  -o survey-responses.json
```

**Analysis Document:**
```typst
#import "typst-package/lib.typ": oxload-file

#let responses = oxload-file("survey-responses.json")

= Survey Analysis Report

== Response Demographics

Total responses: #responses.len()

#let by-dept = responses.fold((:), (acc, r) => {
  let dept = r.department
  acc.insert(dept, acc.at(dept, default: 0) + 1)
  acc
})

#table(
  columns: (1fr, auto),
  [*Department*], [*Responses*],
  ..by-dept.pairs().map(((dept, count)) => ([#dept], [#count])).flatten()
)

== Satisfaction Analysis

#let avg-satisfaction = responses.map(r => r.satisfaction).sum() / responses.len()

Average satisfaction: #calc.round(avg-satisfaction, digits: 2)/5.0

#let satisfaction-by-dept = responses.fold((:), (acc, r) => {
  let dept = r.department
  if dept in acc {
    acc.at(dept).push(r.satisfaction)
  } else {
    acc.insert(dept, (r.satisfaction,))
  }
  acc
})

#for (dept, scores) in satisfaction-by-dept [
  - *#dept*: #calc.round(scores.sum() / scores.len(), digits: 2)/5.0
]
```

## 🔄 Workflow Guide

### 1. Development Phase

**Explore your data:**
```bash
# Get an overview
typox -s ./store -q "SELECT ?p (COUNT(?s) as ?count) WHERE { ?s ?p ?o } GROUP BY ?p ORDER BY DESC(?count)" | head -20

# Sample some data
typox -s ./store -q "SELECT * WHERE { ?s ?p ?o } LIMIT 10"
```

**Test specific queries:**
```bash
# Save queries in files for reuse
echo "SELECT ?name ?email WHERE { ?person foaf:name ?name ; foaf:mbox ?email }" > queries/contacts.sparql

typox -s ./store -q "$(cat queries/contacts.sparql)"
```

### 2. Production Phase

**Batch generate data:**
```bash
#!/bin/bash
# generate-data.sh

STORE="./knowledge-base"
QUERIES_DIR="./queries"
DATA_DIR="./data"

mkdir -p "$DATA_DIR"

for query_file in "$QUERIES_DIR"/*.sparql; do
    query_name=$(basename "$query_file" .sparql)
    output_file="$DATA_DIR/$query_name.json"

    echo "Generating $output_file..."
    typox -s "$STORE" -q "$(cat "$query_file")" -o "$output_file"

    if [ $? -eq 0 ]; then
        echo "✓ $query_name completed"
    else
        echo "✗ $query_name failed"
        exit 1
    fi
done

echo "All data generated successfully!"
```

**Integrate with build process:**
```bash
# Makefile
.PHONY: data document clean

data:
	./generate-data.sh

document: data
	typst compile main.typ output.pdf

clean:
	rm -rf data/ output.pdf

all: document
```

### 3. Continuous Integration

**Example GitHub Actions workflow:**
```yaml
name: Generate Report

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  push:
    branches: [ main ]

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2

    - name: Setup Rust
      uses: actions-rs/toolchain@v1
      with:
        toolchain: stable

    - name: Build typox
      run: cargo build --release

    - name: Install Typst
      run: |
        curl -L https://github.com/typst/typst/releases/latest/download/typst-x86_64-unknown-linux-musl.tar.xz | tar -xJ
        sudo mv typst-x86_64-unknown-linux-musl/typst /usr/local/bin/

    - name: Generate data
      run: ./generate-data.sh

    - name: Compile document
      run: typst compile report.typ report.pdf

    - name: Upload artifact
      uses: actions/upload-artifact@v2
      with:
        name: report
        path: report.pdf
```

## 🛡️ Error Handling

### Common Error Scenarios

#### Store Not Found
```bash
$ typox -s ./nonexistent -q "SELECT * WHERE { ?s ?p ?o }"
Error: Store path does not exist: ./nonexistent
```

#### No Results
```bash
$ typox -s ./store -q "SELECT ?x WHERE { ?x ex:impossible ?y }"
Error: No records found for the given query
```

#### Invalid Query
```bash
$ typox -s ./store -q "INVALID SPARQL"
Error: Failed to execute query: INVALID SPARQL
```

#### Missing JSON File in Typst
```typst
#let data = oxload-file("missing.json")
// Error: failed to load file (No such file or directory)
```

### Best Practices for Error Handling

**1. Validate store existence:**
```bash
if [ ! -d "$STORE_PATH" ]; then
    echo "Error: Store directory $STORE_PATH does not exist"
    exit 1
fi
```

**2. Test queries incrementally:**
```bash
# Start with COUNT queries
typox -s ./store -q "SELECT (COUNT(*) as ?count) WHERE { ?s ?p ?o }"

# Then add specific patterns
typox -s ./store -q "SELECT (COUNT(*) as ?count) WHERE { ?s foaf:name ?o }"
```

**3. Handle empty results gracefully in Typst:**
```typst
#let data = oxload-file("results.json")

#if data.len() == 0 [
  _No data available for this query._
] else [
  #for item in data [
    - #item.name
  ]
]
```

## 🔧 Advanced Features

### Custom Data Processing

You can post-process the JSON data in Typst:

```typst
#import "typst-package/lib.typ": oxload-file

#let raw-data = oxload-file("sales.json")

// Add computed fields
#let processed-data = raw-data.map(item => {
  item.insert("revenue", item.price * item.quantity)
  item.insert("profit-margin", (item.price - item.cost) / item.price * 100)
  item
})

// Filter and sort
#let high-value = processed-data
  .filter(item => item.revenue > 1000)
  .sorted(key: item => item.revenue, reverse: true)
```

### Template Functions

Create reusable functions for common patterns:

```typst
#import "typst-package/lib.typ": oxload-file

#let format-currency(amount) = {
  "$" + str(calc.round(amount, digits: 2))
}

#let make-table(data, columns) = {
  table(
    columns: (1fr,) * columns.len(),
    ..columns.map(col => strong(col.title)),
    ..data.map(row => columns.map(col => [#col.format(row)])).flatten()
  )
}

// Usage
#let sales = oxload-file("sales.json")

#make-table(sales, (
  (title: "Product", format: row => row.name),
  (title: "Revenue", format: row => format-currency(row.revenue)),
  (title: "Units", format: row => str(row.quantity))
))
```

### Performance Optimization

**1. Use LIMIT in development:**
```sparql
SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 100
```

**2. Index your queries:**
```sparql
# More efficient
SELECT ?person ?name WHERE {
  ?person foaf:name ?name
}

# Less efficient
SELECT ?person ?name WHERE {
  ?person ?p ?name .
  FILTER(?p = foaf:name)
}
```

**3. Generate only needed data:**
```bash
# Don't regenerate unchanged data
if [ ! -f "data.json" ] || [ "query.sparql" -nt "data.json" ]; then
    typox -s ./store -q "$(cat query.sparql)" -o data.json
fi
```

## 🔍 Troubleshooting

### Common Issues

**Q: Typst can't find the JSON file**
```
Error: failed to load file
```

*Solution:* Check file paths relative to your Typst document:
```bash
# Make sure paths are correct
ls -la data.json  # Should exist
typst compile --root . document.typ  # Specify root directory
```

**Q: Numbers appear as strings**
```json
{"age": "30", "height": "5.6"}
```

*Solution:* Ensure your RDF data has proper datatypes:
```turtle
ex:person ex:age "30"^^xsd:integer ;
          ex:height "5.6"^^xsd:float .
```

**Q: URIs not shortened**

*Solution:* Add PREFIX declarations to your query:
```sparql
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT ?name WHERE { ?person foaf:name ?name }
```

**Q: Query timeout or memory issues**

*Solution:* Optimize your queries:
```sparql
# Add LIMIT
SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 1000

# Use specific patterns instead of wildcards
SELECT ?person ?name WHERE { ?person foaf:name ?name }
```

### Debug Mode

Enable verbose logging:
```bash
RUST_LOG=debug typox -s ./store -q "SELECT * WHERE { ?s ?p ?o } LIMIT 5"
```

### Performance Profiling

Time your queries:
```bash
time typox -s ./large-store -q "$(cat complex-query.sparql)" -o results.json
```

## 🤝 Contributing

We welcome contributions! Here's how to get started:

### Development Setup

```bash
git clone <repository-url>
cd typox
cargo build
cargo test
```

### Testing

```bash
# Run all tests
cargo test

# Test with a sample store
mkdir test-store
# Add some test data...
cargo run -- -s test-store -q "SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 5"
```

### Adding Features

1. **New data type support:** Modify `format_term_typed()` in `src/main.rs`
2. **New prefixes:** Add to `extract_prefixes()` function
3. **Typst functions:** Extend `typst-package/lib.typ`

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes with tests
4. Update documentation
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Oxigraph](https://github.com/oxigraph/oxigraph) for RDF store capabilities
- [Typst](https://typst.app/) for the amazing typesetting system
- The RDF/SPARQL community for standards and tools

---

**Happy querying! 🎉**

For more examples and advanced usage, check out the `examples/` directory and our [wiki](link-to-wiki).