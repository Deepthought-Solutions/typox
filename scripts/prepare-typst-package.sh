#!/bin/bash
# Typst Package Preparation Script
# Copyright (c) 2024 Typox Project Contributors
# Licensed under the MIT License

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_DIR="$PROJECT_ROOT/typst-package"

# Parse version argument or extract from typst.toml
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    if [ -f "$PACKAGE_DIR/typst.toml" ]; then
        VERSION=$(grep '^version = ' "$PACKAGE_DIR/typst.toml" | sed 's/version = "\(.*\)"/\1/')
    fi
fi

if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Could not determine version${NC}"
    echo "Usage: $0 [version]"
    echo "Or ensure version is set in typst-package/typst.toml"
    exit 1
fi

echo -e "${BLUE}🔧 Typst Package Preparation Script${NC}"
echo "===================================="
echo ""
echo "Version: $VERSION"
echo "Package directory: $PACKAGE_DIR"
echo ""

# Track errors
ERRORS=0
WARNINGS=0

# Helper functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# Step 1: Check required files
echo -e "${BLUE}Step 1: Checking required files...${NC}"

if [ -f "$PACKAGE_DIR/typox.wasm" ]; then
    WASM_SIZE=$(ls -lh "$PACKAGE_DIR/typox.wasm" | awk '{print $5}')
    check_pass "WASM binary exists ($WASM_SIZE)"

    # Check if wasm-opt is available
    if command -v wasm-opt &> /dev/null; then
        echo "  → wasm-opt is available for optimization"
        read -p "  → Run wasm-opt -Oz optimization? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "  → Optimizing WASM binary..."
            wasm-opt -Oz "$PACKAGE_DIR/typox.wasm" -o "$PACKAGE_DIR/typox.wasm.tmp"
            mv "$PACKAGE_DIR/typox.wasm.tmp" "$PACKAGE_DIR/typox.wasm"
            NEW_SIZE=$(ls -lh "$PACKAGE_DIR/typox.wasm" | awk '{print $5}')
            check_pass "WASM optimized (now $NEW_SIZE)"
        fi
    else
        check_warn "wasm-opt not found (install binaryen for size optimization)"
    fi
else
    check_fail "WASM binary missing: $PACKAGE_DIR/typox.wasm"
    echo "  → Run: ./build-wasm.sh"
fi

if [ -f "$PACKAGE_DIR/README.md" ]; then
    README_SIZE=$(ls -lh "$PACKAGE_DIR/README.md" | awk '{print $5}')
    check_pass "README.md exists ($README_SIZE)"
else
    check_fail "README.md missing"
fi

if [ -f "$PACKAGE_DIR/typst.toml" ]; then
    check_pass "typst.toml exists"

    # Validate version matches
    TOML_VERSION=$(grep '^version = ' "$PACKAGE_DIR/typst.toml" | sed 's/version = "\(.*\)"/\1/')
    if [ "$TOML_VERSION" = "$VERSION" ]; then
        check_pass "Version in typst.toml matches ($VERSION)"
    else
        check_fail "Version mismatch: typst.toml has $TOML_VERSION, expected $VERSION"
    fi
else
    check_fail "typst.toml missing"
fi

if [ -f "$PACKAGE_DIR/lib.typ" ]; then
    LIB_SIZE=$(ls -lh "$PACKAGE_DIR/lib.typ" | awk '{print $5}')
    check_pass "lib.typ exists ($LIB_SIZE)"
else
    check_fail "lib.typ missing"
fi

if [ -f "$PROJECT_ROOT/LICENSE" ]; then
    check_pass "LICENSE exists in root"
else
    check_fail "LICENSE missing in project root"
fi

echo ""

# Step 2: Validate package contents
echo -e "${BLUE}Step 2: Validating package contents...${NC}"

# Check for OBSOLETE warnings in lib.typ
if grep -q "OBSOLETE" "$PACKAGE_DIR/lib.typ"; then
    check_pass "Legacy functions marked as OBSOLETE"
else
    check_warn "Legacy functions may not be clearly marked"
fi

# Check for examples in README
if grep -q '```typst' "$PACKAGE_DIR/README.md"; then
    check_pass "README contains code examples"
else
    check_warn "README may be missing code examples"
fi

# Check for unwanted files
UNWANTED_FILES=()
[ -f "$PACKAGE_DIR/.DS_Store" ] && UNWANTED_FILES+=(".DS_Store")
[ -f "$PACKAGE_DIR/.gitignore" ] && UNWANTED_FILES+=(".gitignore")
[ -f "$PACKAGE_DIR/test.pdf" ] && UNWANTED_FILES+=("test.pdf")
[ -d "$PACKAGE_DIR/target" ] && UNWANTED_FILES+=("target/")

