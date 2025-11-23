# LoraxMod v0.3.0

Tree-sitter AST parsing via PowerShell. Focused API: streaming parser (40x+ speedup) + interactive REPL + high-level analysis.

**8 functions, 12 languages, 2 modes: streaming for speed, REPL for exploration.**

## Installation

```powershell
Import-Module C:\path\to\LoraxMod
```

Requirements: Node.js (bundled loraxmod library included)

## Quick Start

### REPL Mode (Exploration)

Interactive AST navigation via Node.js REPL.

```powershell
Start-TreeSitterSession -Language c -Code "int add(int a, int b) { return a + b; }"
# Opens Node.js REPL with tree loaded
# Variables: parser, tree, root
```

### Streaming Mode (Batch Processing)

Long-running parser process for high-performance file processing.

```powershell
# Start session
Start-LoraxStreamParser

# Parse files (pipeline-enabled)
Get-ChildItem *.c -Recurse | Invoke-LoraxStreamQuery -Command parse

# Stop session
Stop-LoraxStreamParser
```

## Performance Comparison

| Mode | Use Case | Speed | Best For |
|------|----------|-------|----------|
| REPL | Interactive exploration | Standard | Learning, debugging, ad-hoc queries |
| Streaming | Batch processing | 40x+ faster | Processing 100+ files, CI/CD pipelines |

**Benchmark:** 1000 C files
- Per-file spawn: 125 seconds
- Streaming: 3 seconds (40x speedup)

**Reason:** Streaming eliminates per-file process spawn overhead. Grammar loaded once, reused for all files.

## Use Case Guidance

**Use REPL when:**
- Exploring AST structure interactively
- Learning tree-sitter query syntax
- Debugging specific parsing issues
- Need immediate visual feedback

**Use Streaming when:**
- Processing large file sets (100+ files)
- Building batch analysis tools
- Integrating into CI/CD pipelines
- Performance is critical

## Function Reference

### Streaming Functions (v0.2.0+)

**Start-LoraxStreamParser** - Initialize long-running parser process
- Parameters: SessionId, ParserScript, TimeoutSeconds
- Returns: SessionId

**Invoke-LoraxStreamQuery** - Send parse/query commands
- Parameters: SessionId, Command, File, Query, Context, TimeoutSeconds
- Commands: parse, query, ping
- Pipeline-enabled (accepts file objects)
- Returns: Response object with results

**Stop-LoraxStreamParser** - Graceful shutdown
- Parameters: SessionId, TimeoutSeconds
- Returns: Statistics (FilesProcessed, Errors, DurationSeconds)

### Interactive REPL (v0.1.0)

**Start-TreeSitterSession** - Interactive Node.js REPL
- Parameters: Language, Code, FilePath
- Globals: parser, tree, root, code
- Manual navigation: root.child(0), root.childForFieldName('name')
- Type .exit to quit

### High-Level Analysis (v0.1.0)

**Find-FunctionCalls** - Find function call sites with context
- Parameters: Language, Code, FilePath, FunctionNames (filter)
- Returns: function, line, parentFunction, arguments, codeLine

**Get-IncludeDependencies** - Extract C/C++ include directives
- Parameters: FilePath, Code
- Returns: system, local, posix (categorized headers)

## Examples

### Streaming - Basic Usage

```powershell
Start-LoraxStreamParser
$result = Invoke-LoraxStreamQuery -File sample.c -Command parse
Stop-LoraxStreamParser

# Output: segments (functions, classes, etc.)
$result.result.segments | Format-Table name, type, lineCount
```

### Streaming - Bulk Processing

```powershell
Start-LoraxStreamParser -SessionId batch

$results = Get-ChildItem C:\src -Recurse -Filter *.c |
           Invoke-LoraxStreamQuery -SessionId batch -Command parse

$stats = Stop-LoraxStreamParser -SessionId batch

Write-Host "Processed $($stats.FilesProcessed) files in $($stats.DurationSeconds)s"
```

### Streaming - Custom Query

```powershell
Start-LoraxStreamParser

$query = '(function_definition name: (identifier) @func)'
$result = Invoke-LoraxStreamQuery -File app.c -Command query -Query $query

$result.result.queryResults | ForEach-Object { $_.text }

Stop-LoraxStreamParser
```

### Streaming - Parallel Sessions

```powershell
# Process different file types concurrently
Start-LoraxStreamParser -SessionId c_files
Start-LoraxStreamParser -SessionId py_files

$c_results = Get-ChildItem *.c | Invoke-LoraxStreamQuery -SessionId c_files
$py_results = Get-ChildItem *.py | Invoke-LoraxStreamQuery -SessionId py_files

Stop-LoraxStreamParser -SessionId c_files
Stop-LoraxStreamParser -SessionId py_files
```

### REPL - Interactive Exploration

```powershell
Start-TreeSitterSession -Language c -FilePath sample.c
# Opens REPL - type commands:
# > root.childCount
# > root.children[0].type
# > Ctrl+D to exit
```

## Supported Languages

C, C++, C#, Python, JavaScript, TypeScript, Bash, PowerShell, R, Rust, CSS, Fortran

Language detected automatically from file extension.

## Protocol Documentation

Streaming parser implements JSON stdin/stdout protocol.

See: docs/STREAMING_PROTOCOL.md

Custom parser implementations can integrate with LoraxMod streaming functions by implementing protocol.

## Architecture

**Streaming:**
- Long-running Node.js process
- JSON commands via stdin
- JSON responses via stdout
- Session-based (multiple concurrent sessions supported)
- Protocol: ping, parse, query, shutdown

**REPL:**
- Interactive Node.js REPL sessions
- Direct AST manipulation
- Global variables: parser, tree, root
- Exploratory workflow

**Both modes use loraxmod library** (bundled in module directory)

## Version History

### v0.3.0 - API Consolidation (Current)

Breaking: Removed low-level AST functions (Invoke-TreeSitterQuery, Get-ASTNode, Show-ASTTree, Export-ASTJson, Get-NodesByType)
Focused API: 8 functions - streaming (3), REPL (1), analysis (2), deprecated (1)
Documentation: New REPL_GUIDE.md, enhanced MCP resources
Migration: Use REPL for exploration, streaming for batch processing

### v0.2.0 - Streaming Parser Integration

New: Start-LoraxStreamParser, Invoke-LoraxStreamQuery, Stop-LoraxStreamParser
Performance: 40x+ speedup for batch processing
Architecture: Streaming protocol with multiple session support
Backward compatible: All v0.1.0 REPL functions unchanged

### v0.1.0 - Initial Release

Features: Interactive REPL, query execution, function analysis, AST navigation
Languages: 12 languages supported
Requirements: Node.js, bundled loraxmod library

## See Also

- Get-Help Start-LoraxStreamParser -Full
- Get-Help Start-TreeSitterSession -Full
- Get-Help Find-FunctionCalls -Examples
- docs/STREAMING_PROTOCOL.md
- docs/REPL_GUIDE.md (coming soon)
- MCP resource: pwsh_mcp_modules://streaming-parser
- loraxmod library (bundled)
