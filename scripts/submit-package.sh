#!/bin/bash
# Typst Package Submission Helper Script
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

# Parse arguments
VERSION="$1"
PACKAGES_REPO="$2"

if [ -z "$VERSION" ] || [ -z "$PACKAGES_REPO" ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    echo ""
    echo "Usage: $0 <version> <packages-repo-path>"
    echo ""
    echo "Example:"
    echo "  $0 0.1.0 ~/src/packages"
    echo ""
    exit 1
fi

# Validate packages repository
if [ ! -d "$PACKAGES_REPO" ]; then
    echo -e "${RED}Error: Packages repository not found: $PACKAGES_REPO${NC}"
    echo ""
    echo "Please clone the packages repository first:"
    echo "  git clone https://github.com/YOUR-USERNAME/packages.git"
    echo ""
    exit 1
fi

if [ ! -d "$PACKAGES_REPO/.git" ]; then
    echo -e "${RED}Error: Not a git repository: $PACKAGES_REPO${NC}"
    exit 1
fi

# Package name from typst.toml
PACKAGE_NAME=$(grep '^name = ' "$PACKAGE_DIR/typst.toml" | sed 's/name = "\(.*\)"/\1/')

if [ -z "$PACKAGE_NAME" ]; then
    echo -e "${RED}Error: Could not determine package name from typst.toml${NC}"
    exit 1
fi

TARGET_DIR="$PACKAGES_REPO/packages/preview/$PACKAGE_NAME/$VERSION"

echo -e "${BLUE}📦 Typst Package Submission Helper${NC}"
echo "===================================="
echo ""
echo "Package: $PACKAGE_NAME"
echo "Version: $VERSION"
echo "Source: $PACKAGE_DIR"
echo "Target: $TARGET_DIR"
echo ""

# Step 1: Check if target already exists
if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}⚠ Warning: Target directory already exists${NC}"
    read -p "Overwrite existing directory? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 1
    fi
    rm -rf "$TARGET_DIR"
fi

# Step 2: Create directory structure
echo -e "${BLUE}Step 1: Creating directory structure...${NC}"
mkdir -p "$TARGET_DIR"
echo -e "${GREEN}✓${NC} Created: $TARGET_DIR"
echo ""

# Step 3: Copy package files
echo -e "${BLUE}Step 2: Copying package files...${NC}"

FILES_TO_COPY=(
    "README.md"
    "typst.toml"
    "lib.typ"
    "typox.wasm"
)

for file in "${FILES_TO_COPY[@]}"; do
    if [ -f "$PACKAGE_DIR/$file" ]; then
        cp "$PACKAGE_DIR/$file" "$TARGET_DIR/"
        SIZE=$(ls -lh "$TARGET_DIR/$file" | awk '{print $5}')
        echo -e "${GREEN}✓${NC} Copied: $file ($SIZE)"
    else
        echo -e "${RED}✗${NC} Missing: $file"
        exit 1
    fi
done

echo ""

# Step 4: Validate structure
echo -e "${BLUE}Step 3: Validating structure...${NC}"

REQUIRED_FILES=("README.md" "typst.toml" "lib.typ")
ALL_PRESENT=true

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$TARGET_DIR/$file" ]; then
        echo -e "${GREEN}✓${NC} $file present"
    else
        echo -e "${RED}✗${NC} $file missing"
        ALL_PRESENT=false
    fi
done

if [ ! "$ALL_PRESENT" = true ]; then
    echo -e "${RED}Error: Missing required files${NC}"
    exit 1
fi

echo ""

# Step 5: Test compilation
echo -e "${BLUE}Step 4: Testing compilation in packages context...${NC}"

TEST_FILE="/tmp/typox-package-test-$$.typ"
cat > "$TEST_FILE" << EOF
#import "/packages/preview/$PACKAGE_NAME/$VERSION/lib.typ": load-turtle, query-memory

#load-turtle("
@prefix ex: <http://example.org/> .
ex:item ex:name 'Test' ; ex:value 42 .
")

#let results = query-memory("SELECT ?name ?value WHERE { ?x ex:name ?name ; ex:value ?value }")

= Test Results

