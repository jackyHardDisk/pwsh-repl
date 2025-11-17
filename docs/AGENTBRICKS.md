# AgentBricks Module Documentation

## Overview

AgentBricks is a self-teaching PowerShell module that provides concrete development tools, pre-configured patterns for common tools, and meta-learning capabilities for Claude agents. The module auto-loads when PowerShell MCP sessions are created.

**Design Philosophy: Hybrid v1+v2+v3 Approach**
- **v1 (Concrete):** Immediately useful functions like Format-Count, Find-Errors
- **v2 (Pre-configured):** 40+ patterns for JavaScript, Python, .NET, Build tools
- **v3 (Meta-learning):** Learn-OutputPattern for self-teaching new tools

**Token Efficiency:** Module functions are NOT included in MCP tool schemas. Agents discover them via `Get-Help` on-demand. This keeps upfront token cost at ~1400 tokens (3 MCP tools only).

## Module Structure

```
AgentBricks/
├── AgentBricks.psd1           # Module manifest (20 exported functions)
├── AgentBricks.psm1           # Main module (BrickStore initialization, auto-loads patterns)
├── Core/
│   ├── Transform.ps1          # Format-Count, Group-By, Measure-Frequency
│   ├── Extract.ps1            # Extract-Regex, Extract-Between, Extract-Column
│   ├── Analyze.ps1            # Find-Errors, Find-Warnings, Parse-BuildOutput
│   └── Present.ps1            # Show, Export-ToFile
├── Meta/
│   ├── Discovery.ps1          # Find-ProjectTools
│   └── Learning.ps1           # Set-Pattern, Get-Patterns, Test-Pattern, Learn-OutputPattern
├── State/
│   └── Management.ps1         # Save-Project, Load-Project, Get-BrickStore, Clear-Stored
└── Patterns/
    ├── JavaScript.ps1         # ESLint, Stylelint, TypeScript, Prettier, Vite, Webpack, Jest, Node.js (8)
    ├── Python.ps1             # Pytest, Mypy, Flake8, Black, Pylint, unittest, Coverage, tracebacks (10)
    ├── DotNet.ps1             # MSBuild, NuGet, NUnit, xUnit, MSTest, Roslyn, StyleCop (10)
    └── Build.ps1              # GCC, Clang, CMake, Make, Ninja, Maven, Gradle, Rust, Cargo, Go (13+)
```

## Function Categories

### Transform Functions (3)

**Format-Count** - Format frequency counts with aligned "Nx: item" format

```powershell
# Basic usage
"error", "error", "warning" | Measure-Frequency | Format-Count
# Output:
#    2x: error
#    1x: warning

# Custom width
Find-Errors build.log | Format-Count -Width 4
#  42x: Cannot find module 'foo'
```

**Group-By** - Group objects by property, return Count/Item format

```powershell
Get-ChildItem | Group-By Extension
#  42x: .txt
#  12x: .log

Import-Csv log.csv | Group-By Level | Format-Count
# 245x: ERROR
#  89x: WARN
```

**Measure-Frequency** - Count occurrences, sort by frequency (descending)

```powershell
Get-Content build.log | Select-String "error" | Measure-Frequency
#  42x: error: Cannot find module
#  12x: error: Undefined variable

# Ascending order
"a", "b", "a", "c", "a" | Measure-Frequency -Ascending
#   1x: b
#   1x: c
#   3x: a
```

### Extract Functions (3)

**Extract-Regex** - Extract named groups from regex pattern

```powershell
"app.js:42:15: error: undefined" | Extract-Regex -Pattern '(?<file>\S+):(?<line>\d+)'
# Returns PSCustomObject with file="app.js", line="42"

# Use stored pattern
$pattern = Get-Patterns -Name "ESLint"
$env:lint_stderr | Extract-Regex -Pattern $pattern.Pattern
```

**Extract-Between** - Extract text between delimiters

```powershell
"<error>File not found</error>" | Extract-Between -Start "<error>" -End "</error>"
# Output: File not found

Get-Content log.xml | Extract-Between -Start "<message>" -End "</message>"
```

**Extract-Column** - Extract column from delimited text

```powershell
"app.js:42:error:undefined" | Extract-Column -Delimiter ":" -Column 2
# Output: 42

Get-Content data.csv | Extract-Column -Delimiter "," -Column 0
# Extract first column from CSV
```

### Analyze Functions (3)

