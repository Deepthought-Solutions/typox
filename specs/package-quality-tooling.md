# Typst Package Quality Tooling Specification

**Status**: Draft
**Version**: 1.0
**Date**: 2025-10-01
**Author**: Typox Project Contributors

## Overview

This specification outlines the implementation of quality assurance tools for the Typox Typst package, including linting, automated testing, and local package testing workflows. These tools ensure package quality before submission to the Typst package registry.

## Goals

1. **Automated Linting**: Validate package structure and content before publishing
2. **Automated Testing**: Run comprehensive tests on package functionality
3. **Local Testing**: Test package installation and usage without publishing
4. **CI Integration**: Automate quality checks in continuous integration pipeline
5. **Developer Experience**: Provide easy-to-use scripts for local validation

## Tool Integration

### 1. typst-package-check (Linting)

#### Purpose
Lint and validate package structure, metadata, and content against Typst package registry requirements.

#### Installation
```bash
# Install typst-package-check (assuming cargo-based tool)
cargo install typst-package-check

# Or via npm if available
npm install -g typst-package-check
```

#### Integration Points

**File: `scripts/lint-package.sh`**
```bash
#!/bin/bash
# Lint the Typst package for common issues

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_DIR="$PROJECT_ROOT/typst-package"

echo "🔍 Linting Typst Package..."
echo "============================"
echo ""

# Check if typst-package-check is installed
if ! command -v typst-package-check &> /dev/null; then
    echo "❌ Error: typst-package-check not found"
    echo "Install it with: cargo install typst-package-check"
    exit 1
fi

# Run package linter
cd "$PACKAGE_DIR"
typst-package-check . --strict

echo ""
echo "✅ Linting complete!"
```

**Checks Performed**:
- ✅ Manifest (typst.toml) validation
  - Required fields present
  - Valid semantic versioning
  - Valid categories and keywords
  - Description length (40-60 chars recommended)
- ✅ File structure
  - Required files present (README.md, LICENSE, lib.typ, typst.toml)
  - No unwanted files (.DS_Store, .git, test files)
- ✅ README validation
  - Contains code examples
  - Uses `@preview` import syntax
  - No emoji shortcodes
  - No unsupported markdown extensions
- ✅ Code quality
  - No deprecated functions without OBSOLETE markers
  - Proper function documentation
- ✅ Size constraints
  - Package size < 2MB warning
  - Individual file size checks

#### Custom Lint Rules

**File: `.typst-package-lint.toml`**
```toml
[rules]
# Enforce strict file inclusion
allowed_extensions = [".typ", ".toml", ".md", ".wasm", ".png", ".jpg"]
max_package_size_mb = 2
max_file_size_kb = 500

# Metadata validation
require_homepage = false
require_categories = true
max_keywords = 5
description_min_length = 40
description_max_length = 60

# Documentation requirements
require_readme_examples = true
require_license = true
require_changelog = false

# Naming conventions
forbid_typst_in_name = true
enforce_kebab_case = true
```

### 2. tytanic (Automated Testing)

#### Purpose
Framework for testing Typst packages with automated compilation tests, visual regression testing, and API validation.

#### Installation
```bash
# Install tytanic
cargo install tytanic

# Or via Typst package manager
typst package install tytanic
```

#### Test Structure

**Directory: `tests/package/`**
```
tests/package/
├── basic/
│   ├── test_load_turtle.typ
│   ├── test_query_memory.typ
│   └── expected/
│       ├── test_load_turtle.pdf
│       └── test_query_memory.pdf
├── integration/
│   ├── test_multiple_stores.typ
│   ├── test_type_conversion.typ
│   └── expected/
├── regression/
│   ├── test_prefix_handling.typ
│   └── expected/
└── tytanic.toml
```

**File: `tests/package/tytanic.toml`**
```toml
[package]
name = "typox-rdf"
version = "0.1.0"
test_root = "tests/package"

[settings]
# Compilation settings
compiler = "typst"
timeout_seconds = 30
parallel = true

# Visual comparison
compare_pdfs = true
pixel_tolerance = 0.01
compare_text = true

# Test discovery
test_pattern = "test_*.typ"
exclude_patterns = ["expected/", "fixtures/"]

[environment]
# Set environment variables for tests
TYPOX_TEST_MODE = "true"

[reporting]
format = "junit"
output = "test-results/junit.xml"
verbose = true
show_diffs = true
```

#### Test Implementation

