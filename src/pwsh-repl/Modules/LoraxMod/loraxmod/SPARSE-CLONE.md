# Sparse Clone Guide for loraxMod

Git sparse checkout allows you to clone only the parts of loraxMod you need, reducing disk usage and clone time.

## Use Cases

### Grammar Files Only (PowerShell/External Callers)
If you're calling tree-sitter from PowerShell or another language and only need the WASM files:

**Disk usage:** ~9 MB (vs ~50+ MB for full clone)

```bash
git clone --no-checkout https://github.com/yourusername/loraxMod.git
cd loraxMod
git sparse-checkout init --cone
git sparse-checkout set grammars
git checkout main
```

Your directory will contain:
```
loraxMod/
├── grammars/
│   ├── tree-sitter-javascript.wasm
│   ├── tree-sitter-python.wasm
│   ├── tree-sitter-bash.wasm
│   ├── tree-sitter-powershell.wasm
│   ├── tree-sitter-r.wasm
│   └── tree-sitter-c-sharp.wasm
├── package.json
└── README.md
```

### Runtime Library (Node.js Projects)
If you're using loraxMod from Node.js but don't need build tools:

**Disk usage:** ~12 MB

```bash
git clone --no-checkout https://github.com/yourusername/loraxMod.git
cd loraxMod
git sparse-checkout init --cone
git sparse-checkout set grammars lib
git checkout main
npm install
```

Your directory will contain:
```
loraxMod/
├── grammars/           # WASM files
├── lib/                # Runtime library
├── node_modules/       # Dependencies (after npm install)
├── package.json
└── README.md
```

### Full Clone (Contributors/Grammar Builders)
If you need to rebuild grammars or contribute to loraxMod:

```bash
git clone https://github.com/yourusername/loraxMod.git
cd loraxMod
npm install
```

Or convert existing sparse checkout to full:
```bash
cd loraxMod
git sparse-checkout disable
git checkout main
```

## Switching Between Patterns

### Expand sparse checkout to include more files
```bash
# Currently have grammars only, add lib/
git sparse-checkout set grammars lib
```

### Reduce sparse checkout
```bash
# Currently have grammars and lib, keep only grammars
git sparse-checkout set grammars
```

### Check current sparse checkout pattern
```bash
git sparse-checkout list
```

### Disable sparse checkout (convert to full clone)
```bash
git sparse-checkout disable
git checkout main
```

## Sparse Checkout in Submodules

If using loraxMod as a submodule with sparse checkout:

```bash
# Add submodule with sparse checkout
git submodule add https://github.com/yourusername/loraxMod.git lib/loraxMod
cd lib/loraxMod
git sparse-checkout init --cone
git sparse-checkout set grammars lib
git checkout main
cd ../..

# Configure submodule to persist sparse checkout
git config -f .gitmodules submodule.lib/loraxMod.sparseCheckout true
```

In `.git/modules/lib/loraxMod/info/sparse-checkout`:
```
grammars
lib
```

## PowerShell Example

Using loraxMod grammars from PowerShell:

```powershell
# Clone grammars only
git clone --no-checkout https://github.com/yourusername/loraxMod.git
cd loraxMod
git sparse-checkout init --cone
git sparse-checkout set grammars
git checkout main

# Now call tree-sitter from PowerShell
$grammarPath = Join-Path $PWD "grammars/tree-sitter-javascript.wasm"
node your-parser.js --grammar $grammarPath
```

## Benefits

1. **Reduced disk usage**: 9 MB (sparse) vs 50+ MB (full)
2. **Faster clones**: Download only what you need
3. **Cleaner working directory**: No build tools if you don't build
4. **Bandwidth savings**: Important for CI/CD pipelines
5. **Security**: Don't clone build tools if you only run

## Caveats

1. **Changing patterns**: Requires re-checkout after changing sparse-checkout
2. **Git operations**: Some git commands may be slower
3. **Hidden files**: Files outside sparse pattern are invisible but still in .git/
4. **Submodule updates**: May need to reconfigure sparse checkout after updates

## Troubleshooting

### "fatal: sparse-checkout leaves no entry on working directory"
You tried to set a pattern that excludes everything. Reset:
```bash
git sparse-checkout disable
git sparse-checkout init --cone
git sparse-checkout set grammars
```

### Files still showing from previous pattern
Re-checkout after changing pattern:
```bash
git sparse-checkout set grammars
git read-tree -mu HEAD
```

### Submodule sparse checkout not persisting
Configure in .gitmodules:
```bash
git config -f .gitmodules submodule.lib/loraxMod.sparseCheckout true
```

Then manually create `.git/modules/lib/loraxMod/info/sparse-checkout` with your pattern.
