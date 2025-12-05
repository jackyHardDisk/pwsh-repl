# AgentBlocks Module Documentation

## Overview

AgentBlocks is a self-teaching PowerShell module that provides concrete development
tools, pre-configured patterns for common tools, and meta-learning capabilities for
Claude agents. The module auto-loads when PowerShell MCP sessions are created.

**Design Philosophy: Hybrid v1+v2+v3 Approach**

- **v1 (Concrete):** Immediately useful functions like Format-Count, Find-Errors
- **v2 (Pre-configured):** 40+ patterns for JavaScript, Python, .NET, Build tools
- **v3 (Meta-learning):** Register-OutputPattern for self-teaching new tools

**Token Efficiency:** Module functions are NOT included in MCP tool schemas. Agents
discover them via `Get-Help` on-demand. This keeps upfront token cost at ~1400 tokens (3
MCP tools only).

## Module Structure

```
AgentBlocks/
├── AgentBlocks.psd1           # Module manifest (35 exported functions)
├── AgentBlocks.psm1           # Main module (BrickStore initialization, auto-loads patterns)
├── Core/
│   ├── Transform.ps1          # Format-Count, Group-By, Measure-Frequency, Group-Similar, Group-BuildErrors
│   ├── Extract.ps1            # Select-RegexMatch, Select-TextBetween, Select-Column
│   ├── Analyze.ps1            # Find-Errors, Find-Warnings, Get-BuildError
│   └── Present.ps1            # Show, Export-ToFile, Get-StreamData, Show-StreamSummary
├── Meta/
│   ├── Discovery.ps1          # Find-ProjectTools
│   └── Learning.ps1           # Set-Pattern, Get-Patterns, Test-Pattern, Register-OutputPattern
├── State/
│   ├── Management.ps1         # Save-Project, Import-Project, Get-BrickStore, Export-Environment, Clear-Stored, Set-EnvironmentTee
│   └── DevRunCache.ps1        # Initialize-DevRunCache, Get-DevRunCacheStats, Get-CachedStreamData, Clear-DevRunCache
│   └── DevRunScripts.ps1      # Add-DevScript, Get-DevScripts, Remove-DevScript, Update-DevScriptMetadata, Invoke-DevScript, Invoke-DevScriptChain
├── Utility/
│   └── Common.ps1             # Invoke-WithTimeout, Invoke-PythonScript
└── Patterns/
    ├── JavaScript.ps1         # ESLint, Stylelint, TypeScript, Prettier, Vite, Webpack, Jest, Node.js (8)
    ├── Python.ps1             # Pytest, Mypy, Flake8, Black, Pylint, unittest, Coverage, tracebacks (10)
    ├── DotNet.ps1             # MSBuild, NuGet, NUnit, xUnit, MSTest, Roslyn, StyleCop (10)
    └── Build.ps1              # GCC, Clang, CMake, Make, Ninja, Maven, Gradle, Rust, Cargo, Go (13+)
```

## Function Categories

### Transform Functions (5)

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

**Group-Similar** - Fuzzy grouping with Jaro-Winkler distance

```powershell
# Group similar error messages (default 85% similarity)
Find-Errors build.log | Group-Similar -Threshold 0.85
# Count: 42
# Example: error: Cannot find module 'foo'
# Items: [array of similar errors]

# Group by property with custom threshold
Get-BuildError | Group-Similar -Property message -Threshold 0.90

# Works with any text
"hello world", "helo world", "goodbye" | Group-Similar -Threshold 0.80
```

**Group-BuildErrors** - Pattern-aware build error grouping with fuzzy matching

```powershell
# Group MSBuild errors by code and similar messages
Find-Errors build.log | Group-BuildErrors -Pattern "MSBuild-Error" -Threshold 0.85
# Count: 42
# Code: CS0103
# Message: The name 'foo' does not exist in the current context
# Files: 8

# Group GCC errors
Get-BuildError gcc.log | Group-BuildErrors -Pattern "GCC" -Threshold 0.90

# Use with custom patterns
Get-Patterns | Where-Object Category -eq 'error' | ForEach-Object {
    Find-Errors log | Group-BuildErrors -Pattern $_.Name
}
```

### Extract Functions (3)

**Select-RegexMatch** - Extract named groups from regex pattern