**File: `tests/package/basic/test_load_turtle.typ`**
```typst
// Test: Basic Turtle loading
#import "/typst-package/lib.typ": load-turtle, query-memory

#set page(width: 200pt, height: 150pt)

#load-turtle("
@prefix ex: <http://example.org/> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .

ex:alice foaf:name 'Alice' ;
         foaf:age 30 .
ex:bob foaf:name 'Bob' ;
       foaf:age 25 .
")

#let people = query-memory("
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  SELECT ?name ?age WHERE {
    ?person foaf:name ?name ;
            foaf:age ?age
  }
  ORDER BY ?age
")

= Test Results

#assert(people.len() == 2, message: "Expected 2 people")
#assert(people.at(0).name == "Bob", message: "First person should be Bob")
#assert(people.at(0).age == 25, message: "Bob's age should be 25")

✅ Test Passed: Loaded #people.len() people
```

**File: `tests/package/integration/test_type_conversion.typ`**
```typst
// Test: RDF datatype to JSON conversion
#import "/typst-package/lib.typ": load-turtle, query-memory

#set page(width: 300pt, height: 200pt)

#load-turtle("
@prefix ex: <http://example.org/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

ex:item1 ex:int_val '42'^^xsd:integer ;
         ex:float_val '3.14'^^xsd:float ;
         ex:decimal_val '99.99'^^xsd:decimal ;
         ex:string_val 'hello' ;
         ex:bool_val 'true'^^xsd:boolean .
")

#let results = query-memory("
  SELECT ?int ?float ?decimal ?string ?bool WHERE {
    ex:item1 ex:int_val ?int ;
             ex:float_val ?float ;
             ex:decimal_val ?decimal ;
             ex:string_val ?string ;
             ex:bool_val ?bool .
  }
")

#let item = results.at(0)

= Type Conversion Test

// Validate types
#assert(type(item.int) == int, message: "Integer should be int type")
#assert(type(item.float) == float, message: "Float should be float type")
#assert(type(item.decimal) == float, message: "Decimal should be float type")
#assert(type(item.string) == str, message: "String should be str type")

// Validate values
#assert(item.int == 42)
#assert(item.float == 3.14)
#assert(item.decimal == 99.99)
#assert(item.string == "hello")

✅ All type conversions passed
```

**File: `scripts/test-package.sh`**
```bash
#!/bin/bash
# Run automated tests using tytanic

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🧪 Running Package Tests..."
echo "============================"
echo ""

# Check if tytanic is installed
if ! command -v tytanic &> /dev/null; then
    echo "❌ Error: tytanic not found"
    echo "Install it with: cargo install tytanic"
    exit 1
fi

# Build WASM if needed
if [ ! -f "$PROJECT_ROOT/typst-package/typox.wasm" ]; then
    echo "📦 Building WASM plugin first..."
    "$PROJECT_ROOT/build-wasm.sh"
fi

# Run tests
cd "$PROJECT_ROOT"
tytanic test --config tests/package/tytanic.toml

echo ""
echo "✅ All tests passed!"
```

### 3. typship (Local Package Testing)

#### Purpose
Local package installation and testing tool that simulates the Typst package registry environment without publishing.

#### Installation
```bash
cargo install typship
```

#### Configuration

**File: `.typship.toml`**
```toml
[package]
source = "typst-package"
name = "typox-rdf"

[local]
# Local package directory (simulates @preview namespace)
packages_dir = ".typship/packages"
cache_dir = ".typship/cache"

[test]
# Test documents that use the package
test_documents = [
    "demo-wasm.typ",
    "tests/integration/*.typ"
]

[hooks]
# Run before local install
pre_install = "./build-wasm.sh"

# Run after local install
post_install = "./scripts/test-package.sh"
```

**File: `scripts/local-install.sh`**
```bash
#!/bin/bash
# Install package locally using typship

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📦 Local Package Installation"
echo "============================="
echo ""

# Check if typship is installed
if ! command -v typship &> /dev/null; then
    echo "❌ Error: typship not found"
    echo "Install it with: cargo install typship"
    exit 1
fi

# Read version from typst.toml
VERSION=$(grep '^version = ' "$PROJECT_ROOT/typst-package/typst.toml" | sed 's/version = "\(.*\)"/\1/')

echo "Package: typox-rdf"
echo "Version: $VERSION"
echo ""

# Install locally
cd "$PROJECT_ROOT"
typship install --local

# Test the installation
echo ""
echo "🧪 Testing local installation..."
typship test

echo ""
echo "✅ Package installed locally!"
echo ""
echo "Usage in Typst documents:"
echo "  #import \"@preview/typox-rdf:$VERSION\": load-turtle, query-memory"
echo ""
echo "Installed at: .typship/packages/preview/typox-rdf/$VERSION/"
```

