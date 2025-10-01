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
    echo ""
    echo "Note: If this tool doesn't exist yet, this is a placeholder for future use."
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
