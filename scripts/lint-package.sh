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
    echo ""
    echo "Note: If this tool doesn't exist yet, this is a placeholder for future use."
    exit 1
fi

# Run package linter
cd "$PACKAGE_DIR"
typst-package-check . --strict

echo ""
echo "✅ Linting complete!"
