#!/bin/bash

# Build script for Typox WASM plugin
# Copyright (c) 2024 Typox Project Contributors
# Licensed under the MIT License

set -e

echo "Building Typox WASM Plugin..."

# Check if we have the wasm32-unknown-unknown target
if ! rustup target list --installed | grep -q wasm32-unknown-unknown; then
    echo "Installing wasm32-unknown-unknown target..."
    rustup target add wasm32-unknown-unknown
fi

# Build the WASM plugin in release mode
echo "Compiling plugin to WebAssembly..."
cd plugin
cargo build --target wasm32-unknown-unknown --release

# Copy the built WASM file to the typst-package directory
echo "Copying WASM file to Typst package..."
cp target/wasm32-unknown-unknown/release/typox_plugin.wasm ../typst-package/typox.wasm

echo "WASM plugin built successfully!"
echo "Plugin location: typst-package/typox.wasm"

# Optional: Check if wasm-opt is available to optimize size
if command -v wasm-opt &> /dev/null; then
    echo "Optimizing WASM file with wasm-opt..."
    wasm-opt -Oz -o ../typst-package/typox.wasm ../typst-package/typox.wasm
    echo "WASM optimization complete!"
else
    echo "Note: wasm-opt not found. Consider installing it to reduce WASM file size."
fi

cd ..

echo "Build complete! You can now use the WASM plugin with Typst."