#if results.len() > 0 [
  Results found: #results.len() row(s)

  #for result in results [
    - Name: #result.name, Value: #result.value
  ]
] else [
  No results (test failed)
]
EOF

cd "$PACKAGES_REPO"
if typst compile --root . "$TEST_FILE" /tmp/test-output-$$.pdf 2>&1; then
    echo -e "${GREEN}✓${NC} Test compilation successful"
    rm -f "$TEST_FILE" /tmp/test-output-$$.pdf
else
    echo -e "${RED}✗${NC} Test compilation failed"
    echo ""
    echo "Debug: Try manually:"
    echo "  cd $PACKAGES_REPO"
    echo "  typst compile --root . $TEST_FILE /tmp/test.pdf"
    rm -f "$TEST_FILE"
    exit 1
fi

echo ""

# Step 6: Display file sizes
echo -e "${BLUE}Step 5: Package contents...${NC}"
echo ""
cd "$TARGET_DIR"
ls -lh | tail -n +2 | awk '{printf "  %s  %s\n", $5, $9}'
TOTAL_SIZE=$(du -sh . | awk '{print $1}')
echo ""
echo "  Total size: $TOTAL_SIZE"
echo ""

# Step 7: Git status
echo -e "${BLUE}Step 6: Preparing git commit...${NC}"

cd "$PACKAGES_REPO"

# Create branch
BRANCH_NAME="add-$PACKAGE_NAME-$VERSION"
if git rev-parse --verify "$BRANCH_NAME" &> /dev/null; then
    echo -e "${YELLOW}⚠ Branch $BRANCH_NAME already exists${NC}"
    read -p "Delete and recreate branch? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git branch -D "$BRANCH_NAME"
        git checkout -b "$BRANCH_NAME"
    else
        git checkout "$BRANCH_NAME"
    fi
else
    git checkout -b "$BRANCH_NAME"
fi

echo -e "${GREEN}✓${NC} Switched to branch: $BRANCH_NAME"
echo ""

# Stage files
git add "packages/preview/$PACKAGE_NAME/$VERSION/"
echo -e "${GREEN}✓${NC} Staged package files"
echo ""

# Generate commit message
COMMIT_MSG_FILE="/tmp/typox-commit-msg-$$.txt"
cat > "$COMMIT_MSG_FILE" << EOF
Add $PACKAGE_NAME $VERSION - RDF/SPARQL integration for Typst

Native RDF processing via WebAssembly plugin powered by Oxigraph.

Features:
- Load Turtle/N3 RDF data into in-memory stores
- Query with SPARQL SELECT
- Automatic type conversion from RDF to JSON
- Multiple named stores support
- No external dependencies

Repository: https://github.com/deepthought-solutions/typox
License: MIT
EOF

echo -e "${BLUE}Generated commit message:${NC}"
echo ""
cat "$COMMIT_MSG_FILE"
echo ""

# Prompt to commit
read -p "Create commit with this message? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    git commit -F "$COMMIT_MSG_FILE"
    echo -e "${GREEN}✓${NC} Commit created"
else
    echo -e "${YELLOW}⚠${NC} Commit not created (files still staged)"
fi

rm -f "$COMMIT_MSG_FILE"
echo ""

# Summary and next steps
echo -e "${BLUE}Summary${NC}"
echo "======="
echo ""
echo -e "${GREEN}✓ Package prepared successfully!${NC}"
echo ""
echo "Package location:"
echo "  $TARGET_DIR"
echo ""
echo "Git branch:"
echo "  $BRANCH_NAME"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. Push the branch to your fork:"
echo "   cd $PACKAGES_REPO"
echo "   git push origin $BRANCH_NAME"
echo ""
echo "2. Create pull request on GitHub:"
echo "   https://github.com/YOUR-USERNAME/packages"
echo "   → Click 'Compare & pull request'"
echo ""
echo "3. Fill in PR description:"
echo "   - Describe the package"
echo "   - List key features"
echo "   - Confirm testing done"
echo "   - Include repository link"
echo ""
echo "4. Submit and wait for review"
echo "   (Usually 1-2 weeks)"
echo ""
echo "For detailed instructions, see:"
echo "  specs/typst-package-publishing-guide.md"
echo ""

exit 0
