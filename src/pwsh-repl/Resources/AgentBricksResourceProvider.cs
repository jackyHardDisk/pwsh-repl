using System.ComponentModel;
using System.Text;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Resources;

/// <summary>
/// Provides MCP resources for PowerShell module documentation.
/// Auto-generates from PWSH_MCP_MODULES environment variable.
/// All content programmatically extracted from manifests and docstrings.
/// </summary>
[McpServerResourceType]
public class PowerShellModuleResourceProvider
{
    private readonly SessionManager _sessionManager;

    public PowerShellModuleResourceProvider(SessionManager sessionManager)
    {
        _sessionManager = sessionManager;
    }

    [McpServerResource(UriTemplate = "pwsh_mcp_modules://modules")]
    [Description("List of all loaded PowerShell modules with metadata from manifests")]
    public string GetModules()
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            session.PowerShell.AddScript(@"
# Discover modules from PWSH_MCP_MODULES
$modulePaths = $env:PWSH_MCP_MODULES -split ';' | Where-Object { $_ }
$moduleManifests = $modulePaths | Where-Object { $_ -match '\.psd1$' }

# Read manifest data programmatically
foreach ($manifestPath in $moduleManifests) {
    if (-not (Test-Path $manifestPath)) { continue }

    # Import manifest as data
    $manifest = Import-PowerShellDataFile $manifestPath
    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($manifestPath)

    ""=== $moduleName ===""
    ""Version: $($manifest.ModuleVersion)""
    ""Description: $($manifest.Description)""
    """"
    ""Functions ($($manifest.FunctionsToExport.Count)):""
    $manifest.FunctionsToExport | ForEach-Object { ""  - $_"" }
    """"

    if ($manifest.PrivateData.PSData.Tags) {
        ""Tags: $($manifest.PrivateData.PSData.Tags -join ', ')""
        """"
    }

    if ($manifest.PrivateData.PSData.ReleaseNotes) {
        ""Release Notes:""
        $manifest.PrivateData.PSData.ReleaseNotes
        """"
    }
}

""---""
""For detailed function help: Get-Help FunctionName -Detailed""
""For examples: pwsh_mcp_modules://examples""
");
            var results = session.PowerShell.Invoke();
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();

            var output = new StringBuilder();
            output.AppendLine("Loaded PowerShell Modules");
            output.AppendLine("========================");
            output.AppendLine();

            foreach (var result in results)
            {
                output.AppendLine(result.ToString());
            }

            return output.ToString();
        }
        catch (Exception ex)
        {
            return $"Error retrieving modules: {ex.Message}";
        }
    }

    [McpServerResource(UriTemplate = "pwsh_mcp_modules://functions")]
    [Description("Complete list of functions with signatures from docstrings")]
    public string GetFunctions()
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            session.PowerShell.AddScript(@"
# Discover modules from PWSH_MCP_MODULES
$modulePaths = $env:PWSH_MCP_MODULES -split ';' | Where-Object { $_ }
$moduleNames = $modulePaths | ForEach-Object {
    if ($_ -match '[\\/]([^\\/]+)\.psd1$') { $matches[1] }
}

$modules = Get-Module | Where-Object { $moduleNames -contains $_.Name }
$modules | ForEach-Object {
    $moduleName = $_.Name
    ""=== $moduleName ===""
    """"

    Get-Command -Module $moduleName | Sort-Object Name | ForEach-Object {
        $cmdName = $_.Name
        $help = Get-Help $cmdName -ErrorAction SilentlyContinue

        # Extract signature
        $synopsis = $help.Synopsis
        $syntax = $help.Syntax.syntaxItem | Select-Object -First 1

        ""  $cmdName""
        ""    Synopsis: $synopsis""

        if ($syntax) {
            $params = $syntax.parameter | ForEach-Object {
                $paramName = $_.name
                $required = $_.required -eq 'true'
                $type = $_.type.name
                if ($required) { ""<$paramName>"" } else { ""[$paramName]"" }
            }
            if ($params) {
                ""    Signature: $cmdName $($params -join ' ')""
            }
        }
        """"
    }
}

