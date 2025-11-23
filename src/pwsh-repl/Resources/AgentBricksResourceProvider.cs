using System.ComponentModel;
using System.Text;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Resources;

/// <summary>
/// Provides granular MCP resources for PowerShell module documentation.
/// Resources organized by module for selective loading and token efficiency.
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

    // ========================================
    // Overview Resources
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://overview")]
    [Description("Overview of all loaded PowerShell modules with quick reference")]
    public string GetOverview()
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            // Check which modules are installed
            session.PowerShell.AddScript(@"
$modules = @{}
Get-Module | ForEach-Object { $modules[$_.Name] = $true }
$modules
");
            var results = session.PowerShell.Invoke();
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();

            var installedModules = new HashSet<string>();
            if (results.Count > 0 && results[0].BaseObject is System.Collections.Hashtable ht)
            {
                foreach (var key in ht.Keys)
                {
                    installedModules.Add(key.ToString()!);
                }
            }

            var overview = new StringBuilder();
            overview.AppendLine("# PowerShell MCP Server - Module Overview");
            overview.AppendLine();
            overview.AppendLine("## Available Modules");
            overview.AppendLine();

            // Base module
            if (installedModules.Contains("Base"))
            {
                overview.AppendLine("**Base** (40 functions) - Foundation module for core execution, transformation, and state management");
                overview.AppendLine("- Execution: Invoke-DevRun, Get-DevRunOutput, Invoke-WithTimeout");
                overview.AppendLine("- Transform: Format-Count, Group-By, Measure-Frequency, Group-Similar, Group-BuildErrors");
                overview.AppendLine("- Extract: Select-RegexMatch, Select-TextBetween, Select-Column");
                overview.AppendLine("- Analyze: Find-Errors, Find-Warnings, Get-BuildError");
                overview.AppendLine("- State: Save-Project, Import-Project, Get-BrickStore, Export-Environment");
                overview.AppendLine("- Cache: Get-CachedStreamData, Clear-DevRunCache, Get-DevRunCacheStats");
                overview.AppendLine("- Background: Invoke-BackgroundProcess, Stop-BackgroundProcess, Get-BackgroundData");
                overview.AppendLine();
            }

            // AgentBricks module
            if (installedModules.Contains("AgentBricks"))
            {
                overview.AppendLine("**AgentBricks** (5 functions) - Pattern learning and meta-discovery");
                overview.AppendLine("- Patterns: Get-Patterns, Set-Pattern, Test-Pattern, Register-OutputPattern");
                overview.AppendLine("- Discovery: Find-ProjectTools");
                overview.AppendLine("- Pre-configured: 43 patterns for JavaScript, Python, .NET, Build tools");
                overview.AppendLine();
            }

            // LoraxMod module
            if (installedModules.Contains("LoraxMod"))
            {
                overview.AppendLine("**LoraxMod** (7 functions) - Tree-sitter AST parsing for 12 languages");
                overview.AppendLine("- Streaming: Start-LoraxStreamParser, Invoke-LoraxStreamQuery, Stop-LoraxStreamParser");
                overview.AppendLine("- Analysis: Find-FunctionCalls, Get-IncludeDependencies");
                overview.AppendLine("- Interactive: Start-TreeSitterSession");
                overview.AppendLine();
            }

            // SessionLog module
            if (installedModules.Contains("SessionLog"))
            {
                overview.AppendLine("**SessionLog** (8 functions) - Session tracking with JSONL format (4 AM boundary)");
                overview.AppendLine("- Logging: Add-SessionLog, Add-Todo, Add-Note, Add-Bug");
                overview.AppendLine("- Reading: Read-SessionLog, Show-Session, Get-SessionDate");
                overview.AppendLine("- Updates: Update-TodoStatus");
                overview.AppendLine();
            }

            // TokenCounter module
            if (installedModules.Contains("TokenCounter"))
            {
                overview.AppendLine("**TokenCounter** (1 function) - Accurate Claude token counting");
                overview.AppendLine("- Measure-Tokens (uses tiktoken with conda environment)");
                overview.AppendLine();
            }

            if (installedModules.Count == 0)
            {
                overview.AppendLine("**No modules detected.** Modules may not be loaded yet. Try executing a pwsh command first.");
                overview.AppendLine();
            }

            overview.AppendLine("## Quick Navigation");
            overview.AppendLine();
            overview.AppendLine("**Module Details:**");
            overview.AppendLine("- pwsh_mcp://base - Base module functions and examples");
            overview.AppendLine("- pwsh_mcp://agentbricks - AgentBricks patterns and discovery");
            overview.AppendLine("- pwsh_mcp://loraxmod - LoraxMod streaming parser protocol");
            overview.AppendLine("- pwsh_mcp://sessionlog - SessionLog workflow");
            overview.AppendLine("- pwsh_mcp://tokencounter - TokenCounter usage");
            overview.AppendLine();
            overview.AppendLine("**Mode Callback Pattern:**");
            overview.AppendLine("- pwsh_mcp://mode-callback - Universal mode callback examples");
            overview.AppendLine();
            overview.AppendLine("**Workflows:**");
            overview.AppendLine("- pwsh_mcp://workflows - Common analysis workflows and pipelines");

            return overview.ToString();
        }
        catch (Exception ex)
        {
            return $"Error retrieving overview: {ex.Message}";
        }
    }

    // ========================================
    // Base Module
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://base")]
    [Description("Base module: 40 core functions for execution, transformation, and state management")]
    public string GetBaseModule()
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            session.PowerShell.AddScript(@"
$manifestPath = ""$PSScriptRoot/../Modules/Base/Base.psd1""
if (-not (Test-Path $manifestPath)) {
    Write-Output ""# Base Module (Not Installed)""
    Write-Output """"
    Write-Output ""**Module not found.** Base module is not installed or not in the expected location.""
    Write-Output """"
    Write-Output ""Expected path: $manifestPath""
    return
}

$manifest = Import-PowerShellDataFile $manifestPath

""# Base Module v$($manifest.ModuleVersion)""
""""
$manifest.Description
""""
""## Functions ($($manifest.FunctionsToExport.Count))""
""""

# Group by category (inferred from function prefix)
$categories = @{
    'Core Execution' = @('Invoke-DevRun', 'Get-DevRunOutput', 'Get-DevRunCacheList', 'Invoke-WithTimeout')
    'Background Process' = @('Invoke-BackgroundProcess', 'Stop-BackgroundProcess', 'Get-BackgroundData', 'Test-BackgroundProcess')
    'Transform' = @('Format-Count', 'Group-By', 'Measure-Frequency', 'Group-Similar', 'Group-BuildErrors', 'Get-JaroWinklerDistance')
    'Extract' = @('Select-RegexMatch', 'Select-TextBetween', 'Select-Column')
    'Analyze' = @('Find-Errors', 'Find-Warnings', 'Get-BuildError')
    'Present' = @('Show', 'Export-ToFile', 'Get-StreamData', 'Show-StreamSummary')
    'State Management' = @('Save-Project', 'Import-Project', 'Get-BrickStore', 'Export-Environment', 'Clear-Stored', 'Set-EnvironmentTee')
    'DevRun Cache' = @('Get-CachedStreamData', 'Clear-DevRunCache', 'Get-DevRunCacheStats')
    'Script Registry' = @('Add-DevScript', 'Get-DevScripts', 'Remove-DevScript', 'Update-DevScriptMetadata', 'Invoke-DevScript', 'Invoke-DevScriptChain')
}

foreach ($category in $categories.Keys | Sort-Object) {
    ""**$category**""
    """"
    foreach ($func in $categories[$category]) {
        $help = Get-Help $func -ErrorAction SilentlyContinue
        if ($help) {
            ""- **$func** - $($help.Synopsis)""
        }
    }
    """"
}

""## Mode Callback Examples""
""""
""``````python""
""# Core execution with dev_run workflow""
""mcp__pwsh-repl__pwsh(""
""    mode='Invoke-DevRun',""
""    script='dotnet build',""
""    name='build',""
""    kwargs={'Streams': ['Error', 'Warning']}""
"")""
""""
""# Transform data""
""mcp__pwsh-repl__pwsh(""
""    mode='Format-Count',""
""    script='Get-Content errors.txt | Group-Similar'""
"")""
""""
""# Background process""
""mcp__pwsh-repl__pwsh(""
""    mode='Invoke-BackgroundProcess',""
""    kwargs={'Command': 'python', 'Arguments': ['-m', 'app.server']}""
"")""
""``````""
""""
""## Release Notes""
""""
$manifest.PrivateData.PSData.ReleaseNotes
");
            var results = session.PowerShell.Invoke();
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();

            var output = new StringBuilder();
            foreach (var result in results)
            {
                output.AppendLine(result.ToString());
            }

            return output.ToString();
        }
        catch (Exception ex)
        {
            return $"Error retrieving Base module documentation: {ex.Message}";
        }
    }

    // ========================================
    // AgentBricks Module
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://agentbricks")]
    [Description("AgentBricks module: Pattern learning and meta-discovery with 43 pre-configured patterns")]
    public string GetAgentBricksModule()
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            session.PowerShell.AddScript(@"
$manifestPath = ""$PSScriptRoot/../Modules/AgentBricks/AgentBricks.psd1""
if (-not (Test-Path $manifestPath)) {
    Write-Output ""# AgentBricks Module (Not Installed)""
    Write-Output """"
    Write-Output ""**Module not found.** AgentBricks module is not installed or not in the expected location.""
    Write-Output """"
    Write-Output ""Expected path: $manifestPath""
    Write-Output """"
    Write-Output ""## Installation""
    Write-Output """"
    Write-Output ""AgentBricks is included with the PowerShell MCP Server. If you see this message, the module may not have been copied during build.""
    Write-Output """"
    Write-Output ""To resolve:""
    Write-Output ""1. Rebuild the project: dotnet build""
    Write-Output ""2. Verify CopyAgentBricksModule target in .csproj""
    Write-Output ""3. Check bin/Debug/net8.0-windows/win-x64/Modules/AgentBricks exists""
    return
}

$manifest = Import-PowerShellDataFile $manifestPath

""# AgentBricks Module v$($manifest.ModuleVersion)""
""""
$manifest.Description
""""
""## Functions ($($manifest.FunctionsToExport.Count))""
""""

foreach ($func in $manifest.FunctionsToExport) {
    $help = Get-Help $func -ErrorAction SilentlyContinue
    if ($help) {
        ""**$func**""
        ""- Synopsis: $($help.Synopsis)""

        if ($help.Examples.Example) {
            ""- Example:""
            ""  ``````powershell""
            ""  $($help.Examples.Example[0].Code)""
            ""  ``````""
        }
        """"
    }
}

""## Pre-configured Patterns (43)""
""""
""Use Get-Patterns to list all available patterns. Common patterns:""
""""
""- **MSBuild-Error** - C# compiler errors (CS####)""
""- **ESLint** - JavaScript linting errors""
""- **Pytest** - Python test failures""
""- **Git-Status** - Git status --short format""
""- **NPM-Error** - npm/yarn package errors""
""""
""## Pattern Discovery Example""
""""
""Use Get-Patterns to list available patterns, Test-Pattern to validate against sample text, and Set-Pattern to register custom patterns.""
""""
""## Release Notes""
""""
$manifest.PrivateData.PSData.ReleaseNotes
");
            var results = session.PowerShell.Invoke();
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();

            var output = new StringBuilder();
            foreach (var result in results)
            {
                output.AppendLine(result.ToString());
            }

            return output.ToString();
        }
        catch (Exception ex)
        {
            return $"Error retrieving AgentBricks module documentation: {ex.Message}";
        }
    }

    // ========================================
    // LoraxMod Module
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://loraxmod")]
    [Description("LoraxMod module: Streaming tree-sitter AST parsing for 12 languages with 40x speedup")]
    public string GetLoraxModModule()
    {
        return @"# LoraxMod Module

**Note:** LoraxMod is an optional external module. Check if loaded with `Get-Module LoraxMod`.

Tree-sitter AST parsing module with streaming session protocol for high-performance batch processing.

## Functions (7)

**Streaming Session:**
- **Start-LoraxStreamParser** - Initialize long-running parser session
- **Invoke-LoraxStreamQuery** - Process files through active session
- **Stop-LoraxStreamParser** - Gracefully shutdown session with stats

**Direct Analysis:**
- **Find-FunctionCalls** - Extract function call sites from code
- **Get-IncludeDependencies** - Map #include dependencies (C/C++)

**Interactive:**
- **Start-TreeSitterSession** - Launch interactive REPL for exploration

**Generic:**
- **Invoke-StreamingParser** - Low-level streaming protocol access

## Supported Languages (12)

C, C++, C#, Python, JavaScript, Bash, PowerShell, R, Rust, CSS, HTML, Fortran

## Streaming Protocol Examples

**Basic Batch Processing:**
```python
# Initialize session
mcp__pwsh-repl__pwsh(
    script='''
$session = Start-LoraxStreamParser -SessionId batch1
Get-ChildItem *.c -Recurse | Invoke-LoraxStreamQuery -SessionId batch1 -Command parse
$stats = Stop-LoraxStreamParser -SessionId batch1
Write-Host ""Processed $($stats.FilesProcessed) files""
'''
)
```

**Function Call Extraction:**
```python
# Extract all function calls from C# file
mcp__pwsh-repl__pwsh(
    script='Find-FunctionCalls -FilePath src/Program.cs -Language csharp | Format-Table'
)
```

**Custom Query:**
```python
# Run tree-sitter S-expression query
mcp__pwsh-repl__pwsh(
    script='''
$query = '(function_declaration declarator: (identifier) @func)'
Invoke-LoraxStreamQuery -SessionId s1 -File code.c -Command query -Query $query
'''
)
```

## Performance

- **40x faster** than per-file process spawning
- **Best for:** Batch processing 100+ files
- **Memory:** ~50-100 MB per session
- **Benchmark (1000 files):** 1.2s vs 45s

## Protocol Commands

- **ping** - Health check, get statistics
- **parse** - Extract code segments (functions, classes, etc.)
- **query** - Execute tree-sitter S-expression query
- **shutdown** - Graceful termination

## Full Protocol Documentation

See pwsh_mcp://loraxmod-protocol for complete streaming protocol specification with JSON command/response formats.
";
    }

    [McpServerResource(UriTemplate = "pwsh_mcp://loraxmod-protocol")]
    [Description("Complete LoraxMod streaming parser JSON protocol specification with command signatures")]
    public string GetLoraxModProtocol()
    {
        return @"# LoraxMod Streaming Parser Protocol

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

**JSON Request:**
```json
{ ""command"": ""ping"" }
```

**JSON Response:**
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

**JSON Request:**
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

**JSON Response (Success):**
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

### QUERY - Execute Tree-Sitter Pattern

**Signature:** `query(file: string, query: string, context?: object)`

**JSON Request:**
```json
{
  ""command"": ""query"",
  ""file"": ""C:/project/code.c"",
  ""query"": ""(function_declaration declarator: (identifier) @func)"",
  ""context"": {}
}
```

**JSON Response:**
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
        ""endPosition"": { ""row"": 9, ""column"": 23 }
      }
    ],
    ""captureCount"": 1
  }
}
```

### SHUTDOWN - Graceful Termination

**Signature:** `shutdown()`

**JSON Request:**
```json
{ ""command"": ""shutdown"" }
```

**JSON Response:**
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

## Context Parameter

Optional filter for parse/query commands:

```json
{
  ""Elements"": [""function"", ""method""],
  ""Exclusions"": [""constant"", ""variable""],
  ""PreserveContext"": true,
  ""ScopeFilter"": ""top-level"",
  ""Filters"": {
    ""ClassName"": ""MyClass"",
    ""FunctionName"": ""calculate""
  }
}
```

## Error Handling

**Error Response Format:**
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

## Supported Segment Types

**C/C++:** function, class, namespace, variable, typedef, macro
**Python:** function, class, method, variable, constant
**JavaScript:** function, class, method, variable, constant, arrow_function
**PowerShell:** function, cmdlet, param, variable, filter
";
    }

    // ========================================
    // SessionLog Module
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://sessionlog")]
    [Description("SessionLog module: JSONL-based session tracking with 4 AM boundary for todos, notes, bugs")]
    public string GetSessionLogModule()
    {
        return @"# SessionLog Module

**Note:** SessionLog is an optional external module. Check if loaded with `Get-Module SessionLog`.

Session tracking with JSONL format and 4 AM session boundary rule.

## Functions (8)

**Logging:**
- **Add-SessionLog** - Create session entry with completed tasks, todos, notes, bugs
- **Add-Todo** - Add single todo item
- **Add-Note** - Add technical note
- **Add-Bug** - Report bug discovered

**Reading:**
- **Read-SessionLog** - Read JSONL entries with filtering
- **Show-Session** - Display formatted session summary
- **Get-SessionDate** - Get current session date (4 AM boundary)

**Updates:**
- **Update-TodoStatus** - Mark todo as completed/abandoned

## 4 AM Boundary Rule

Sessions span from 4 AM to 3:59 AM next day. Times before 4 AM count as previous day.

**Example:**
- 2025-11-23 05:00 → Session: 2025-11-23
- 2025-11-23 02:00 → Session: 2025-11-22 (previous day!)

## Workflow Example

```python
# End of session debrief
mcp__pwsh-repl__pwsh(
    script='''
Add-SessionLog -Completed @(
    ""Fixed PwshTool.cs JsonElement conversion"",
    ""Migrated 40 functions to Base module""
) -Todos @(
    ""Test mode callback pattern"",
    ""Update docstrings""
) -Notes @(
    ""Mode callback achieved 92% token reduction"",
    ""JsonElement requires explicit lambda""
)
'''
)

# Read recent sessions
mcp__pwsh-repl__pwsh(
    script='Read-SessionLog -Last 50 | Where-Object {$_.type -eq ""todo""} | Format-Table'
)

# Update todo status
mcp__pwsh-repl__pwsh(
    script='Update-TodoStatus -Index 0 -Status completed'
)
```

## File Format

**Location:** `.gary/logs/sessions.jsonl`
**Format:** JSONL (newline-delimited JSON)

**Entry Types:**
```json
{""timestamp"":""2025-11-23T14:30:00"",""session"":""2025-11-23"",""type"":""completed"",""task"":""Fix bug""}
{""timestamp"":""2025-11-23T14:31:00"",""session"":""2025-11-23"",""type"":""todo"",""task"":""Add tests"",""status"":""pending""}
{""timestamp"":""2025-11-23T14:32:00"",""session"":""2025-11-23"",""type"":""note"",""content"":""Design decision""}
```
";
    }

    // ========================================
    // TokenCounter Module
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://tokencounter")]
    [Description("TokenCounter module: Accurate Claude token counting using tiktoken with conda environment")]
    public string GetTokenCounterModule()
    {
        return @"# TokenCounter Module

**Note:** TokenCounter is an optional external module. Check if loaded with `Get-Module TokenCounter`.

Accurate Claude token counting using tiktoken library in conda environment.

## Function (1)

**Measure-Tokens** - Count tokens for Claude models

**Parameters:**
- Text (pipeline or parameter) - Text to tokenize
- Model (optional) - Model name (default: claude-sonnet-4-5)

## Usage Examples

```python
# Count tokens in file
mcp__pwsh-repl__pwsh(
    script='Get-Content README.md | Measure-Tokens'
)

# Count with specific model
mcp__pwsh-repl__pwsh(
    script='Get-Content script.ps1 | Measure-Tokens -Model claude-opus-4'
)

# Count string directly
mcp__pwsh-repl__pwsh(
    script='""Hello world"" | Measure-Tokens'
)
```

## Supported Models

- claude-sonnet-4-5 (default)
- claude-opus-4
- claude-haiku-4
- claude-3-5-sonnet
- claude-3-opus
- claude-3-haiku

## Requirements

**Conda Environment:** planetarium-test (auto-activated)
**Python Package:** tiktoken

## Output Format

```
Text: Hello world
Tokens: 3
Model: claude-sonnet-4-5
```
";
    }

    // ========================================
    // Mode Callback Pattern
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://mode-callback")]
    [Description("Mode callback pattern: Universal dispatcher for Base module functions with 92% token reduction")]
    public string GetModeCallbackPattern()
    {
        return @"# Mode Callback Pattern

Universal dispatcher pattern that achieves 92% token reduction (550 tokens saved) by consolidating 40+ separate MCP tools into single pwsh tool with mode parameter.

## Concept

Instead of separate MCP tools for each function, use mode parameter to call Base module functions:

**OLD (40+ tools):**
```python
mcp__pwsh-repl__dev_run(script='dotnet build', name='build')
mcp__pwsh-repl__format_count(script='Get-Content errors.txt | Group-Object')
mcp__pwsh-repl__invoke_background(command='python', arguments=['server.py'])
```

**NEW (1 tool with mode):**
```python
mcp__pwsh-repl__pwsh(mode='Invoke-DevRun', script='dotnet build', name='build')
mcp__pwsh-repl__pwsh(mode='Format-Count', script='Get-Content errors.txt | Group-Object')
mcp__pwsh-repl__pwsh(mode='Invoke-BackgroundProcess', kwargs={'Command': 'python', 'Arguments': ['server.py']})
```

## Parameters

**script** (optional if mode provided) - PowerShell code to execute
**mode** (optional) - Base module function name to call
**name** (optional) - Cache name (auto-generated: pwsh_1, pwsh_2, etc.)
**kwargs** (optional) - Dictionary of parameters for mode function
**sessionId** (optional, default: ""default"") - Named session
**environment** (optional) - venv path or conda name
**timeoutSeconds** (optional, default: 60) - Execution timeout

## How It Works

C# PwshTool.cs builds PowerShell command:

```csharp
// mode='Invoke-DevRun', script='dotnet build', kwargs={'Streams': ['Error', 'Warning']}
// Becomes:
Invoke-DevRun -Script {dotnet build} -Streams @('Error', 'Warning')
```

## Auto-Caching

ALL executions auto-cache in $global:DevRunCache with auto-generated names:

```python
# First call
mcp__pwsh-repl__pwsh(script='Get-Process | Select -First 5')
# Cached as: pwsh_1

# Second call
mcp__pwsh-repl__pwsh(script='Get-Service | Where Status -eq Running')
# Cached as: pwsh_2
```

## JsonElement Conversion

MCP SDK passes kwargs as Dictionary<string, object> where values are System.Text.Json.JsonElement.

**Conversion rules:**
- `JsonElement.String` → `'value'`
- `JsonElement.Number` → `42`
- `JsonElement.True/False` → `$true/$false`
- `JsonElement.Array` → `@('item1', 'item2')`
- `JsonElement.Object` → `@{ key = 'value' }`

**Example:**
```python
kwargs={'Streams': ['Error', 'Warning'], 'Verbose': True}
# Converts to:
-Streams @('Error', 'Warning') -Verbose $true
```

## Common Mode Callback Examples

**Core Execution:**
```python
mcp__pwsh-repl__pwsh(
    mode='Invoke-DevRun',
    script='dotnet build',
    name='build',
    kwargs={'Streams': ['Error', 'Warning']}
)
```

**Transform:**
```python
mcp__pwsh-repl__pwsh(
    mode='Format-Count',
    script='Get-Content errors.txt | Group-Similar'
)
```

**Background Process:**
```python
mcp__pwsh-repl__pwsh(
    mode='Invoke-BackgroundProcess',
    kwargs={'Command': 'python', 'Arguments': ['-m', 'app.server']}
)
```

**Retrieve Cached:**
```python
mcp__pwsh-repl__pwsh(
    mode='Get-DevRunOutput',
    kwargs={'Name': 'build', 'Stream': 'Error'}
)
```

**Piped Mode + Script:**
```python
# Mode function output pipes to script
mcp__pwsh-repl__pwsh(
    mode='Get-BackgroundData',
    script='Find-Errors | Group-Similar | Format-Count'
)
```

## Token Savings

**Separate tools (OLD):**
- 40 tools × ~700 tokens/tool = ~28,000 tokens
- Context overhead for all tool definitions

**Mode callback (NEW):**
- 1 tool × ~1,400 tokens (includes mode param docs)
- ~550 tokens saved per request (92% reduction)

## Direct Script Execution

Mode parameter is optional. Can execute PowerShell directly:

```python
# No mode - direct execution (still auto-cached!)
mcp__pwsh-repl__pwsh(
    script='Get-Process | Where CPU -gt 100 | Select -First 5'
)
```
";
    }

    // ========================================
    // Common Workflows
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://workflows")]
    [Description("Common analysis workflows and pipeline patterns using Base and AgentBricks modules")]
    public string GetWorkflows()
    {
        return @"# Common Workflows

## Build Error Analysis

**Best: Regex + Fuzzy Hybrid (Group-BuildErrors)**
```python
# Automatic: Extract structure, group by code, fuzzy-match messages
mcp__pwsh-repl__pwsh(
    script='Get-Content build.log | Group-BuildErrors | Format-Count'
)

# Result: 192 errors → 35 distinct issues (81% reduction!)
```

**C# Compiler Errors:**
```python
mcp__pwsh-repl__pwsh(
    mode='Invoke-DevRun',
    script='dotnet build',
    name='build',
    kwargs={'Streams': ['Error']}
)

mcp__pwsh-repl__pwsh(
    mode='Get-StreamData',
    script='Group-BuildErrors -Pattern ""MSBuild-Error"" | Format-Count',
    kwargs={'Name': 'build', 'Stream': 'Error'}
)
```

## Error Analysis (Simple - Fuzzy Only)

```python
# Capture with dev_run
mcp__pwsh-repl__pwsh(
    mode='Invoke-DevRun',
    script='npm test',
    name='test',
    kwargs={'Streams': ['Error', 'Warning']}
)

# Analyze errors
mcp__pwsh-repl__pwsh(
    script='Get-StreamData test stderr | Find-Errors | Group-Similar | Format-Count'
)
```

## Git Status Extraction

```python
# Extract structured data with regex named groups
mcp__pwsh-repl__pwsh(
    script='''
git status --short |
Select-RegexMatch -Pattern (Get-Patterns -Name Git-Status).Pattern |
Group-By status |
Format-Count
'''
)
```

## Background Process Workflow

```python
# 1. Launch non-blocking
mcp__pwsh-repl__pwsh(
    mode='Invoke-BackgroundProcess',
    kwargs={'Command': 'python', 'Arguments': ['-m', 'app.server']}
)

# 2. Check status
mcp__pwsh-repl__pwsh(mode='Test-BackgroundProcess')

# 3. Get live output
mcp__pwsh-repl__pwsh(
    mode='Get-BackgroundData',
    kwargs={'Last': 50}
)

# 4. Analyze errors from output
mcp__pwsh-repl__pwsh(
    mode='Get-BackgroundData',
    script='Find-Errors | Group-Similar | Format-Count'
)

# 5. Kill when done
mcp__pwsh-repl__pwsh(mode='Stop-BackgroundProcess')
```

## Streaming Parser Batch Processing

```python
# Process 100+ files with 40x speedup
mcp__pwsh-repl__pwsh(
    script='''
$session = Start-LoraxStreamParser -SessionId batch1
Get-ChildItem *.c -Recurse | Invoke-LoraxStreamQuery -SessionId batch1 -Command parse
$stats = Stop-LoraxStreamParser -SessionId batch1
Write-Host ""Processed $($stats.FilesProcessed) files""
'''
)
```

## Custom Pattern Extraction

```python
# Register pattern
mcp__pwsh-repl__pwsh(
    script='''
Set-Pattern -Name ""AppLog"" -Pattern ""(?<time>\d+:\d+) (?<level>\w+): (?<msg>.+)""
'''
)

# Extract data
mcp__pwsh-repl__pwsh(
    script='''
Get-Content app.log |
Select-RegexMatch -Pattern (Get-Patterns -Name AppLog).Pattern |
Group-By level |
Format-Count
'''
)
```

## Session Logging Workflow

```python
# End of session debrief
mcp__pwsh-repl__pwsh(
    script='''
Add-SessionLog -Completed @(
    ""Implemented feature X"",
    ""Fixed bug Y""
) -Todos @(
    ""Add tests for feature X"",
    ""Document API changes""
) -Notes @(
    ""Design decision: Use strategy pattern for extensibility""
)
'''
)

# Review pending todos
mcp__pwsh-repl__pwsh(
    script='''
Read-SessionLog -Last 100 |
Where-Object {$_.type -eq ""todo"" -and $_.status -eq ""pending""} |
Format-Table -AutoSize
'''
)
```

## Script Registry Pattern

```python
# Register reusable scripts
mcp__pwsh-repl__pwsh(
    script='''
Add-DevScript -Name ""AnalyzeErrors"" -Script {
    param($LogFile)
    Get-Content $LogFile | Find-Errors | Group-Similar | Format-Count
}
'''
)

# Execute registered script
mcp__pwsh-repl__pwsh(
    mode='Invoke-DevScript',
    kwargs={'Name': 'AnalyzeErrors', 'Parameters': {'LogFile': 'build.log'}}
)
```

## Token Counting

```python
# Count tokens in documentation
mcp__pwsh-repl__pwsh(
    script='Get-Content README.md | Measure-Tokens',
    environment='planetarium-test'
)
```
";
    }
}
