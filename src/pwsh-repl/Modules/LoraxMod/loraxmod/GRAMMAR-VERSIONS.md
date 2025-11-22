# Grammar Versions and Update Guide

This document tracks the source repositories, versions, and update procedures for all tree-sitter WASM grammars included in loraxMod.

## Current Grammar Versions

Last updated: **November 2025**

| Language   | Repository | Version/Commit | Language Version | Notes |
|------------|------------|----------------|------------------|-------|
| JavaScript | [tree-sitter/tree-sitter-javascript](https://github.com/tree-sitter/tree-sitter-javascript) | Latest (main) | 15 | Supports ES2024+, JSX |
| Python     | [tree-sitter/tree-sitter-python](https://github.com/tree-sitter/tree-sitter-python) | Latest (main) | 15 | Python 3.x syntax |
| Bash       | [tree-sitter/tree-sitter-bash](https://github.com/tree-sitter/tree-sitter-bash) | Latest (main) | 15 | POSIX + GNU extensions |
| PowerShell | [Airbus-CERT/tree-sitter-powershell](https://github.com/Airbus-CERT/tree-sitter-powershell) | Latest (main) | 15 | PowerShell 5.1+ |
| R          | [r-lib/tree-sitter-r](https://github.com/r-lib/tree-sitter-r) | Latest (main) | 15 | R6, S3, S4 classes |
| C#         | [tree-sitter/tree-sitter-c-sharp](https://github.com/tree-sitter/tree-sitter-c-sharp) | Latest (main) | 15 | C# 12 features |
| Rust       | [tree-sitter/tree-sitter-rust](https://github.com/tree-sitter/tree-sitter-rust) | Latest (main) | 15 | Rust 2021 edition |
| C          | [tree-sitter/tree-sitter-c](https://github.com/tree-sitter/tree-sitter-c) | Latest (main) | 15 | C11/C17 standards |
| CSS        | [tree-sitter/tree-sitter-css](https://github.com/tree-sitter/tree-sitter-css) | Latest (main) | 15 | CSS3 + preprocessors |
| Fortran    | [stadelmanma/tree-sitter-fortran](https://github.com/stadelmanma/tree-sitter-fortran) | Latest (main) | 15 | Fortran 90/95/03/08 |

## Grammar Details

### JavaScript
- **Source:** Official tree-sitter grammar
- **Supports:** ES2024+, JSX, TypeScript (via file extension)
- **WASM Size:** 403 KB
- **Update Frequency:** Active development, updates monthly

### Python
- **Source:** Official tree-sitter grammar
- **Supports:** Python 3.x syntax (not Python 2)
- **WASM Size:** 448 KB
- **Update Frequency:** Active development

### Bash
- **Source:** Official tree-sitter grammar
- **Supports:** POSIX shell + GNU bash extensions
- **WASM Size:** 1.4 MB
- **Update Frequency:** Stable, occasional updates

### PowerShell
- **Source:** Airbus CERT community grammar (most complete)
- **Supports:** PowerShell 5.1+ syntax
- **WASM Size:** 958 KB
- **Update Frequency:** Community-maintained
- **Note:** Alternative exists at tree-sitter/tree-sitter-powershell but less mature

### R
- **Source:** Official R community grammar
- **Supports:** R 4.x, R6/S3/S4 object systems
- **WASM Size:** 471 KB
- **Update Frequency:** Active development by R core contributors

### C#
- **Source:** Official tree-sitter grammar
- **Supports:** C# 12 and earlier
- **WASM Size:** 4.9 MB (largest due to language complexity)
- **Update Frequency:** Active development

### Rust
- **Source:** Official tree-sitter grammar
- **Supports:** Rust 2021 edition, all core language features
- **WASM Size:** TBD (to be built)
- **Update Frequency:** Active development by tree-sitter team

### C
- **Source:** Official tree-sitter grammar
- **Supports:** C11/C17 standards
- **WASM Size:** TBD (to be built)
- **Update Frequency:** Active development, stable grammar

### CSS
- **Source:** Official tree-sitter grammar
- **Supports:** CSS3, SCSS, Sass, Less preprocessors
- **WASM Size:** TBD (to be built)
- **Update Frequency:** Active development

### Fortran
- **Source:** Community grammar (stadelmanma)
- **Supports:** Fortran 90/95/03/08
- **WASM Size:** TBD (to be built)
- **Update Frequency:** Community-maintained
- **Note:** Not official tree-sitter org, but only available Fortran grammar

## How to Check for Updates

### Check Grammar Repository Updates
```bash
# Clone grammar repo and check recent commits
git clone https://github.com/tree-sitter/tree-sitter-javascript
cd tree-sitter-javascript
git log --oneline -10

# Check for breaking changes
git log --grep="BREAKING" --oneline
```

### Compare WASM File Sizes
```bash
# Current WASM size
ls -lh loraxMod/grammars/tree-sitter-javascript.wasm

# After rebuild, compare
ls -lh loraxMod/grammars/tree-sitter-javascript.wasm
```

### Test Compatibility
After updating, test with existing code:
```bash
# Test parsing a known file
node loraxMod/lib/index.js test-file.js

# Run vibe_tools test suite
cd vibe_tools/code_evolver
powershell.exe -ExecutionPolicy Bypass -File Track-CodeEvolution.ps1 -ClassName TestClass
```

## How to Update Grammars

### Prerequisites: Install emsdk

emsdk is **not** included in loraxMod. Install it once to a standard location:

**Windows:**
```powershell
# Clone to C:\tools (recommended)
cd C:\tools
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk

# Install and activate
emsdk install latest
emsdk activate latest
```

**Linux/macOS:**
```bash
# Clone to /usr/local or ~/emsdk
cd /usr/local  # or cd ~
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk

# Install and activate
./emsdk install latest
./emsdk activate latest
```

**Custom Location:**

If you install emsdk to a different directory, set the `EMSDK_ROOT` environment variable:

```powershell
# Windows PowerShell (permanent)
[System.Environment]::SetEnvironmentVariable('EMSDK_ROOT', 'D:\dev\tools\emsdk', 'User')

# Windows PowerShell (current session only)
$env:EMSDK_ROOT = "D:\dev\tools\emsdk"
```

```bash
# Linux/macOS (add to ~/.bashrc or ~/.zshrc)
export EMSDK_ROOT="/opt/emsdk"
```

The build script automatically detects emsdk in these locations (in order):
1. `C:\tools\emsdk` (Windows)
2. `/usr/local/emsdk` (Linux)
3. `~/emsdk` (user home)
4. `$EMSDK_ROOT` (environment variable)

### Automated Update (Recommended)

Use the build script to rebuild all grammars from latest sources:

```bash
# 1. Activate emsdk (Windows)
powershell.exe -ExecutionPolicy Bypass -File C:\tools\emsdk\emsdk_env.ps1

# 2. Run build script (rebuilds all grammars)
bash loraxMod/build/build-grammar.sh
```

The script will:
1. Clone or update grammar repositories to `build/temp/`
2. Generate parser C code using tree-sitter CLI
3. Compile to WASM using emscripten
4. Copy WASM files to `grammars/`

### Manual Update for Single Grammar

```bash
# Example: Update JavaScript grammar

# 1. Clone latest grammar
cd loraxMod/build/temp
git clone https://github.com/tree-sitter/tree-sitter-javascript
cd tree-sitter-javascript

# 2. Generate parser
tree-sitter generate

# 3. Compile to WASM
emcc src/parser.c src/scanner.c -o tree-sitter-javascript.wasm \
  -I./src -Os -fPIC -s WASM=1 -s SIDE_MODULE=2 \
  -s EXPORTED_FUNCTIONS="['_tree_sitter_javascript']"

# 4. Copy to grammars directory
cp tree-sitter-javascript.wasm ../../grammars/

# 5. Test
cd ../../../
node -e "const lorax = require('./lib/index.js'); console.log(lorax.getSupportedLanguages());"
```

## Version Pinning (Optional)

For production stability, you may want to pin specific grammar versions:

### Create Version Lock File
```bash
# Record current grammar commit hashes
cd loraxMod/build/temp

echo "# Grammar Version Lock" > grammar-versions.lock
echo "# Created: $(date)" >> grammar-versions.lock

for dir in tree-sitter-*; do
  if [ -d "$dir/.git" ]; then
    cd "$dir"
    hash=$(git rev-parse HEAD)
    echo "$dir: $hash" >> ../grammar-versions.lock
    cd ..
  fi
done
```

### Restore Specific Versions
```bash
# Checkout specific versions from lock file
while IFS=': ' read -r dir hash; do
  if [ -d "$dir" ]; then
    cd "$dir"
    git checkout "$hash"
    cd ..
  fi
done < grammar-versions.lock

# Then rebuild
bash ../build-grammar.sh
```

## Troubleshooting Updates

### "Parser version mismatch" Error
- Grammar compiled with different tree-sitter CLI version
- Solution: Ensure tree-sitter CLI matches grammar expectations
- Check: `tree-sitter --version` (should be 0.25.9+)

### WASM File Size Dramatically Changed
- May indicate breaking changes in grammar
- Compare old vs new WASM: `diff -u <(xxd old.wasm) <(xxd new.wasm) | head -50`
- Test thoroughly before deploying

### Grammar Breaks Existing Parsing
- Grammar may have changed node types or structure
- Check changelog in grammar repository
- May need to update extractor in `lib/extractors/<language>.js`

### Compilation Fails
- Check emsdk version: `emcc --version`
- Verify grammar has no build errors: `tree-sitter test` in grammar repo
- Check scanner.c vs scanner.cc (some use C++, adjust emcc command)

## Best Practices

1. **Test Before Deploying:** Always test updated grammars with existing code
2. **Update One at a Time:** Update and test grammars individually
3. **Document Changes:** Note any breaking changes in commit messages
4. **Keep emsdk Updated:** Periodically update emsdk for security patches
5. **Monitor Upstream:** Watch grammar repositories for major updates

## Update Checklist

When updating grammars:

- [ ] Check grammar repository for breaking changes
- [ ] Activate emsdk environment
- [ ] Run build script or manual compilation
- [ ] Verify WASM file generated successfully
- [ ] Test parsing with sample files
- [ ] Run vibe_tools test suite
- [ ] Update this document with new version info
- [ ] Commit changes with clear version notes
- [ ] Tag release if publishing to npm

## Links

- [tree-sitter Documentation](https://tree-sitter.github.io/tree-sitter/)
- [web-tree-sitter NPM](https://www.npmjs.com/package/web-tree-sitter)
- [Emscripten Documentation](https://emscripten.org/)
- [tree-sitter CLI](https://github.com/tree-sitter/tree-sitter/tree/master/cli)
