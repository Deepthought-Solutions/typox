# Typst Package Publishing Guide

This guide provides comprehensive instructions for publishing the Oxload package to the official Typst packages repository at [github.com/typst/packages](https://github.com/typst/packages).

## Table of Contents

- [Overview](#overview)
- [Pre-Publishing Checklist](#pre-publishing-checklist)
- [Package Structure](#package-structure)
- [Publishing Process](#publishing-process)
- [Automation Tools](#automation-tools)
- [Post-Publication](#post-publication)
- [Version Management](#version-management)
- [Troubleshooting](#troubleshooting)

## Overview

### What Gets Published

**ONLY the WASM plugin** (contents of `typst-package/`) will be published to the Typst packages repository. The CLI tool is distributed separately via:
- Cargo: `cargo install typox`
- GitHub Releases
- Direct repository cloning

### Package Details

- **Package Name**: `oxload`
- **Namespace**: `@preview` (official preview namespace)
- **Current Version**: `0.1.0`
- **Repository**: https://github.com/deepthought-solutions/typox
- **License**: MIT

### Target Users

Package users will install via:
```typst
#import "@preview/oxload:0.1.0": load-turtle, query-memory
```

They will have access to WASM plugin functions only (no CLI-based functions).

## Pre-Publishing Checklist

### ✅ Required Items

Use this checklist before each release:

#### 1. Package Files

- [ ] `typst-package/README.md` exists with comprehensive documentation
- [ ] `typst-package/typst.toml` has correct version, description, and metadata
- [ ] `typst-package/lib.typ` contains all public API functions
- [ ] `typst-package/typox.wasm` is built and optimized
- [ ] Root `LICENSE` file exists (MIT license)

#### 2. WASM Binary Optimization

- [ ] WASM binary is built with release profile
- [ ] `wasm-opt -Oz` optimization applied (if available)
- [ ] Binary size is acceptable (target: <1MB, current: ~1.2MB)

Run these commands:
```bash
# Build WASM
./build-wasm.sh

# Check size
ls -lh typst-package/typox.wasm

# Optimize (if wasm-opt is available)
wasm-opt -Oz typst-package/typox.wasm -o typst-package/typox.wasm
```

#### 3. Documentation

- [ ] Package README has:
  - Quick start example that works immediately
  - Complete API reference
  - Multiple usage examples
  - Type conversion table
  - Error handling guidance
  - Limitations clearly stated
- [ ] Examples compile without errors
- [ ] All WASM functions are documented
- [ ] Legacy CLI functions marked as OBSOLETE

#### 4. Code Quality

- [ ] All examples in README compile successfully
- [ ] `demo-wasm.typ` compiles without errors
- [ ] No syntax errors in `lib.typ`
- [ ] No hardcoded paths or local dependencies
- [ ] All imports use relative paths within package

Test compilation:
```bash
typst compile demo-wasm.typ /tmp/test-output.pdf
```

#### 5. Version Consistency

- [ ] `typst-package/typst.toml` version matches release version
- [ ] `plugin/Cargo.toml` version updated (optional, for tracking)
- [ ] Git tag created for release
- [ ] CHANGELOG updated with release notes

#### 6. Legal & Metadata

- [ ] LICENSE file in repository root
- [ ] Copyright headers in source files
- [ ] Repository URL correct in `typst.toml`
- [ ] Authors list accurate
- [ ] Keywords relevant and useful

### ⚠️ Things to Avoid

- [ ] No large binary files beyond the WASM plugin
- [ ] No generated PDFs or documentation files
- [ ] No test data or development-only files
- [ ] No `.git` directory or git-related files
- [ ] No CLI-based functionality in public API

## Package Structure

### Required Structure for Submission

When submitting to `typst/packages`, your package will be placed at:
```
packages/preview/oxload/{version}/
```

### Files to Include

```
typst-package/
├── README.md          # Package documentation (REQUIRED)
├── typst.toml         # Package manifest (REQUIRED)
├── lib.typ            # Main package file (REQUIRED)
└── typox.wasm         # WASM plugin binary (REQUIRED)
```

### Files to EXCLUDE

Do NOT include these in the package submission:
- `target/` - Rust build artifacts
- `*.pdf` - Generated PDFs
- `.git/` - Git metadata
- `demo*.typ` - Demo files (unless as examples/)
- `.env`, `*.env` - Environment files
- `node_modules/` - If any JS tools used

### typst.toml Requirements

Verify your `typst.toml` contains all required fields:

```toml
[package]
name = "oxload"
version = "0.1.0"
entrypoint = "lib.typ"
authors = ["Typox Project Contributors"]
license = "MIT"
description = "Load RDF data from Oxigraph stores into Typst documents"
repository = "https://github.com/deepthought-solutions/typox"
keywords = ["rdf", "sparql", "oxigraph", "data"]

[tool.typst-ts]
exclude = ["target/"]
```

**Important:** The `name` field determines the import path: `@preview/{name}:0.1.0`

## Publishing Process

### Step-by-Step Submission

#### Step 1: Prepare Package Directory

Run the automation script (see [Automation Tools](#automation-tools)):

```bash
./scripts/prepare-typst-package.sh
```

Or manually:

```bash
# Verify package structure
cd typst-package
ls -la
# Should show: README.md, typst.toml, lib.typ, typox.wasm

# Test compilation
cd ..
typst compile demo-wasm.typ /tmp/test.pdf
```

#### Step 2: Fork typst/packages Repository

```bash
# On GitHub, fork: https://github.com/typst/packages

# Clone your fork
git clone https://github.com/YOUR-USERNAME/packages.git
cd packages

# Add upstream remote
git remote add upstream https://github.com/typst/packages.git
```

**Tip:** Use sparse checkout to avoid downloading all packages:

```bash
git clone --filter=blob:none --sparse https://github.com/YOUR-USERNAME/packages.git
cd packages
git sparse-checkout set packages/preview/
```

#### Step 3: Create Package Directory

```bash
# Create directory for your package version
mkdir -p packages/preview/oxload/0.1.0

# Copy package files
cp -r /path/to/typox/typst-package/* packages/preview/oxload/0.1.0/

# Verify structure
ls -la packages/preview/oxload/0.1.0/
# Should show: README.md, typst.toml, lib.typ, typox.wasm

# Check file sizes
du -sh packages/preview/oxload/0.1.0/*
```

#### Step 4: Test Package Locally

Before submitting, test the package as users will use it:

```bash
# Create test document
cat > /tmp/test-oxload.typ << 'EOF'
#import "/packages/preview/oxload/0.1.0/lib.typ": load-turtle, query-memory

#load-turtle("
@prefix ex: <http://example.org/> .
ex:test ex:name 'Test' ; ex:value 42 .
")

#let results = query-memory("SELECT ?name ?value WHERE { ?x ex:name ?name ; ex:value ?value }")
#results
EOF

# Compile test document
cd packages
typst compile --root . /tmp/test-oxload.typ /tmp/test-output.pdf

# Verify output
ls -lh /tmp/test-output.pdf
```

#### Step 5: Create Pull Request

```bash
# Create branch
cd packages
git checkout -b add-oxload-0.1.0

# Add files
git add packages/preview/oxload/0.1.0/

# Commit with descriptive message
git commit -m "Add oxload 0.1.0 - RDF/SPARQL integration for Typst

- Native RDF processing via WASM plugin
- SPARQL SELECT query support
- In-memory named stores
- Smart type preservation for RDF datatypes"

# Push to your fork
git push origin add-oxload-0.1.0
```

Then on GitHub:
1. Navigate to your fork: `https://github.com/YOUR-USERNAME/packages`
2. Click "Compare & pull request"
3. Fill out the PR description:

```markdown
# Add oxload 0.1.0

## Package Description
Oxload provides native RDF/SPARQL integration for Typst documents through a WebAssembly plugin. Load Turtle data into in-memory stores and query with SPARQL directly in your templates.

## Features
- Native WASM integration (no external dependencies)
- In-memory RDF stores with SPARQL SELECT support
- Automatic RDF datatype to JSON type conversion
- Multiple named stores support

## Testing
- [x] All examples compile successfully
- [x] Package loads without errors
- [x] Functions work as documented
- [x] No external dependencies required

## Repository
https://github.com/deepthought-solutions/typox

## License
MIT License
```

4. Submit the pull request

#### Step 6: CI Validation

The Typst packages repository has automated CI that will:
- Validate `typst.toml` syntax
- Check for required files
- Verify examples compile
- Check package size limits

Monitor the CI results and fix any issues if checks fail.

#### Step 7: Review Process

Maintainers will review your submission for:
- Code quality and safety
- Documentation completeness
- Usefulness to the community
- Compliance with package guidelines

**Response time:** Usually within 1-2 weeks

#### Step 8: Merge and Publication

Once approved and merged:
- Package becomes available within ~30 minutes
- Users can import via `@preview/oxload:0.1.0`
- Package appears in the [Typst Universe](https://typst.app/universe)

Verify publication:
```bash
# Test from fresh directory
mkdir /tmp/test-published
cd /tmp/test-published

cat > test.typ << 'EOF'
#import "@preview/oxload:0.1.0": load-turtle, query-memory

#load-turtle("@prefix ex: <http://example.org/> . ex:item ex:value 42 .")
#let results = query-memory("SELECT ?value WHERE { ?x ex:value ?value }")
Results: #results
EOF

typst compile test.typ output.pdf
```

## Automation Tools

### Package Preparation Script

Use the provided script to automate pre-publication checks:

```bash
./scripts/prepare-typst-package.sh [version]
```

**What it does:**
1. Verifies WASM binary exists and is optimized
2. Checks required files (README, typst.toml, lib.typ, LICENSE)
3. Validates typst.toml syntax
4. Tests package compilation with demo
5. Displays file sizes
6. Shows checklist of remaining manual steps

**Example output:**
```
🔧 Typst Package Preparation Script
====================================

Version: 0.1.0
Package directory: /path/to/typox/typst-package

✓ WASM binary exists (1.2MB)
✓ README.md exists
✓ typst.toml exists
✓ lib.typ exists
✓ LICENSE exists in root
✓ Demo compiles successfully

File sizes:
  lib.typ: 7.1K
  typox.wasm: 1.2M
  README.md: 8.5K
  Total: 1.3M

Next steps:
1. Fork https://github.com/typst/packages
2. Run: ./scripts/submit-package.sh 0.1.0 /path/to/packages
```

See full script in [scripts/prepare-typst-package.sh](../scripts/prepare-typst-package.sh)

### Package Submission Helper

Use this script to copy files to your packages fork:

```bash
./scripts/submit-package.sh <version> <packages-repo-path>
```

**What it does:**
1. Creates package directory structure
2. Copies required files
3. Validates structure
4. Tests compilation
5. Generates git commit message

**Example:**
```bash
./scripts/submit-package.sh 0.1.0 ~/src/packages
```

See full script in [scripts/submit-package.sh](../scripts/submit-package.sh)

## Post-Publication

### Announcement

After publication, announce the package:

1. **GitHub Release**: Create release on main repository
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

2. **Social Media**: Share on relevant platforms
   - Twitter/X with #typst hashtag
   - Relevant Reddit communities (r/typst if exists)
   - Typst Discord/community channels

3. **Documentation**: Update main README with package installation instructions

### Monitoring

Track package usage:
- Monitor GitHub issues for bug reports
- Watch Typst Universe for ratings/comments
- Track download statistics (if available)

### Support

Respond to:
- GitHub issues about the package
- Questions in Typst community
- Pull requests for improvements

## Version Management

### Semantic Versioning

Follow [SemVer](https://semver.org/) for versions:

- **MAJOR** (1.0.0): Breaking changes to API
- **MINOR** (0.1.0): New features, backwards compatible
- **PATCH** (0.1.1): Bug fixes, backwards compatible

### Version Update Workflow

When releasing a new version (e.g., 0.2.0):

#### 1. Update Version Numbers

```bash
# Update package manifest
vim typst-package/typst.toml
# Change: version = "0.2.0"

# Update plugin Cargo.toml (optional)
vim plugin/Cargo.toml
# Change: version = "0.2.0"
```

#### 2. Update Documentation

```bash
# Update import examples in READMEs
# Change all: @preview/oxload:0.1.0
# To: @preview/oxload:0.2.0
```

#### 3. Rebuild WASM

```bash
./build-wasm.sh
```

#### 4. Test New Version

```bash
typst compile demo-wasm.typ /tmp/test-v0.2.0.pdf
```

#### 5. Create Git Tag

```bash
git add .
git commit -m "Release v0.2.0"
git tag -a v0.2.0 -m "Release version 0.2.0

- Added feature X
- Fixed bug Y
- Improved performance Z"

git push origin main
git push origin v0.2.0
```

#### 6. Submit to Typst Packages

Follow the [Publishing Process](#publishing-process) again with new version:

```bash
mkdir -p packages/preview/oxload/0.2.0
cp typst-package/* packages/preview/oxload/0.2.0/
# ... create PR
```

### Version Coordination

Keep these versions aligned:

| File | Version Field | Purpose |
|------|---------------|---------|
| `typst-package/typst.toml` | `version` | **PRIMARY** - Package version users see |
| `plugin/Cargo.toml` | `version` | Rust crate version (can diverge) |
| `Cargo.toml` (root) | `version` | CLI tool version (independent) |
| Git tags | `v0.1.0` | Release markers |

**Rule**: Always update `typst-package/typst.toml` first, others are optional.

### Breaking Changes

If introducing breaking changes (major version bump):

1. **Document Migration**: Create migration guide
2. **Deprecation Period**: Mark old functions as deprecated first
3. **Announcement**: Clearly communicate breaking changes
4. **Examples**: Update all examples and documentation

Example migration guide:
```markdown
# Migrating from 0.x to 1.0

## Breaking Changes

### Function Renames
- `load-turtle()` → `load-rdf-turtle()`
- `query-memory()` → `sparql-query()`

### API Changes
- `oxquery()` now requires store name as first parameter
- Error handling changed from panic to Result type

## Migration Steps
1. Update imports: `@preview/oxload:1.0.0`
2. Rename function calls as shown above
3. Wrap queries in error handlers
```

## Troubleshooting

### Common Issues

#### Issue: CI Validation Fails

**Error**: "Package manifest validation failed"

**Solution**:
```bash
# Validate typst.toml locally
typst compile --root typst-package typst-package/lib.typ /tmp/test.pdf

# Check for required fields
cat typst-package/typst.toml
```

#### Issue: Examples Don't Compile

**Error**: "Failed to compile example in README"

**Solution**:
- Test every code block in README manually
- Ensure no hardcoded paths
- Verify WASM plugin loads correctly
- Check for typos in example code

#### Issue: Package Too Large

**Error**: "Package exceeds size limit"

**Solution**:
```bash
# Optimize WASM binary
wasm-opt -Oz typst-package/typox.wasm -o typst-package/typox.wasm

# Remove unnecessary files
rm typst-package/*.pdf
rm typst-package/.DS_Store

# Check sizes
du -sh typst-package/*
```

#### Issue: Import Path Doesn't Work

**Error**: "Package not found: @preview/oxload:0.1.0"

**Solution**:
- Wait 30 minutes after PR merge
- Clear Typst cache: `rm -rf ~/.cache/typst`
- Check package name in typst.toml matches import
- Verify version number is correct

#### Issue: WASM Plugin Fails to Load

**Error**: "Failed to load plugin"

**Solution**:
```bash
# Rebuild with correct target
rustup target add wasm32-unknown-unknown
cd plugin
cargo clean
cargo build --target wasm32-unknown-unknown --release

# Copy to package
cp target/wasm32-unknown-unknown/release/typox.wasm ../typst-package/
```

#### Issue: Legacy Functions Cause Confusion

**Error**: Users try to use `oxload()` which requires CLI

**Solution**:
- Ensure OBSOLETE warnings are clear in lib.typ
- Update package README to only show WASM functions
- Consider removing legacy functions in next major version
- Add FAQ section explaining the difference

### Getting Help

If you encounter issues:

1. **Typst Documentation**: https://typst.app/docs/
2. **Package Guidelines**: https://github.com/typst/packages/blob/main/docs/README.md
3. **Typst Discord**: https://discord.gg/2uDybryKPe
4. **GitHub Issues**: https://github.com/typst/typst/issues

## Appendices

### Appendix A: Checklist for First-Time Publishers

- [ ] Read full Typst package documentation
- [ ] Understand Git/GitHub workflow (fork, branch, PR)
- [ ] Have GitHub account with verified email
- [ ] Understand semantic versioning
- [ ] Read through examples in typst/packages repo
- [ ] Join Typst community channels for support

### Appendix B: Size Optimization Tips

To reduce WASM binary size:

1. **Compile with opt-level**:
   ```toml
   [profile.release]
   opt-level = "z"  # Optimize for size
   lto = true
   codegen-units = 1
   strip = true
   ```

2. **Use wasm-opt**:
   ```bash
   wasm-opt -Oz input.wasm -o output.wasm
   ```

3. **Remove debug info**:
   ```bash
   wasm-strip typox.wasm
   ```

4. **Feature flags**: Disable unused features
   ```toml
   [dependencies]
   oxigraph = { version = "0.4", default-features = false }
   ```

### Appendix C: Example PR Descriptions

**Initial Version PR**:
```markdown
# Add oxload 0.1.0 - RDF/SPARQL integration

First release of oxload package for integrating RDF data into Typst.

## Features
- Load Turtle/N3 RDF data
- SPARQL SELECT queries
- In-memory named stores
- Automatic type conversion

## Testing
Compiled all examples successfully. Tested with demo document.

## License
MIT
```

**Update PR**:
```markdown
# Update oxload to 0.1.1

Bug fix release.

## Changes
- Fixed type conversion for xsd:decimal
- Improved error messages
- Updated documentation examples

## Backwards Compatibility
Fully backwards compatible with 0.1.0.
```

### Appendix D: Quick Reference Commands

```bash
# Build WASM
./build-wasm.sh

# Test compilation
typst compile demo-wasm.typ /tmp/test.pdf

# Check file sizes
ls -lh typst-package/

# Prepare for publication
./scripts/prepare-typst-package.sh

# Submit package
./scripts/submit-package.sh 0.1.0 ~/src/packages

# Create release
git tag -a v0.1.0 -m "Release 0.1.0"
git push origin v0.1.0

# Test published package (after merge)
mkdir /tmp/test && cd /tmp/test
cat > test.typ << 'EOF'
#import "@preview/oxload:0.1.0": load-turtle, query-memory
#load-turtle("@prefix ex: <http://example.org/> . ex:x ex:y 42 .")
#query-memory("SELECT * WHERE { ?s ?p ?o }")
EOF
typst compile test.typ output.pdf
```

---

## Summary

Publishing to the Typst packages repository involves:

1. ✅ **Prepare**: Ensure all files are ready, optimized, and tested
2. 🍴 **Fork**: Fork typst/packages repository
3. 📦 **Package**: Copy files to correct directory structure
4. 🧪 **Test**: Compile examples locally
5. 📝 **PR**: Submit pull request with clear description
6. ⏳ **Wait**: CI validates and maintainers review
7. 🎉 **Publish**: Package becomes available after merge

For the first release, budget 2-4 hours for preparation and 1-2 weeks for review. Subsequent releases are faster.

**Next Steps:**
1. Review the [Pre-Publishing Checklist](#pre-publishing-checklist)
2. Run `./scripts/prepare-typst-package.sh`
3. Follow the [Publishing Process](#publishing-process)

Good luck! 🚀