**Find-Errors** - Find lines matching error patterns

```powershell
Find-Errors build.log
# Returns lines containing: error, exception, failed, failure (case-insensitive)

Find-Errors build.log | Measure-Frequency | Format-Count
#  42x: error: Cannot find module
#  12x: exception: NullPointerException
```

**Find-Warnings** - Find lines matching warning patterns

```powershell
Find-Warnings build.log
# Returns lines containing: warning, warn (case-insensitive)

Find-Warnings npm-output.txt | Format-Count
#  15x: warning: Deprecated function
```

**Parse-BuildOutput** - Parse build tool output (MSBuild, GCC, Clang)

```powershell
Parse-BuildOutput build.log
# Returns structured objects with File, Line, Col, Severity, Code, Message

Parse-BuildOutput msbuild.log | Where-Object { $_.Code -like "CS*" }
# Filter C# compiler errors

Parse-BuildOutput gcc.log | Group-By Severity | Format-Count
#  42x: error
#  12x: warning
```

### Present Functions (2)

**Show** - Display results with optional filtering and formatting

```powershell
Find-Errors build.log | Show -Top 5
# Show top 5 errors

Get-Patterns | Show -Format Table
# Display as table

Measure-Frequency test.log | Show -Skip 3 -Top 10
# Skip first 3, show next 10
```

**Export-ToFile** - Export results to file (text, CSV, JSON)

```powershell
Find-Errors build.log | Export-ToFile -Path errors.txt
# Export as text

Get-Patterns | Export-ToFile -Path patterns.csv -Format Csv
# Export as CSV

Measure-Frequency | Export-ToFile -Path stats.json -Format Json
# Export as JSON
```

### Meta-Discovery (1)

**Find-ProjectTools** - Auto-detect available build/test/lint tools in project

```powershell
Find-ProjectTools

# Output:
# Type       Tool        Command                  Category
# ----       ----        -------                  --------
# JavaScript npm         npm run build            build
# JavaScript npm         npm run test             test
# JavaScript npm         npm run lint             lint
# Python     pytest      pytest tests/            test
# Python     mypy        mypy src/                lint
# .NET       dotnet      dotnet build             build
```

Detects tools from:
- package.json (npm scripts)
- pyproject.toml (Python tools)
- *.csproj (dotnet commands)
- Makefile, CMakeLists.txt (make/cmake)
- Cargo.toml (Rust)

### Meta-Learning (4)

**Set-Pattern** - Define regex pattern for tool output

```powershell
Set-Pattern -Name "ESLint" `
    -Pattern '(?<file>[\w/.-]+):(?<line>\d+):(?<col>\d+): (?<severity>error|warning): (?<message>.+)' `
    -Description "ESLint output format" `
    -Category "lint"
```

**Get-Patterns** - List registered patterns

```powershell
Get-Patterns
# Show all patterns

Get-Patterns -Category error
# Show only error patterns

Get-Patterns -Name "*eslint*"
# Wildcard search

$pattern = Get-Patterns -Name "Pytest-Fail"
# Get specific pattern for use
```

**Test-Pattern** - Validate pattern against sample input

```powershell
Test-Pattern -Name "ESLint" -Sample "app.js:42:15: error: undefined variable"

# Output:
# Pattern: ESLint
# Matched: YES
#
# Extracted fields:
#   file     : app.js
#   line     : 42
#   col      : 15
#   severity : error
#   message  : undefined variable
```

**Learn-OutputPattern** - Interactively learn new tool patterns

```powershell
# Interactive mode (prompts for pattern selection)
Learn-OutputPattern -Name "myapp-lint" -Command "myapp lint src/" -Interactive

# Auto mode (detects and registers best-guess pattern)
Learn-OutputPattern -Name "custom-test" -Command "npm test" -Category test
```

Auto-detects common patterns:
- GCC-style: `file:line:col: severity: message`
- MSBuild-style: `file(line,col): severity code: message`
- Test-style: `STATUS test - message`
- Generic: `severity: message`

### State Management (4)

**Save-Project** - Save BrickStore state to .brickyard.json

```powershell
Save-Project -Path ".brickyard.json"
# Saves patterns, results, chains for reuse
```

**Load-Project** - Load saved state from .brickyard.json

```powershell
Load-Project -Path ".brickyard.json"
# Restores patterns from previous session
```

**Get-BrickStore** - View current BrickStore contents

```powershell
Get-BrickStore
# Shows: Results count, Patterns count, Chains count