""---""
""For detailed help: Get-Help <function> -Full""
""For examples: pwsh_mcp_modules://examples""
");
            var results = session.PowerShell.Invoke();
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();

            var output = new StringBuilder();
            output.AppendLine("PowerShell Module Functions");
            output.AppendLine("===========================");
            output.AppendLine();

            foreach (var result in results)
            {
                output.AppendLine(result.ToString());
            }

            return output.ToString();
        }
        catch (Exception ex)
        {
            return $"Error retrieving functions: {ex.Message}";
        }
    }

    [McpServerResource(UriTemplate = "pwsh_mcp_modules://examples")]
    [Description("Code examples extracted from function docstrings")]
    public string GetExamples()
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            session.PowerShell.AddScript(@"
# Discover modules from PWSH_MCP_MODULES
$modulePaths = $env:PWSH_MCP_MODULES -split ';' | Where-Object { $_ }
$moduleNames = $modulePaths | ForEach-Object {
    if ($_ -match '[\\/]([^\\/]+)\.psd1$') { $matches[1] }
}

$modules = Get-Module | Where-Object { $moduleNames -contains $_.Name }
$modules | ForEach-Object {
    $moduleName = $_.Name
    ""=== $moduleName ===""
    """"

    $commands = Get-Command -Module $moduleName | Sort-Object Name
    foreach ($cmd in $commands) {
        $help = Get-Help $cmd.Name -Full -ErrorAction SilentlyContinue

        if ($help.examples.example) {
            ""## $($cmd.Name)""
            """"

            foreach ($example in $help.examples.example) {
                $title = $example.title -replace '-+\s*', ''
                ""### $title""
                ""``````powershell""
                $example.code
                ""``````""

                if ($example.remarks) {
                    $example.remarks | ForEach-Object { $_.Text }
                }
                """"
            }
        }
    }
}

""---""
""Examples extracted from Get-Help -Full""
");
            var results = session.PowerShell.Invoke();
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();

            var output = new StringBuilder();
            output.AppendLine("PowerShell Module Examples");
            output.AppendLine("==========================");
            output.AppendLine();

            foreach (var result in results)
            {
                output.AppendLine(result.ToString());
            }

            return output.ToString();
        }
        catch (Exception ex)
        {
            return $"Error retrieving examples: {ex.Message}";
        }
    }

    [McpServerResource(UriTemplate = "pwsh_mcp_modules://guide")]
    [Description("Quick reference guide for PowerShell MCP modules")]
    public string GetQuickStart()
    {
        return @"# PowerShell MCP Modules Quick Start

## Common Workflows

**Build Error Analysis (Best - Regex + Fuzzy):**
```powershell
# Automatic: Extract structure, group by code, fuzzy-match messages
Get-Content build.log | Group-BuildErrors

# C# errors (CS####): Use MSBuild-Error pattern
Get-Content msbuild.log | Group-BuildErrors -Pattern 'MSBuild-Error'

# Result: 192 errors -> 35 distinct issues (81% reduction!)
```

**Error Analysis (Simple - Fuzzy only):**
```powershell
dev_run 'npm test' 'test'
pwsh 'Get-StreamData test stderr | Find-Errors | Group-Similar | Format-Count'
```

**Git Status Extraction:**
```powershell
pwsh 'git status --short | Select-RegexMatch -Pattern (Get-Patterns -Name Git-Status).Pattern | Group-By status'
```

**Custom Pattern Extraction:**
```powershell
# Extract structured data with regex named groups
Get-Content app.log | Select-RegexMatch -Pattern '(?<time>\d+:\d+) (?<level>\w+): (?<msg>.+)'
```

## Discovery

- **List functions:** `Get-Command -Module AgentBricks`
- **Get help:** `Get-Help <function> -Detailed`
- **List patterns:** `Get-Patterns` (if AgentBricks loaded)
- **Test pattern:** `Test-Pattern <pattern-name> <sample-text>`

## Key Functions

- **Transform:** Format-Count, Group-By, Measure-Frequency, Group-Similar
- **Extract:** Select-RegexMatch, Select-TextBetween, Select-Column
- **Analyze:** Find-Errors, Find-Warnings, Get-BuildError, Group-BuildErrors
- **Present:** Show, Export-ToFile, Get-StreamData
- **Meta:** Find-ProjectTools, Set-Pattern, Get-Patterns, Test-Pattern
- **State:** Save-Project, Load-Project, Get-BrickStore

## Discovery Resources

- `pwsh_mcp_modules://modules` - Module metadata from manifests
- `pwsh_mcp_modules://functions` - Function signatures from docstrings
- `pwsh_mcp_modules://examples` - Code examples from Get-Help
- `pwsh_mcp_modules://streaming-parser` - Streaming parser protocol
";
    }

    [McpServerResource(UriTemplate = "pwsh_mcp_modules://streaming-parser")]
    [Description("LoraxMod streaming parser protocol documentation with command signatures")]
    public string GetStreamingParserDocs()
    {
        return @"# LoraxMod Streaming Parser Protocol

## Overview

Long-running Node.js process for high-performance tree-sitter code parsing.
Processes multiple files (100+) with 40x+ speedup vs per-file process spawning.

## Architecture

**Process:** Node.js streaming_query_parser.js
**Protocol:** JSON command-response over stdin/stdout
**Languages:** 12 (C, C++, C#, Python, JavaScript, Bash, PowerShell, R, Rust, CSS, HTML, Fortran)

## Session Lifecycle

```powershell
# 1. Initialize session
$sessionId = Start-LoraxStreamParser -SessionId 'batch1'

# 2. Process files (reusable - one session, many files)
Get-ChildItem *.c | Invoke-LoraxStreamQuery -SessionId $sessionId -Command parse

# 3. Shutdown gracefully
$stats = Stop-LoraxStreamParser -SessionId $sessionId
```

## Commands

### PING - Health Check

**Signature:** `ping()`

Verify parser responsiveness and get current statistics.

**PowerShell:**
```powershell
Invoke-LoraxStreamQuery -SessionId 'default' -Command ping
```

**JSON Protocol:**
```json
{ ""command"": ""ping"" }
```

**Response:**
```json
{
  ""status"": ""pong"",
  ""uptime"": 5234,
  ""filesProcessed"": 42,
  ""queries"": 128,
  ""errors"": 0,
  ""memoryUsage"": { ""rss"": 123456789 }
}
```

### PARSE - Extract Code Segments

**Signature:** `parse(file: string, context?: object)`

Parse file and extract structural code segments (classes, functions, methods, etc.).

**PowerShell:**
```powershell
# Single file
Invoke-LoraxStreamQuery -SessionId 'batch1' -File 'app.c' -Command parse

# Pipeline (batch)
Get-ChildItem *.c -Recurse | Invoke-LoraxStreamQuery -SessionId 'batch1' -Command parse
```

**JSON Protocol:**
```json
{
  ""command"": ""parse"",
  ""file"": ""C:/project/app.c"",
  ""context"": {
    ""Elements"": [""function"", ""class""],
    ""Exclusions"": [""constant""],
    ""PreserveContext"": true,
    ""Filters"": { ""ClassName"": ""MyClass"" }
  }
}
```

**Response (Success):**
```json
{
  ""status"": ""ok"",
  ""result"": {
    ""file"": ""C:/project/app.c"",
    ""language"": ""c"",
    ""segments"": [
      {
        ""type"": ""function"",
        ""name"": ""calculate"",
        ""startLine"": 10,
        ""endLine"": 20,
        ""content"": ""int calculate(int x) { ... }"",
        ""lineCount"": 11
      }
    ],
    ""segmentCount"": 1
  },
  ""stats"": { ""filesProcessed"": 1, ""queries"": 0 }
}
```

**Response (Error):**
```json
{
  ""status"": ""error"",
  ""error"": {
    ""type"": ""ParseError"",
    ""message"": ""File not found: invalid.c"",
    ""file"": ""C:/project/invalid.c""
  }
}
```

### QUERY - Execute Tree-Sitter Pattern

**Signature:** `query(file: string, query: string, context?: object)`

Parse file and run tree-sitter S-expression query.

**PowerShell:**
```powershell
$query = '(function_declaration declarator: (identifier) @func)'
Invoke-LoraxStreamQuery -SessionId 'batch1' -File 'code.c' -Command query -Query $query
```

**JSON Protocol:**
```json
{
  ""command"": ""query"",
  ""file"": ""C:/project/code.c"",
  ""query"": ""(function_declaration declarator: (identifier) @func)"",
  ""context"": {}
}
```

**Response (Success):**
```json
{
  ""status"": ""ok"",
  ""result"": {
    ""file"": ""C:/project/code.c"",
    ""language"": ""c"",
    ""queryResults"": [
      {
        ""name"": ""func"",
        ""text"": ""calculate"",
        ""startPosition"": { ""row"": 9, ""column"": 14 },
        ""endPosition"": { ""row"": 9, ""column"": 23 },
        ""startIndex"": 145,
        ""endIndex"": 154
      }
    ],
    ""captureCount"": 1
  },
  ""stats"": { ""filesProcessed"": 1, ""queries"": 1 }
}
```

### SHUTDOWN - Graceful Termination

**Signature:** `shutdown()`

Stop parser, retrieve final statistics, cleanup resources.

**PowerShell:**
```powershell
$stats = Stop-LoraxStreamParser -SessionId 'batch1'
Write-Host ""Processed $($stats.FilesProcessed) files""
```

**JSON Protocol:**
```json
{ ""command"": ""shutdown"" }
```

**Response:**
```json
{
  ""status"": ""shutdown"",
  ""finalStats"": {
    ""filesProcessed"": 142,
    ""queries"": 289,
    ""errors"": 3,
    ""duration"": 12534,
    ""uptime"": 12534
  }
}
```

## Context Parameter (Extraction Filtering)

Optional parameter for parse/query commands. Filters extracted segments.

```json
{
  ""Elements"": [""function"", ""method""],          // Only extract these types
  ""Exclusions"": [""constant"", ""variable""],     // Exclude these types
  ""PreserveContext"": true,                       // Include parent class in names
  ""ScopeFilter"": ""top-level"",                  // 'top-level' for module-level only
  ""Filters"": {                                   // Name-based filters
    ""ClassName"": ""MyClass"",
    ""FunctionName"": ""calculate"",
    ""Extends"": ""BaseClass""
  }
}
```

## Error Handling

Parser catches all errors and returns JSON error response (no exceptions thrown).

**Error Format:**
```json
{
  ""status"": ""error"",
  ""error"": {
    ""type"": ""ParseError|FileNotFound|QueryError|ContextError"",
    ""message"": ""Human-readable error message"",
    ""file"": ""optional: source file if applicable""
  }
}
```

## Performance

- **Single session:** 40x faster than per-file spawning
- **Best for:** Batch processing 100+ files
- **Memory:** ~50-100 MB per session (WASM parser + grammar)
- **CPU:** Single-threaded (no concurrency benefits, but eliminates spawn overhead)

**Benchmark (1000 files):**
- Per-file spawning: ~45 seconds
- Single session: ~1.2 seconds

## Concurrent Sessions

Multiple independent parser sessions for parallel processing:

```powershell
# Session 1: Process C files
$s1 = Start-LoraxStreamParser -SessionId 'c_batch'

# Session 2: Process Python files
$s2 = Start-LoraxStreamParser -SessionId 'python_batch'

# Process in parallel
Get-ChildItem *.c | Invoke-LoraxStreamQuery -SessionId 'c_batch' -Command parse
Get-ChildItem *.py | Invoke-LoraxStreamQuery -SessionId 'python_batch' -Command parse

# Cleanup
Stop-LoraxStreamParser -SessionId 'c_batch'
Stop-LoraxStreamParser -SessionId 'python_batch'
```

## Supported Segment Types (parse command)

By language. Common types:

**C/C++:** function, class, namespace, variable, typedef, macro
**Python:** function, class, method, variable, constant
**JavaScript:** function, class, method, variable, constant, arrow_function
**PowerShell:** function, cmdlet, param, variable, filter

See loraxmod language documentation for complete segment type lists.
";
    }
}