```powershell
"app.js:42:15: error: undefined" | Select-RegexMatch -Pattern '(?<file>\S+):(?<line>\d+)'
# Returns PSCustomObject with file="app.js", line="42"

# Use stored pattern
$pattern = Get-Patterns -Name "ESLint"
$env:lint_stderr | Select-RegexMatch -Pattern $pattern.Pattern
```

**Select-TextBetween** - Extract text between delimiters

```powershell
"<error>File not found</error>" | Select-TextBetween -Start "<error>" -End "</error>"
# Output: File not found

Get-Content log.xml | Select-TextBetween -Start "<message>" -End "</message>"
```

**Select-Column** - Extract column from delimited text

```powershell
"app.js:42:error:undefined" | Select-Column -Delimiter ":" -Column 2
# Output: 42

Get-Content data.csv | Select-Column -Delimiter "," -Column 0
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

**Get-BuildError** - Parse build tool output (MSBuild, GCC, Clang)

```powershell
Get-BuildError build.log
# Returns structured objects with File, Line, Col, Severity, Code, Message

Get-BuildError msbuild.log | Where-Object { $_.Code -like "CS*" }
# Filter C# compiler errors

Get-BuildError gcc.log | Group-By Severity | Format-Count
#  42x: error
#  12x: warning
```

### Present Functions (4)

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

**Get-StreamData** - Retrieve specific stream from DevRun cache (JSON storage)

```powershell
# Get error stream from build run
Get-StreamData -Name "build" -Stream "Error"

# Get output stream
Get-StreamData -Name "test" -Stream "Output"

# Pipeline for analysis
Get-StreamData build Error | Measure-Frequency | Format-Count
#  42x: CS0103: The name 'foo' does not exist
#   8x: CS0246: Type or namespace not found

# Combine streams
Get-StreamData build Error | Group-Similar -Threshold 0.85
```

**Show-StreamSummary** - Display formatted summary of Invoke-DevRun cached streams

```powershell
# Show default streams (Error, Warning)
Show-StreamSummary -Name "build"

# Show specific streams
Show-StreamSummary -Name "test" -Streams Error,Warning,Output

# Custom top count
Show-StreamSummary -Name "build" -Streams Error -TopCount 10

# Output:
# Errors: 42 (5 unique)
#
# Top Errors:
#     8x: CS0103: The name 'foo' does not exist
#     3x: CS0246: Type or namespace not found
#     1x: CS1002: ; expected
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

**Register-OutputPattern** - Interactively learn new tool patterns

```powershell
# Interactive mode (prompts for pattern selection)
Register-OutputPattern -Name "myapp-lint" -Command "myapp lint src/" -Interactive

# Auto mode (detects and registers best-guess pattern)
Register-OutputPattern -Name "custom-test" -Command "npm test" -Category test
```

Auto-detects common patterns:

- GCC-style: `file:line:col: severity: message`
- MSBuild-style: `file(line,col): severity code: message`
- Test-style: `STATUS test - message`
- Generic: `severity: message`

### State Management (6)

**Save-Project** - Save BrickStore state to .brickyard.json

```powershell
Save-Project -Path ".brickyard.json"
# Saves patterns, results, chains for reuse
```

**Import-Project** - Load saved state from .brickyard.json

```powershell
Import-Project -Path ".brickyard.json"
# Restores patterns from previous session
```

**Get-BrickStore** - View current BrickStore contents

```powershell
Get-BrickStore
# Shows: Results count, Patterns count, Chains count

Get-BrickStore -Detailed
# Full dump of all stored data
```

**Export-Environment** - Export current environment variables to JSON file

```powershell
Export-Environment -Path "session.json"
# Saves all $env: variables to file

Export-Environment -Path "build-vars.json" -Filter "build_*"
# Export only matching variables
```

**Clear-Stored** - Reset BrickStore state

```powershell
Clear-Stored
# Clears all patterns, results, chains

Clear-Stored -PatternOnly
# Keep results/chains, clear patterns only
```

**Set-EnvironmentTee** - Capture pipeline items to $env variable while passing through

```powershell
# Capture errors while displaying
Find-Errors build.log | Set-EnvironmentTee -Name "captured_errors" | Show -Top 5

# Later access captured data
$env:captured_errors | Measure-Frequency

# Chain with analysis
Get-BuildError |
    Set-EnvironmentTee -Name "all_issues" |
    Where-Object Severity -eq 'error' |
    Group-By Code |
    Format-Count

# Verbose shows what's being captured
Find-Warnings | Set-EnvironmentTee -Name "warnings" -Verbose
```

### DevRun Cache (4 functions)

