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

#import "typst-package/lib.typ": oxload, oxload-file

// Example usage of the oxload function
// Note: This requires pre-generated JSON files from the typox binary

= RDF Data Integration Example

// Example 1: Using oxload with store and query
// This will look for a file like "oxload-123456-789012.json" based on hashed parameters
#let people-data = oxload("/path/to/my/store", "
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT ?name ?age WHERE {
  ?person foaf:name ?name ;
  foaf:age ?age
}
LIMIT 5
")

== People Data
#for row in people-data [
  - *#row.name*: #row.age years old
]

// Example 2: Using oxload-file with a specific file
#let products-data = oxload-file("products.json")

== Products
#for product in products-data [
  - #product.name: $#product.price
]

// Example 3: Numbers are preserved as numbers for calculations
#let numeric-data = oxload-file("numbers.json")

== Numeric Calculations
#let total = numeric-data.fold(0, (acc, item) => acc + item.value)
Total value: #total