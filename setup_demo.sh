#!/bin/bash

# Copyright (c) 2024 Typox Project Contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Typox Demo Setup Script
# This script sets up demo stores and generates sample query results for Typst integration

set -e

echo "🚀 Typox Demo Setup"
echo "=================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEMO_DIR="demo"
STORES_DIR="$DEMO_DIR/stores"
QUERIES_DIR="$DEMO_DIR/queries"
RESULTS_DIR="$DEMO_DIR/results"

# Create demo directory structure
echo -e "${BLUE}📁 Creating demo directory structure...${NC}"
mkdir -p "$STORES_DIR"
mkdir -p "$QUERIES_DIR"
mkdir -p "$RESULTS_DIR"

# Build the typox binary if needed
if [ ! -f "target/release/typox" ] && [ ! -f "target/debug/typox" ]; then
    echo -e "${YELLOW}🔨 Building typox binary...${NC}"
    cargo build --release || {
        echo -e "${YELLOW}⚠️  Release build failed, trying debug build...${NC}"
        cargo build
        TYPOX_BIN="target/debug/typox"
    }
    TYPOX_BIN="target/release/typox"
else
    if [ -f "target/release/typox" ]; then
        TYPOX_BIN="target/release/typox"
    else
        TYPOX_BIN="target/debug/typox"
    fi
fi

echo -e "${GREEN}✅ Using binary: $TYPOX_BIN${NC}"

# Function to load turtle files into a store
load_store() {
    local store_name="$1"
    local description="$2"
    shift 2
    local files=("$@")

    echo -e "${BLUE}📦 Creating $description store...${NC}"

    # Create the store with all files
    if $TYPOX_BIN load -s "$STORES_DIR/$store_name" -f "${files[@]}" -c; then
        echo -e "${GREEN}✅ Successfully created $store_name store${NC}"
    else
        echo -e "${RED}❌ Failed to create $store_name store${NC}"
        return 1
    fi
}

# Load individual stores
echo -e "${YELLOW}🏗️  Loading turtle files into Oxigraph stores...${NC}"

load_store "people" "people (FOAF)" "samples/people.ttl"
load_store "products" "products (e-commerce)" "samples/products.ttl"
load_store "publications" "publications (academic)" "samples/publications.ttl"
load_store "locations" "locations (geographic)" "samples/locations.ttl"
load_store "datatypes" "datatypes (XSD examples)" "samples/datatypes.ttl"