**Initialize-DevRunCache** - Initialize ConcurrentDictionary cache structures

```powershell
Initialize-DevRunCache
# Creates $global:DevRunCache and $global:DevRunScripts
# Called automatically on module load
```

**Get-DevRunCacheStats** - Display cache statistics

```powershell
Get-DevRunCacheStats
# Output:
# DevRun Cache Statistics
# =======================
# Cached Streams: 0
# Script Registry: 3
```

**Get-CachedStreamData** - Retrieve stream data with caching (performance optimized)

```powershell
# First call: parses JSON from $env, caches result
Get-CachedStreamData -Name "build" -Stream "Error"

# Subsequent calls: returns from cache (faster)
Get-CachedStreamData -Name "build" -Stream "Error"
```

**Clear-DevRunCache** - Clear all cached stream data

```powershell
Clear-DevRunCache
# Clears $global:DevRunCache
```

### DevRun Scripts (6 functions)

**Add-DevScript** - Register script metadata in global registry

```powershell
# Basic registration
Add-DevScript -Name "build" -Script "dotnet build"

# With dependencies
Add-DevScript -Name "test" -Script "dotnet test" -Dependencies @("build")

# With exit code tracking
Add-DevScript -Name "deploy" -Script "kubectl apply -f app.yaml" -ExitCode 0
```

**Get-DevScripts** - List all registered scripts with metadata

```powershell
Get-DevScripts
# Name         Timestamp           ExitCode Dependencies
# ----         ---------           -------- ------------
# build        2025-11-18 13:47:46        0
# test         2025-11-18 13:48:12        0 build
# deploy       2025-11-18 13:49:01        0 test
```

**Remove-DevScript** - Remove script from registry

```powershell
Remove-DevScript -Name "test"
# Removed script 'test' from registry
```

**Update-DevScriptMetadata** - Update script metadata after execution

```powershell
Update-DevScriptMetadata -Name "build" -ExitCode 1
# Updates timestamp and exit code
```

**Invoke-DevScript** - Execute a registered script

```powershell
# Basic invocation
Invoke-DevScript -Name "build"

# Update metadata after execution
Invoke-DevScript -Name "build" -UpdateMetadata

# Return output for further processing
$result = Invoke-DevScript -Name "build" -PassThru
```

**Invoke-DevScriptChain** - Execute multiple scripts in sequence

```powershell
# Basic chain (stops on first failure)
Invoke-DevScriptChain -Names @("build", "test", "deploy")

# Continue even if scripts fail
Invoke-DevScriptChain -Names @("lint", "format", "build") -ContinueOnError

# Update metadata for each script
Invoke-DevScriptChain -Names @("build", "test") -UpdateMetadata

# Output:
# Executing: build
# Executing: test
#
# Chain Summary:
#   Total scripts: 2
#   Executed: 2
#   Successful: 2
#   Failed: 0
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

AgentBlocks maintains a global `$BrickStore` hashtable with session-persistent state:

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
$env:build_stderr | Select-RegexMatch -Pattern (Get-Patterns -Name "MSBuild").Pattern | Format-Count
#     8x: CS0103
#     3x: CS0246
#     1x: CS1002

# Filter specific error code
$env:build_stderr | Select-RegexMatch -Pattern (Get-Patterns -Name "MSBuild").Pattern |
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
$env:test_stderr | Select-RegexMatch -Pattern (Get-Patterns -Name "Jest").Pattern
```

### Workflow 3: Learning Custom Tool

```powershell
# Learn new tool pattern interactively
Register-OutputPattern -Name "myapp-lint" -Command "myapp lint src/" -Interactive

# Agent sees:
# Detected patterns:
#   1. GCC-style: file:line:col: severity: message
#   2. Generic: severity: message
# Select pattern (1-2) or 'c' for custom: 1

# Pattern registered and ready for use
$env:lint_output | Select-RegexMatch -Pattern (Get-Patterns -Name "myapp-lint").Pattern

# Save for future sessions
Save-Project -Path ".brickyard.json"
```

### Workflow 4: Cross-Project Pattern Reuse

```powershell
# Project A: Learn patterns
Register-OutputPattern -Name "company-tool" -Command "tool validate" -Category lint
Save-Project -Path "company-patterns.json"

# Project B: Reuse patterns
Import-Project -Path "C:\shared\company-patterns.json"
Get-Patterns -Name "*company*"
# Pattern available immediately
```

