# loraxMod - Tree-Sitter Parsing Infrastructure

Standalone tree-sitter parsing library extracted from vibe_tools. Provides unified multi-language code parsing with AST analysis for 10 languages: JavaScript, Python, PowerShell, Bash, R, C#, Rust, C, CSS, and Fortran.

## Purpose

loraxMod eliminates duplication of tree-sitter infrastructure across projects by providing:

- Single source for grammar WASM files (10 languages)
- Unified parser initialization and language loading
- Modular language-specific extractors
- Ancestor-aware AST traversal utilities
- Extraction context filtering

## Supported Languages

All languages use tree-sitter WASM grammars - no native compilation required.

- **JavaScript/TypeScript** (.js, .jsx, .ts, .tsx, .mjs, .cjs)
- **Python** (.py)
- **PowerShell** (.ps1, .psm1, .psd1)
- **Bash** (.sh, .bash)
- **R** (.r, .R)
- **C#** (.cs, .csx)
- **Rust** (.rs)
- **C** (.c, .h)
- **CSS** (.css, .scss, .sass, .less)
- **Fortran** (.f, .f90, .f95, .f03, .f08, .for)

## Installation

### Method 1: Direct Path (Development)
```bash
# Place loraxMod adjacent to your project
cd ../loraxMod
npm install  # Installs only web-tree-sitter (~5.7 MB)

# Your project automatically finds it via relative path
```

### Method 2: npm link (Recommended)
```bash
cd loraxMod
npm install  # Single dependency: web-tree-sitter
npm link

cd ../your-project
npm link loraxmod
```

### Method 3: Git Submodule
```bash
cd your-project
git submodule add https://github.com/yourusername/loraxMod.git lib/loraxMod
git submodule update --init --recursive
```

### Method 4: Sparse Clone (Grammar Only - for PowerShell callers)
```bash
git clone --no-checkout https://github.com/yourusername/loraxMod.git
cd loraxMod
git sparse-checkout init --cone
git sparse-checkout set grammars
git checkout main
```

## Usage

### Basic Parsing

```javascript
const { parseCode } = require('loraxmod');

const code = `
class MyClass {
  myMethod() {
    console.log("Hello");
  }
}
`;

const segments = await parseCode(code, 'example.js');
console.log(segments);
// [
//   { type: 'class', name: 'MyClass', startLine: 1, endLine: 5, ... },
//   { type: 'method', name: 'MyClass.myMethod', startLine: 2, endLine: 4, ... }
// ]
```

### With Extraction Context

```javascript
const { parseCode } = require('loraxmod');

const extractionContext = {
  Elements: ['class', 'method'],  // Only extract classes and methods
  Exclusions: ['constant'],        // Exclude constants
  PreserveContext: true,           // Preserve parent class in method names
  Filters: {
    ClassName: 'MyClass'           // Only extract MyClass
  }
};

const segments = await parseCode(code, 'example.js', extractionContext);
```

### Low-Level API

```javascript
const {
  initParser,
  loadLanguage,
  getParser,
  detectLanguage,
  getExtractorClass
} = require('loraxmod');

// Initialize parser
await initParser();

// Load language
const language = detectLanguage('example.py');
const langObj = await loadLanguage(language);

// Parse with tree-sitter directly
const parser = getParser();
parser.setLanguage(langObj);
const tree = parser.parse(code);

// Use extractor
const ExtractorClass = getExtractorClass(language);
const extractor = new ExtractorClass();
const segments = extractor.extract(tree, extractionContext);
```

### AST Traversal Utilities

```javascript
const { traverseWithAncestors, findAncestor, getParentClassName } = require('loraxmod');

traverseWithAncestors(rootNode, [], (node, ancestors) => {
  // Process node with full ancestor context
  const parentClass = findAncestor(ancestors, 'class_declaration');
  const className = getParentClassName(ancestors, 'javascript');
});
```

## API Reference

### High-Level API

#### `parseCode(code, filePath, extractionContext?, languageConfig?)`
Parse code and extract structured segments.

**Parameters:**
- `code` (string): Source code to parse
- `filePath` (string): File path for language detection
- `extractionContext` (Object, optional): Filtering context
  - `Elements` (Array): Types to include (class, function, method, etc.)
  - `Exclusions` (Array): Types to exclude
  - `PreserveContext` (boolean): Preserve parent class in method names
  - `ScopeFilter` (string): 'top-level' to exclude nested items
  - `Filters` (Object): Name-based filters
    - `ClassName` (string): Filter by class name
    - `FunctionName` (string): Filter by function/method name
    - `Extends` (string): Filter by parent class
- `languageConfig` (Object, optional): Configuration
  - `grammarDir` (string): Custom grammar directory path

**Returns:** `Promise<Array>` - Array of segments with:
- `type`: Segment type (class, function, method, constant, etc.)
- `name`: Segment name
- `startLine`: Start line number (0-indexed)
- `endLine`: End line number (0-indexed)
- `content`: Full segment code
- `parent`: Parent class name (for methods)
- `extends`: Superclass name (for classes)
- `lineCount`: Number of lines