Get-BrickStore -Detailed
# Full dump of all stored data
```

**Clear-Stored** - Reset BrickStore state

```powershell
Clear-Stored
# Clears all patterns, results, chains

Clear-Stored -PatternOnly
# Keep results/chains, clear patterns only
```

## Pre-Configured Patterns (40+)

Patterns are loaded automatically on module import. Access via `Get-Patterns`.

### JavaScript/TypeScript (8)

- **ESLint**: `file:line:col: severity: message`
- **Stylelint**: CSS/SCSS linting errors
- **TypeScript**: `file(line,col): error TSxxxx: message`
- **Prettier**: Formatting issues
- **Vite**: Build errors
- **Webpack**: Bundle errors
- **Jest**: Test failures
- **Node.js**: Runtime errors and stack traces

### Python (10)

- **Pytest-Fail**: `FAILED test::path - reason`
- **Pytest-Error**: `ERROR test::path`
- **Mypy**: Type checking errors
- **Flake8**: Linting errors `file:line:col: code message`
- **Black**: Formatting issues
- **Pylint**: `file:line:col: code: message`
- **unittest**: Unit test failures
- **Coverage**: Coverage warnings
- **Traceback**: Python stack traces
- **ModuleNotFoundError**: Import errors

### .NET (10)

- **MSBuild**: `file(line,col): severity code: message`
- **MSBuild-Project**: Project-level errors
- **NuGet**: Package restore errors
- **NUnit**: Test failures
- **xUnit**: Test failures
- **MSTest**: Test failures
- **Roslyn**: Compiler diagnostics
- **Roslyn-Info**: Compiler suggestions
- **StyleCop**: Code style violations
- **AnalyzerFailure**: Analyzer crashes

### Build Tools (13+)

- **GCC**: `file:line:col: severity: message`
- **Clang**: Clang compiler errors
- **CMake**: Configuration errors
- **CMake-Missing**: Missing dependencies
- **Make**: Makefile errors
- **Ninja**: Ninja build errors
- **Maven**: Java build errors
- **Gradle**: Gradle task failures
- **Rust-Error**: Rust compiler errors
- **Rust-Warning**: Rust warnings
- **Cargo**: Cargo build output
- **Go-Build**: Go compiler errors
- **Go-Test**: Go test failures

## BrickStore Global State

AgentBricks maintains a global `$BrickStore` hashtable with session-persistent state:

```powershell
$global:BrickStore = @{
    Results = @{}    # Stored analysis results from dev-run
    Patterns = @{}   # Regex patterns (pre-configured + learned)
    Chains = @{}     # Saved pipelines (future enhancement)
}
```

**Session Scope:** Persists within PowerShell session, cleared on session removal

**Cross-Session:** Export via `Save-Project`, import via `Load-Project`

## Usage Workflows

### Workflow 1: Iterative Build Error Analysis

```powershell
# Run build with dev-run (captures output)
dev-run "dotnet build" -name "build"

# Output:
# Errors:   12  (5 unique)
# Top Errors:
#     8x: CS0103: The name 'foo' does not exist
#     3x: CS0246: Type or namespace not found

# Analyze errors in detail
$env:build_stderr | Extract-Regex -Pattern (Get-Patterns -Name "MSBuild").Pattern | Format-Count
#     8x: CS0103
#     3x: CS0246
#     1x: CS1002

# Filter specific error code
$env:build_stderr | Extract-Regex -Pattern (Get-Patterns -Name "MSBuild").Pattern |
    Where-Object { $_.Code -eq "CS0103" }
```

### Workflow 2: Project Discovery and Testing

```powershell
# Discover available tools
Find-ProjectTools

# Identify test command
# Output: JavaScript | npm | npm run test | test

# Run tests with capture
dev-run "npm run test" -name "test"

# Analyze test failures
$env:test_stderr | Extract-Regex -Pattern (Get-Patterns -Name "Jest").Pattern
```

### Workflow 3: Learning Custom Tool

```powershell
# Learn new tool pattern interactively
Learn-OutputPattern -Name "myapp-lint" -Command "myapp lint src/" -Interactive

# Agent sees:
# Detected patterns:
#   1. GCC-style: file:line:col: severity: message
#   2. Generic: severity: message
# Select pattern (1-2) or 'c' for custom: 1