if [ ${#UNWANTED_FILES[@]} -eq 0 ]; then
    check_pass "No unwanted files in package directory"
else
    check_warn "Found unwanted files: ${UNWANTED_FILES[*]}"
    echo "  → Consider removing: cd $PACKAGE_DIR && rm -rf ${UNWANTED_FILES[*]}"
fi

echo ""

# Step 3: Test compilation
echo -e "${BLUE}Step 3: Testing compilation...${NC}"

if [ -f "$PROJECT_ROOT/demo-wasm.typ" ]; then
    if typst compile "$PROJECT_ROOT/demo-wasm.typ" /tmp/typox-test-$$.pdf &> /dev/null; then
        check_pass "demo-wasm.typ compiles successfully"
        rm -f /tmp/typox-test-$$.pdf
    else
        check_fail "demo-wasm.typ compilation failed"
        echo "  → Try: typst compile demo-wasm.typ /tmp/test.pdf"
    fi
else
    check_warn "demo-wasm.typ not found"
fi

# Test a minimal example
TEST_FILE="/tmp/typox-package-test-$$.typ"
cat > "$TEST_FILE" << 'EOF'
#import "typst-package/lib.typ": load-turtle, query-memory

#load-turtle("
@prefix ex: <http://example.org/> .
ex:test ex:value 42 .
")

#let results = query-memory("SELECT ?value WHERE { ?x ex:value ?value }")
#if results.len() > 0 [Test passed] else [Test failed]
EOF

cd "$PROJECT_ROOT"
if typst compile "$TEST_FILE" /tmp/typox-test-output-$$.pdf &> /dev/null; then
    check_pass "Minimal test example compiles"
    rm -f "$TEST_FILE" /tmp/typox-test-output-$$.pdf
else
    check_fail "Minimal test example failed"
    rm -f "$TEST_FILE"
fi

echo ""

# Step 4: Display file sizes
echo -e "${BLUE}Step 4: Package size analysis...${NC}"

if [ -d "$PACKAGE_DIR" ]; then
    echo ""
    echo "File sizes:"
    cd "$PACKAGE_DIR"
    ls -lh *.typ *.toml *.md *.wasm 2>/dev/null | awk '{printf "  %s: %s\n", $9, $5}'

    TOTAL_SIZE=$(du -sh . | awk '{print $1}')
    echo "  Total: $TOTAL_SIZE"
    echo ""

    # Warn if too large
    TOTAL_BYTES=$(du -s . | awk '{print $1}')
    if [ "$TOTAL_BYTES" -gt 2048 ]; then  # 2MB in KB
        check_warn "Package size is large ($TOTAL_SIZE). Consider optimization."
    else
        check_pass "Package size is reasonable ($TOTAL_SIZE)"
    fi
fi

echo ""

# Step 5: Check git status
echo -e "${BLUE}Step 5: Git status...${NC}"

cd "$PROJECT_ROOT"
if git rev-parse --git-dir > /dev/null 2>&1; then
    # Check for uncommitted changes
    if git diff --quiet && git diff --staged --quiet; then
        check_pass "No uncommitted changes"
    else
        check_warn "You have uncommitted changes"
        echo "  → Consider committing before publishing"
    fi

    # Check for version tag
    if git tag | grep -q "^v$VERSION$"; then
        check_pass "Git tag v$VERSION exists"
    else
        check_warn "Git tag v$VERSION not found"
        echo "  → Create tag: git tag -a v$VERSION -m \"Release $VERSION\""
    fi
else
    check_warn "Not a git repository"
fi

echo ""

# Summary
echo -e "${BLUE}Summary${NC}"
echo "======="
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}✗ Found $ERRORS error(s)${NC}"
    echo "  Please fix errors before publishing"
    echo ""
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $WARNINGS warning(s)${NC}"
    echo "  Consider addressing warnings before publishing"
    echo ""
else
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
fi

# Next steps
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. Fork repository:"
echo "   https://github.com/typst/packages"
echo ""
echo "2. Clone your fork:"
echo "   git clone https://github.com/YOUR-USERNAME/packages.git"
echo ""
echo "3. Run submission script:"
echo "   ./scripts/submit-package.sh $VERSION /path/to/packages"
echo ""
echo "4. Create pull request on GitHub"
echo ""
echo "For detailed instructions, see:"
echo "  specs/typst-package-publishing-guide.md"
echo ""

exit 0