### Workflow 5: DevRun Script Automation (NEW)

```powershell
# Run build with Invoke-DevRun (auto-registers script)
mcp__pwsh-repl__pwsh(
    mode='Invoke-DevRun',
    script='dotnet build',
    name='build'
)

# Run tests with Invoke-DevRun (auto-registers script)
mcp__pwsh-repl__pwsh(
    mode='Invoke-DevRun',
    script='dotnet test',
    name='test'
)

# View registered scripts
Get-DevScripts
# Name   Timestamp           ExitCode Dependencies
# ----   ---------           -------- ------------
# build  2025-11-18 13:47:46        0
# test   2025-11-18 13:48:12        0

# Chain them together for CI/CD
Invoke-DevScriptChain -Names @("build", "test")
# Executing: build
# Executing: test
#
# Chain Summary:
#   Total scripts: 2
#   Executed: 2
#   Successful: 2
#   Failed: 0

# Analyze errors from build
Get-StreamData build Error | Group-Similar -Threshold 0.85 | Show -Top 5

# Combine outputs from both runs
@("build", "test") | ForEach-Object {
    Get-StreamData -Name $_ -Stream "Output"
} | Measure-Frequency | Format-Count
```

## Auto-Loading Behavior

**On session creation:**

1. SessionManager creates new Runspace
2. Imports AgentBlocks from `Modules/AgentBlocks/`
3. Module loads Core, Meta, State, Patterns scripts
4. Pre-configured patterns populate `$BrickStore.Patterns`
5. Checks for `.brickyard.json` in current directory, loads if exists
6. Displays module banner with pattern count

**Module banner output:**

```
╔════════════════════════════════════════════════════════╗
║          AgentBlocks - Development Toolkit            ║
║                     v0.1.0 POC                         ║
╚════════════════════════════════════════════════════════╝

Quick Start:
  Get-BrickStore       - View loaded patterns and state
  Find-ProjectTools    - Discover available tools
  Get-Patterns         - List learned patterns
  Get-Help <function>  - Full documentation

Pre-loaded patterns: 41
```

**Graceful failure:** If module load fails, session continues without AgentBlocks (
warning logged to stderr).

## Token Efficiency Strategy

**Problem:** Large tool schemas consume token budget before conversation starts.

**Solution: Just-In-Time Discovery**

- MCP tool schemas: ~1400 tokens (pwsh, stdin, list_sessions only)
- AgentBlocks functions: 0 tokens upfront (not in schemas)
- Agents discover via `Get-Command -Module AgentBlocks`
- Full help via `Get-Help <function> -Full` (on-demand)
- Pre-configured patterns: Loaded but not in tool descriptions

**Total upfront cost:** ~1400 tokens vs ~15,000 tokens for 20+ tools exposed as MCP
tools.

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
    Select-RegexMatch -Pattern (Get-Patterns -Name "Pytest-Fail").Pattern |
    Group-By test |
    Format-Count
```

Standard output format: `PSCustomObject` with properties suitable for next function in
chain.

## Future Enhancements

**Chains (Saved Pipelines):**

```powershell
Save-Chain -Name "analyze-build" -Pipeline {
    Find-Errors | Select-RegexMatch -Pattern (Get-Patterns -Name "MSBuild").Pattern | Format-Count
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

## Integration with Invoke-DevRun Workflow

AgentBlocks complements the Invoke-DevRun function (Base module):

**Invoke-DevRun responsibilities:**

- Execute scripts via pwsh tool mode callback
- Capture stdout/stderr/streams separately
- Store in `$global:DevRunCache` (JSON structure)
- Generate condensed summary (error/warning counts)
- Set environment variables (`$env:name_stdout`, `$env:name_stderr`)

**AgentBlocks responsibilities:**

- Parse outputs with patterns (Select-RegexMatch)
- Aggregate and count (Measure-Frequency)
- Format results (Format-Count)
- Learn new patterns (Register-OutputPattern)

**Combined workflow:**

```powershell
# Step 1: Run with dev-run
dev-run "dotnet build" -name "build"
# Returns: 42 errors (5 unique), top errors listed

# Step 2: Deep dive with AgentBlocks
$env:build_stderr | Select-RegexMatch -Pattern (Get-Patterns -Name "MSBuild").Pattern |
    Where-Object { $_.Severity -eq "error" } |
    Group-By Code |
    Format-Count
#  12x: CS0103
#   8x: CS0246
#   5x: CS1002
```
