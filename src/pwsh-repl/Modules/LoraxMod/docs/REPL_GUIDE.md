# LoraxMod REPL Guide

Interactive tree-sitter exploration via Node.js REPL

## What is the REPL?

REPL (Read-Eval-Print Loop) mode provides interactive JavaScript console for exploring tree-sitter AST nodes manually. Unlike streaming mode (automated batch processing), REPL lets you navigate, inspect, and query AST structure interactively.

## When to Use REPL

**Use REPL for:**
- Learning tree-sitter AST structure for a language
- Exploring unfamiliar code interactively
- Prototyping tree-sitter queries
- Debugging parsing issues
- Understanding node types, fields, relationships

**Use Streaming for:**
- Processing 100+ files
- Automating analysis in scripts/CI
- Performance-critical workflows
- Production analysis tools

## Starting a REPL Session

```powershell
# From code string
Start-TreeSitterSession -Language c -Code 'int main() { return 0; }'

# From file
Start-TreeSitterSession -Language python -FilePath script.py

# Supported languages
# c, cpp, csharp, python, javascript, typescript, bash, powershell, r, rust, css, fortran
```

**What happens:**
1. PowerShell spawns Node.js process
2. loraxmod initializes parser with specified language
3. Code is parsed into AST
4. Interactive REPL opens with global variables ready

## Available Globals

When REPL starts, these are available immediately:

| Global | Type | Purpose |
|--------|------|---------|
| `lorax` | object | loraxmod API (parseCode, detectLanguage, etc.) |
| `parser` | object | Parser instance |
| `tree` | object | Parsed tree |
| `root` | node | Root AST node (start here!) |
| `code` | string | Original source code |

## Basic Navigation

### Inspecting Nodes

```javascript
// Node type
root.type
// 'translation_unit' (C/C++)

// Children count
root.childCount
// 3

// Get child by index
root.child(0)

// Named children only (skip punctuation)
root.namedChildCount
root.namedChild(0)

// Node text
root.text
// Full source text for this node

// Node position
root.startPosition
// { row: 0, column: 0 }

root.endPosition
// { row: 10, column: 5 }
```

### Navigating Tree

```javascript
// Parent node
root.parent
// null (root has no parent)

// Navigate down
const func = root.child(0)
func.type
// 'function_definition'

const body = func.childForFieldName('body')
body.type
// 'compound_statement'
```

### Field Access

Tree-sitter grammars define field names for structured access:

```javascript
// C function: function_definition has fields
const func = root.child(0)

// Get by field name
func.childForFieldName('declarator')
// Function declarator node

func.childForFieldName('body')
// Function body node

// List all children with fields
for (let i = 0; i < func.childCount; i++) {
  const child = func.child(i)
  if (child.fieldName) {
    console.log(`Field '${child.fieldName}': ${child.type}`)
  }
}
```

## Common Patterns

### Finding Functions

**C/C++:**

```javascript
// Traverse and collect function definitions
const functions = []

function traverse(node) {
  if (node.type === 'function_definition') {
    const declarator = node.childForFieldName('declarator')
    const identifier = declarator.childForFieldName('declarator')
    if (identifier) {
      functions.push({
        name: identifier.text,
        line: node.startPosition.row + 1
      })
    }
  }

  for (let i = 0; i < node.childCount; i++) {
    traverse(node.child(i))
  }
}

traverse(root)
console.log(JSON.stringify(functions, null, 2))
```

**Python:**

```javascript
const functions = []

function traverse(node) {
  if (node.type === 'function_definition') {
    const name = node.childForFieldName('name')
    if (name) {
      functions.push({
        name: name.text,
        line: node.startPosition.row + 1
      })
    }
  }

  for (let i = 0; i < node.childCount; i++) {
    traverse(node.child(i))
  }
}

traverse(root)
```

### Finding Function Calls

```javascript
const calls = []

function traverse(node) {
  if (node.type === 'call_expression' || node.type === 'call') {
    const func = node.childForFieldName('function')
    if (func) {
      calls.push({
        function: func.text,
        line: node.startPosition.row + 1
      })
    }
  }

  for (let i = 0; i < node.childCount; i++) {
    traverse(node.child(i))
  }
}

traverse(root)
```

### Printing Tree Structure

```javascript
function printTree(node, indent = 0) {
  const prefix = '  '.repeat(indent)
  console.log(`${prefix}[${node.type}] ${node.text.substring(0, 50)}`)

  for (let i = 0; i < node.childCount && indent < 5; i++) {
    printTree(node.child(i), indent + 1)
  }
}

printTree(root)
```

## Tree-Sitter Queries (S-expressions)

REPL supports tree-sitter query language for pattern matching.

### Basic Query Syntax

```javascript
// Query pattern (S-expression syntax)
const queryPattern = '(function_definition name: (identifier) @func)'

// Execute query
const query = parser.getLanguage().query(queryPattern)
const matches = query.matches(root)

// Process captures
matches.forEach(match => {
  match.captures.forEach(capture => {
    console.log(`${capture.name}: ${capture.node.text}`)
  })
})
```