### Core Functions

#### `initParser()`
Initialize tree-sitter parser. Call once before parsing.

**Returns:** `Promise<TreeSitter.Parser>`

#### `loadLanguage(language, grammarDir?)`
Load language grammar WASM file.

**Parameters:**
- `language` (string): Language identifier
- `grammarDir` (string, optional): Custom grammar directory

**Returns:** `Promise<TreeSitter.Language|null>`

#### `detectLanguage(filePath)`
Detect language from file extension.

**Returns:** `string` - Language identifier or 'unknown'

#### `getSupportedLanguages()`
Get list of supported languages.

**Returns:** `Array<string>`

### Traversal Utilities

#### `traverseWithAncestors(node, ancestors, visitor)`
Traverse AST with ancestor tracking.

**Parameters:**
- `node` (TreeSitter.SyntaxNode): Current node
- `ancestors` (Array): Ancestor nodes
- `visitor` (Function): Callback `(node, ancestors) => {}`

#### `findAncestor(ancestors, types)`
Find first ancestor of specific type(s).

**Parameters:**
- `ancestors` (Array): Ancestor nodes
- `types` (string|Array): Node type(s) to find

**Returns:** `TreeSitter.SyntaxNode|null`

#### `isTopLevel(ancestors, language)`
Check if node is at module/file top level.

**Returns:** `boolean`

#### `getParentClassName(ancestors, language)`
Get parent class name from ancestors.

**Returns:** `string|null`

## Architecture

### Directory Structure
```
loraxMod/
├── grammars/               # WASM grammar files
├── lib/
│   ├── core/              # Parser, language detection, traversal
│   ├── extractors/        # Language-specific extractors
│   ├── filters/           # Extraction context filtering
│   └── index.js           # Main export
├── build/                 # Build scripts for grammars
└── emsdk/                # Emscripten SDK (excluded from npm)
```

### Design Principles

1. **Single Responsibility**: Core parsing only, no Git or reporting logic
2. **Composition**: Modular extractors registered via plugin pattern
3. **Backward Compatible**: Drop-in replacement for existing parsers
4. **Sparse Clone Friendly**: Minimal dependencies for grammar-only usage
5. **Zero Native Dependencies**: Pure WASM - no compilation, cross-platform

## Building Grammars

Pre-compiled WASM grammars are included. Only rebuild if you need to update or customize grammars.

### Prerequisites
- tree-sitter CLI: `npm install -g tree-sitter-cli@0.25.9`
- Emscripten SDK: Install to `C:\tools\emsdk` (Windows) or `/usr/local/emsdk` (Linux)

**Install emsdk (one-time setup):**
```bash
# Windows
cd C:\tools
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
emsdk install latest
emsdk activate latest

# Linux/macOS
cd /usr/local  # or ~/
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
```

**Custom emsdk location:** Set `EMSDK_ROOT` environment variable to your emsdk path.
Build script auto-detects: `C:\tools\emsdk`, `/usr/local/emsdk`, `~/emsdk`, or `$EMSDK_ROOT`.

### Build Grammars

**Windows:**
```bash
# Activate emsdk
powershell.exe -ExecutionPolicy Bypass -File C:\tools\emsdk\emsdk_env.ps1

# Build all grammars
bash build/build-grammar.sh
```

**Linux/macOS:**
```bash
# Activate emsdk
source /usr/local/emsdk/emsdk_env.sh

# Build all grammars
bash build/build-grammar.sh
```

### Updating Grammars

See [GRAMMAR-VERSIONS.md](GRAMMAR-VERSIONS.md) for:
- Current grammar versions and sources
- Update procedures and version pinning
- Troubleshooting compilation issues
- Testing and validation steps

## Sparse Clone Patterns

For projects that only need grammars (e.g., PowerShell callers):

```bash
# Clone with sparse checkout
git clone --no-checkout https://github.com/yourusername/loraxMod.git
cd loraxMod
git sparse-checkout init --cone

# Pattern 1: Grammars only (minimal)
git sparse-checkout set grammars
git checkout main

# Pattern 2: Grammars + runtime lib
git sparse-checkout set grammars lib
git checkout main

# Pattern 3: Everything (full clone)
git sparse-checkout disable
git checkout main
```

## Migration from vibe_tools

If migrating from vibe_tools code_evolver or code_referencer:

1. Install loraxMod adjacent to vibe_tools: `../loraxMod`
2. Run `npm install` in loraxMod
3. Your tools will automatically find loraxMod via relative path
4. Original wrapper parsers now delegate to loraxMod

## Contributing

### Adding New Languages

1. Add grammar WASM file to `grammars/`
2. Update `lib/core/language-map.js` with file extension mapping
3. Create extractor in `lib/extractors/<language>.js`
4. Register extractor in `lib/index.js`
5. Update build script in `build/build-grammar.sh`

## License

ISC

## Credits

Extracted from vibe_tools project (code_evolver and code_referencer).
Built with web-tree-sitter WASM for cross-platform compatibility.
