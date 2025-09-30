# SPARQL Query Namespace Prefix Fix

## Problem Description
The setup_demo.sh script fails when executing SPARQL queries due to missing namespace prefix declarations. Specifically:

1. **datatypes_numeric.sparql query (lines 214-219)**: Uses `rdfs:label` without declaring the `rdfs` prefix
2. **publications_basic.sparql query (line 187)**: Uses `foaf:name` without declaring the `foaf` prefix

## Error Analysis
The SPARQL parser error occurs at line 5, character 22 in the datatypes_numeric query, which corresponds to the `rdfs:label` usage without proper prefix declaration.

Error details:
- Location: Line 5 (SELECT clause), character 22
- Issue: `rdfs` prefix not found in query namespace declarations
- Impact: Query execution fails, preventing demo setup completion

## Required Fixes

### 1. Fix datatypes_numeric.sparql
- **Location**: setup_demo.sh lines 214-219
- **Issue**: Missing `rdfs` prefix declaration
- **Solution**: Add `PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>` to the query

### 2. Fix publications_basic.sparql  
- **Location**: setup_demo.sh lines 178-191
- **Issue**: Missing `foaf` prefix declaration for `foaf:name` usage on line 187
- **Solution**: Add `PREFIX foaf: <http://xmlns.com/foaf/0.1/>` to the query

## Data Context
From examining `/samples/datatypes.ttl`, the RDF data uses:
- `rdfs:label` for human-readable labels
- `ex:decimalValue`, `ex:floatValue`, `ex:largeInteger` for numeric values

The query structure is correct, only the namespace prefix declarations are missing.

## Expected Outcome
After fixing both queries:
1. setup_demo.sh should run successfully without SPARQL parsing errors
2. All demo stores should be created and populated
3. All sample queries should execute and generate JSON results for Typst integration

## Implementation Priority
High - This blocks the entire demo setup process and prevents users from exploring Typox functionality.