# Create a combined store with all data
echo -e "${BLUE}📦 Creating combined store with all data...${NC}"
if $TYPOX_BIN load -s "$STORES_DIR/combined" -f samples/*.ttl -c; then
    echo -e "${GREEN}✅ Successfully created combined store${NC}"
else
    echo -e "${RED}❌ Failed to create combined store${NC}"
fi

# Function to execute query and save results
execute_query() {
    local store="$1"
    local query_file="$2"
    local output_file="$3"
    local description="$4"

    echo -e "${BLUE}🔍 Executing $description query...${NC}"

    if [ -f "$query_file" ]; then
        local query_content=$(cat "$query_file")
        if $TYPOX_BIN query -s "$STORES_DIR/$store" -q "$query_content" -o "$RESULTS_DIR/$output_file"; then
            echo -e "${GREEN}✅ Query results saved to $output_file${NC}"
        else
            echo -e "${RED}❌ Query execution failed for $description${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Query file $query_file not found${NC}"
    fi
}

# Generate some basic queries for demonstration
echo -e "${YELLOW}📝 Creating sample SPARQL queries...${NC}"

# People queries
cat > "$QUERIES_DIR/people_basic.sparql" << 'EOF'
PREFIX foaf: <http://xmlns.com/foaf/0.1/>

SELECT ?name ?age ?title WHERE {
  ?person foaf:name ?name ;
          foaf:age ?age ;
          foaf:title ?title .
}
ORDER BY ?age
EOF

cat > "$QUERIES_DIR/people_relationships.sparql" << 'EOF'
PREFIX foaf: <http://xmlns.com/foaf/0.1/>

SELECT ?person1 ?person2 WHERE {
  ?p1 foaf:name ?person1 ;
      foaf:knows ?p2 .
  ?p2 foaf:name ?person2 .
}
ORDER BY ?person1 ?person2
EOF

# Products queries
cat > "$QUERIES_DIR/products_basic.sparql" << 'EOF'
PREFIX schema: <https://schema.org/>

SELECT ?name ?price ?brand ?category WHERE {
  ?product schema:name ?name ;
           schema:price ?price ;
           schema:brand ?brand ;
           schema:category ?cat .
  ?cat schema:name ?category .
}
ORDER BY ?price
EOF

cat > "$QUERIES_DIR/products_ratings.sparql" << 'EOF'
PREFIX schema: <https://schema.org/>

SELECT ?name ?rating ?reviews WHERE {
  ?product schema:name ?name ;
           schema:aggregateRating ?rating_obj .
  ?rating_obj schema:ratingValue ?rating ;
              schema:reviewCount ?reviews .
}
ORDER BY DESC(?rating)
EOF

# Publications queries
cat > "$QUERIES_DIR/publications_basic.sparql" << 'EOF'
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX dcterms: <http://purl.org/dc/terms/>
PREFIX bibo: <http://purl.org/ontology/bibo/>

SELECT ?title ?author ?year WHERE {
  ?paper dc:title ?title ;
         dc:creator ?creator ;
         dcterms:issued ?date .
  ?creator foaf:name ?author .
  BIND(YEAR(?date) AS ?year)
}
ORDER BY DESC(?year)
EOF

# Locations queries
cat > "$QUERIES_DIR/locations_basic.sparql" << 'EOF'
PREFIX gn: <http://www.geonames.org/ontology#>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>

SELECT ?name ?country ?population ?lat ?long WHERE {
  ?location gn:name ?name ;
            gn:parentCountry ?country_obj ;
            gn:population ?population ;
            geo:lat ?lat ;
            geo:long ?long .
  ?country_obj gn:name ?country .
}
ORDER BY DESC(?population)
EOF

# Datatypes queries
cat > "$QUERIES_DIR/datatypes_numeric.sparql" << 'EOF'
PREFIX ex: <http://example.org/datatypes/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

SELECT ?label ?decimal ?float ?integer WHERE {
  ?example rdfs:label ?label ;
           ex:decimalValue ?decimal ;
           ex:floatValue ?float ;
           ex:largeInteger ?integer .
}
EOF

# Execute queries if stores were created successfully
if [ -d "$STORES_DIR" ] && [ "$(ls -A $STORES_DIR)" ]; then
    echo -e "${YELLOW}🔍 Executing sample queries and generating results...${NC}"

    execute_query "people" "$QUERIES_DIR/people_basic.sparql" "people_basic.json" "people basic info"
    execute_query "people" "$QUERIES_DIR/people_relationships.sparql" "people_relationships.json" "people relationships"
    execute_query "products" "$QUERIES_DIR/products_basic.sparql" "products_basic.json" "products basic info"
    execute_query "products" "$QUERIES_DIR/products_ratings.sparql" "products_ratings.json" "products ratings"
    execute_query "publications" "$QUERIES_DIR/publications_basic.sparql" "publications_basic.json" "publications basic info"
    execute_query "locations" "$QUERIES_DIR/locations_basic.sparql" "locations_basic.json" "locations basic info"
    execute_query "datatypes" "$QUERIES_DIR/datatypes_numeric.sparql" "datatypes_numeric.json" "datatypes numeric"
else
    echo -e "${RED}❌ No stores were created successfully${NC}"
fi

echo -e "${GREEN}🎉 Demo setup complete!${NC}"
echo ""
echo "📂 Demo Structure:"
echo "  $STORES_DIR/     - Oxigraph stores"
echo "  $QUERIES_DIR/    - SPARQL query files"
echo "  $RESULTS_DIR/    - JSON query results for Typst"
echo ""
echo "🚀 Next Steps:"
echo "  1. Explore the generated stores and queries"
echo "  2. Run 'typst compile demo.typ' to generate the demo document"
echo "  3. Try your own queries with: $TYPOX_BIN query -s $STORES_DIR/combined -q 'YOUR_QUERY'"
echo ""
echo "💡 Example Usage:"
echo "  # Query the combined store"
echo "  $TYPOX_BIN query -s $STORES_DIR/combined -q \"SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 10\""
echo ""
echo "  # Load additional data"
echo "  $TYPOX_BIN load -s $STORES_DIR/my_store -f my_data.ttl"