**File: `scripts/local-uninstall.sh`**
```bash
#!/bin/bash
# Uninstall local package

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"
typship uninstall --local

echo "✅ Package uninstalled from local registry"
```

## CI/CD Integration

### GitHub Actions Workflow

**File: `.github/workflows/package-quality.yml`**
```yaml
name: Package Quality Checks

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  lint:
    name: Lint Package
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable

      - name: Install typst-package-check
        run: cargo install typst-package-check

      - name: Run linter
        run: ./scripts/lint-package.sh

  test:
    name: Test Package
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          target: wasm32-unknown-unknown

      - name: Setup Typst
        uses: typst-community/setup-typst@v1
        with:
          typst-version: latest

      - name: Install tytanic
        run: cargo install tytanic

      - name: Build WASM plugin
        run: ./build-wasm.sh

      - name: Run tests
        run: ./scripts/test-package.sh

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-results/

  local-install:
    name: Test Local Installation
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          target: wasm32-unknown-unknown

      - name: Setup Typst
        uses: typst-community/setup-typst@v1

      - name: Install typship
        run: cargo install typship

      - name: Local install and test
        run: ./scripts/local-install.sh

  package-size:
    name: Check Package Size
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          target: wasm32-unknown-unknown

      - name: Build WASM
        run: ./build-wasm.sh

      - name: Check package size
        run: |
          cd typst-package
          TOTAL_SIZE=$(du -sh . | awk '{print $1}')
          TOTAL_BYTES=$(du -sb . | awk '{print $1}')
          MAX_BYTES=$((2 * 1024 * 1024))  # 2MB

          echo "Package size: $TOTAL_SIZE"

          if [ "$TOTAL_BYTES" -gt "$MAX_BYTES" ]; then
            echo "❌ Package too large! ($TOTAL_SIZE > 2MB)"
            exit 1
          fi

          echo "✅ Package size OK"
```

### Pre-commit Hooks

**File: `.husky/pre-commit`** (or `.git/hooks/pre-commit`)
```bash
#!/bin/bash
# Pre-commit hook for package quality

set -e

echo "🔍 Running pre-commit checks..."

# Only run if package files changed
PACKAGE_FILES=$(git diff --cached --name-only | grep "^typst-package/" || true)

if [ -n "$PACKAGE_FILES" ]; then
    echo "📦 Package files changed, running quality checks..."

    # Run linter
    if command -v typst-package-check &> /dev/null; then
        ./scripts/lint-package.sh
    else
        echo "⚠️  Warning: typst-package-check not installed (skipping)"
    fi

    # Run quick tests
    if command -v tytanic &> /dev/null && [ -f "typst-package/typox.wasm" ]; then
        ./scripts/test-package.sh --quick
    else
        echo "⚠️  Warning: tytanic not installed or WASM not built (skipping tests)"
    fi
fi

echo "✅ Pre-commit checks passed!"
```

## Development Workflow

### Daily Development

```bash
# 1. Make changes to package
vim typst-package/lib.typ

# 2. Build WASM
./build-wasm.sh

# 3. Run linter
./scripts/lint-package.sh

# 4. Run tests
./scripts/test-package.sh

# 5. Test locally
./scripts/local-install.sh
typst compile demo-wasm.typ test-output.pdf
```

### Before Publishing

```bash
# 1. Full preparation check
./scripts/prepare-typst-package.sh 0.1.0

# 2. Run all quality tools
./scripts/lint-package.sh
./scripts/test-package.sh
./scripts/local-install.sh

# 3. Manual testing
typst compile demo-wasm.typ

# 4. Submit to packages repository
./scripts/submit-package.sh 0.1.0 ~/path/to/packages
```

## Makefile Integration

**File: `Makefile`**
```makefile
.PHONY: help lint test local-install quality-check clean

help:
	@echo "Typox Package Quality Tools"
	@echo "============================"
	@echo ""
	@echo "Available targets:"
	@echo "  lint           - Run package linter"
	@echo "  test           - Run automated tests"
	@echo "  local-install  - Install package locally"
	@echo "  quality-check  - Run all quality checks"
	@echo "  clean          - Clean build artifacts"

lint:
	@./scripts/lint-package.sh

test: build-wasm
	@./scripts/test-package.sh

local-install: build-wasm
	@./scripts/local-install.sh

local-uninstall:
	@./scripts/local-uninstall.sh

quality-check: lint test local-install
	@echo "✅ All quality checks passed!"

build-wasm:
	@./build-wasm.sh

clean:
	@rm -rf .typship/
	@rm -rf test-results/
	@cd plugin && cargo clean
```

## Testing Strategy