### Query Examples

**Find all function names:**

```javascript
const query = parser.getLanguage().query(`
  (function_definition
    name: (identifier) @func)
`)

query.matches(root).forEach(m => {
  m.captures.forEach(c => console.log(c.node.text))
})
```

**Find printf calls:**

```javascript
const query = parser.getLanguage().query(`
  (call_expression
    function: (identifier) @func (#eq? @func "printf"))
`)

query.matches(root).forEach(m => {
  console.log(m.captures[0].node.startPosition.row + 1)
})
```

**Find includes:**

```javascript
const query = parser.getLanguage().query(`
  (preproc_include
    path: (system_lib_string) @header)
`)

query.matches(root).forEach(m => {
  console.log(m.captures[0].node.text)
})
```

## Language-Specific Tips

### C/C++

Node types:
- `translation_unit` - Root
- `function_definition` - Function
- `declaration` - Variable declarations
- `call_expression` - Function calls
- `preproc_include` - #include directives

Important fields:
- `function_definition`: declarator, body
- `call_expression`: function, arguments
- `preproc_include`: path

### Python

Node types:
- `module` - Root
- `function_definition` - Function
- `class_definition` - Class
- `call` - Function calls
- `import_statement` - Import

Important fields:
- `function_definition`: name, parameters, body
- `class_definition`: name, superclasses, body
- `call`: function, arguments

### JavaScript

Node types:
- `program` - Root
- `function_declaration` - Function
- `arrow_function` - Arrow function
- `call_expression` - Function calls
- `class_declaration` - Class

Important fields:
- `function_declaration`: name, parameters, body
- `arrow_function`: parameters, body
- `call_expression`: function, arguments

## Exiting REPL

```javascript
// Type in REPL:
.exit

// Or Ctrl+D (Unix/Mac) / Ctrl+Z (Windows)
```

## Comparison: REPL vs Streaming

| Feature | REPL | Streaming |
|---------|------|-----------|
| **Use Case** | Exploration | Automation |
| **Speed** | Interactive | 40x faster (batch) |
| **Files** | One at a time | 100+ files |
| **Interface** | Manual navigation | Pipeline/scripts |
| **Output** | Console | Structured JSON |
| **Learning Curve** | Higher | Lower |
| **Best For** | Understanding | Production |

**Workflow:**

1. Use REPL to understand AST structure for target language
2. Prototype query patterns interactively
3. Switch to streaming for production analysis

## Advanced: Leveraging loraxmod API

The `lorax` global exposes full loraxmod API:

```javascript
// Parse different code in same session
const newCode = "void test() { return; }"
const newTree = parser.parse(newCode)
newTree.rootNode.type

// Detect language from file extension
lorax.detectLanguage('script.py')
// 'python'

// Get supported languages
lorax.getSupportedLanguages()
```

## Troubleshooting

**REPL doesn't start:**
- Check Node.js installed: `node --version`
- Verify loraxmod path: Check module installation

**Parser errors:**
- Check language support: Must be in ValidateSet
- Verify code syntax: Parser may fail on syntax errors

**Navigation confusion:**
- Start simple: Explore root.type, root.childCount
- Print tree: Use printTree helper function
- Check grammar: Different languages use different node types

## Examples

### Example 1: Count Functions in C File

```powershell
Start-TreeSitterSession -Language c -FilePath mycode.c

# In REPL:
let count = 0
function traverse(node) {
  if (node.type === 'function_definition') count++
  for (let i = 0; i < node.childCount; i++) {
    traverse(node.child(i))
  }
}
traverse(root)
console.log(`Functions: ${count}`)
```

### Example 2: Find All Variable Declarations

```javascript
const vars = []

function traverse(node) {
  if (node.type === 'declaration') {
    const declarators = node.childForFieldName('declarator')
    if (declarators && declarators.type === 'init_declarator') {
      const name = declarators.childForFieldName('declarator')
      if (name) {
        vars.push(name.text)
      }
    }
  }

  for (let i = 0; i < node.childCount; i++) {
    traverse(node.child(i))
  }
}

traverse(root)
console.log(JSON.stringify(vars, null, 2))
```

### Example 3: Extract Function Signatures

```javascript
const signatures = []

function traverse(node) {
  if (node.type === 'function_definition') {
    signatures.push({
      signature: node.text.split('{')[0].trim(),
      line: node.startPosition.row + 1
    })
  }

  for (let i = 0; i < node.childCount; i++) {
    traverse(node.child(i))
  }
}

traverse(root)
```

## See Also

- [README.md](../README.md) - Module overview
- [STREAMING_PROTOCOL.md](STREAMING_PROTOCOL.md) - Streaming parser protocol
- [StreamingParser.Tests.ps1](../tests/StreamingParser.Tests.ps1) - Streaming examples
- [REPL.Tests.ps1](../tests/REPL.Tests.ps1) - Analysis function examples
- Get-Help Start-TreeSitterSession -Full
- Get-Help Find-FunctionCalls -Examples
- Tree-sitter docs: https://tree-sitter.github.io/tree-sitter/using-parsers