# Pattern registered and ready for use
$env:lint_output | Extract-Regex -Pattern (Get-Patterns -Name "myapp-lint").Pattern

# Save for future sessions
Save-Project -Path ".brickyard.json"
```

### Workflow 4: Cross-Project Pattern Reuse

```powershell
# Project A: Learn patterns
Learn-OutputPattern -Name "company-tool" -Command "tool validate" -Category lint
Save-Project -Path "company-patterns.json"

# Project B: Reuse patterns
Load-Project -Path "C:\shared\company-patterns.json"
Get-Patterns -Name "*company*"
# Pattern available immediately
```

## Auto-Loading Behavior

**On session creation:**
1. SessionManager creates new Runspace
2. Imports AgentBricks from `Modules/AgentBricks/`
3. Module loads Core, Meta, State, Patterns scripts
4. Pre-configured patterns populate `$BrickStore.Patterns`
5. Checks for `.brickyard.json` in current directory, loads if exists
6. Displays module banner with pattern count

**Module banner output:**
```
╔════════════════════════════════════════════════════════╗
║          AgentBricks - Development Toolkit            ║
║                     v0.1.0 POC                         ║
╚════════════════════════════════════════════════════════╝

Quick Start:
  Get-BrickStore       - View loaded patterns and state
  Find-ProjectTools    - Discover available tools
  Get-Patterns         - List learned patterns
  Get-Help <function>  - Full documentation

Pre-loaded patterns: 41
```

**Graceful failure:** If module load fails, session continues without AgentBricks (warning logged to stderr).

## Token Efficiency Strategy

**Problem:** Large tool schemas consume token budget before conversation starts.

**Solution: Just-In-Time Discovery**
- MCP tool schemas: ~1400 tokens (test, pwsh, dev_run only)
- AgentBricks functions: 0 tokens upfront (not in schemas)
- Agents discover via `Get-Command -Module AgentBricks`
- Full help via `Get-Help <function> -Full` (on-demand)
- Pre-configured patterns: Loaded but not in tool descriptions

**Total upfront cost:** ~1400 tokens vs ~15,000 tokens for 20+ tools exposed as MCP tools.

## Pipeline-Friendly Design

All functions support PowerShell pipeline with `ValueFromPipeline`:

```powershell
# Chaining example
Get-Content build.log |
    Find-Errors |
    Measure-Frequency |
    Format-Count |
    Show -Top 10

# dev-run integration
dev-run "pytest tests/" -name "test"
$env:test_stderr |
    Extract-Regex -Pattern (Get-Patterns -Name "Pytest-Fail").Pattern |
    Group-By test |
    Format-Count
```

Standard output format: `PSCustomObject` with properties suitable for next function in chain.

## Future Enhancements

**Chains (Saved Pipelines):**
```powershell
Save-Chain -Name "analyze-build" -Pipeline {
    Find-Errors | Extract-Regex -Pattern (Get-Patterns -Name "MSBuild").Pattern | Format-Count
}

Invoke-Chain -Name "analyze-build" -Input build.log
```

**Compare (Baseline vs Current):**
```powershell
Compare-Output -Baseline $env:build1_stderr -Current $env:build2_stderr -Pattern "MSBuild"
# Shows: New errors, Fixed errors, Persistent errors
```

**Watch (Monitor Changes):**
```powershell
Watch-Command -Command "npm test" -Interval 30s -Alert "error"
# Re-runs command, alerts on pattern match
```

## Integration with dev_run Tool

AgentBricks complements the dev_run MCP tool:

**dev_run responsibilities:**
- Execute scripts
- Capture stdout/stderr separately
- Store in `$env:name_stdout`, `$env:name_stderr`, `$env:name`
- Generate condensed summary (error/warning counts)

**AgentBricks responsibilities:**
- Parse outputs with patterns (Extract-Regex)
- Aggregate and count (Measure-Frequency)
- Format results (Format-Count)
- Learn new patterns (Learn-OutputPattern)

**Combined workflow:**
```powershell
# Step 1: Run with dev-run
dev-run "dotnet build" -name "build"
# Returns: 42 errors (5 unique), top errors listed

# Step 2: Deep dive with AgentBricks
$env:build_stderr | Extract-Regex -Pattern (Get-Patterns -Name "MSBuild").Pattern |
    Where-Object { $_.Severity -eq "error" } |
    Group-By Code |
    Format-Count
#  12x: CS0103
#   8x: CS0246
#   5x: CS1002
```