### Test Categories

1. **Unit Tests** (`tests/package/basic/`)
   - Individual function testing
   - Basic RDF loading and querying
   - Error handling

2. **Integration Tests** (`tests/package/integration/`)
   - Multi-store operations
   - Complex SPARQL queries
   - Type conversion scenarios

3. **Regression Tests** (`tests/package/regression/`)
   - Previously fixed bugs
   - Edge cases
   - Performance benchmarks

4. **Visual Regression** (`tests/package/visual/`)
   - PDF output comparison
   - Layout consistency
   - Rendering accuracy

### Test Coverage Goals

- **Code Coverage**: 80%+ for lib.typ functions
- **SPARQL Coverage**: All SPARQL SELECT features
- **Type Coverage**: All XSD datatypes
- **Error Coverage**: All error paths tested

## Documentation

### For Developers

**File: `DEVELOPMENT.md`** (add section)
```markdown
## Quality Assurance Tools

### Linting
Run the linter before committing:
```bash
make lint
# or
./scripts/lint-package.sh
```

### Testing
Run automated tests:
```bash
make test
# or
./scripts/test-package.sh
```

### Local Testing
Install package locally to test:
```bash
make local-install
# or
./scripts/local-install.sh
```

Then test in your documents:
```typst
#import "@preview/typox-rdf:0.1.0": load-turtle, query-memory
```

### All Quality Checks
Run everything before publishing:
```bash
make quality-check
```
```

## Rollout Plan

### Phase 1: Setup (Week 1)
- [ ] Install and configure typst-package-check
- [ ] Create lint-package.sh script
- [ ] Add .typst-package-lint.toml configuration
- [ ] Run initial linting, fix issues

### Phase 2: Testing (Week 2)
- [ ] Install and configure tytanic
- [ ] Create test directory structure
- [ ] Write basic test cases
- [ ] Create test-package.sh script
- [ ] Achieve 50% test coverage

### Phase 3: Local Testing (Week 3)
- [ ] Install and configure typship
- [ ] Create .typship.toml configuration
- [ ] Create local-install.sh script
- [ ] Test full workflow locally

### Phase 4: CI/CD (Week 4)
- [ ] Create GitHub Actions workflow
- [ ] Add pre-commit hooks
- [ ] Create Makefile targets
- [ ] Document workflow in DEVELOPMENT.md
- [ ] Achieve 80% test coverage

### Phase 5: Refinement (Ongoing)
- [ ] Add visual regression tests
- [ ] Expand integration tests
- [ ] Performance benchmarks
- [ ] Continuous improvement

## Success Metrics

### Quality Metrics
- ✅ Zero linting errors
- ✅ 80%+ test coverage
- ✅ All tests passing in CI
- ✅ Package size < 2MB
- ✅ Local install works without errors

### Developer Experience
- ✅ < 5 minutes for full quality check
- ✅ Clear error messages
- ✅ One-command testing
- ✅ Automated CI feedback within 10 minutes

### Publishing Readiness
- ✅ All quality checks pass
- ✅ Documentation up to date
- ✅ Version consistency verified
- ✅ No breaking changes without major version bump

## Tools Reference

### typst-package-check
- **Purpose**: Lint package structure and metadata
- **Docs**: https://github.com/typst/typst-package-check
- **Config**: .typst-package-lint.toml

### tytanic
- **Purpose**: Automated Typst package testing
- **Docs**: https://github.com/tingerrr/tytanic
- **Config**: tests/package/tytanic.toml

### typship
- **Purpose**: Local package installation and testing
- **Docs**: https://github.com/typst/typship
- **Config**: .typship.toml

## Appendix

### Example Test Output

```
🧪 Running Package Tests...
============================

Running tests from: tests/package/

✅ basic/test_load_turtle.typ - PASSED (0.3s)
✅ basic/test_query_memory.typ - PASSED (0.2s)
✅ integration/test_multiple_stores.typ - PASSED (0.5s)
✅ integration/test_type_conversion.typ - PASSED (0.4s)
✅ regression/test_prefix_handling.typ - PASSED (0.3s)

Total: 5 tests
Passed: 5
Failed: 0
Skipped: 0
Duration: 1.7s

✅ All tests passed!
```

### Troubleshooting

**Issue**: typst-package-check not found
```bash
# Solution
cargo install typst-package-check
```

**Issue**: tytanic compilation errors
```bash
# Solution
./build-wasm.sh  # Rebuild WASM first
./scripts/test-package.sh
```

**Issue**: Local install fails
```bash
# Solution
./scripts/local-uninstall.sh  # Clean first
./scripts/local-install.sh
```
