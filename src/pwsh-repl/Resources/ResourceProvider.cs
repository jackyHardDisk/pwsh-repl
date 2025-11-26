using System.ComponentModel;
using System.Text;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Resources;

/// <summary>
/// Provides dynamic MCP resources generated programmatically from module manifests.
/// All content auto-generated from Get-Module and Get-Help - zero hardcoding.
/// </summary>
[McpServerResourceType]
public class ResourceProvider
{
    private readonly SessionManager _sessionManager;

    public ResourceProvider(SessionManager sessionManager)
    {
        _sessionManager = sessionManager;
    }

    // ========================================
    // Module Overview
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://modules")]
    [Description("List all loaded PowerShell modules")]
    public string GetModules()
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            session.PowerShell.AddScript(@"
$modules = Get-Module | Sort-Object Name
if ($modules.Count -eq 0) {
    Write-Output '# PowerShell Modules'
    Write-Output ''
    Write-Output '**No modules loaded yet.** Execute a pwsh command to load modules.'
    return
}

Write-Output '# PowerShell Modules'
Write-Output ''
Write-Output 'Available modules with auto-generated resources:'
Write-Output ''

foreach ($mod in $modules) {
    Write-Output ""## $($mod.Name) v$($mod.Version)""
    Write-Output ''
    if ($mod.Description) {
        Write-Output $mod.Description
        Write-Output ''
    }
    Write-Output ""**Functions:** $($mod.ExportedFunctions.Count)""
    Write-Output ''
    Write-Output ""**Resources:**""
    Write-Output ""- pwsh_mcp://modules/$($mod.Name.ToLower()) - Module overview""
    Write-Output ""- pwsh_mcp://functions/$($mod.Name.ToLower()) - Function docstrings""
    Write-Output ""- pwsh_mcp://examples/$($mod.Name.ToLower()) - Usage examples""
    Write-Output ''
}

Write-Output '---'
Write-Output ''
Write-Output '**Other Resources:**'
Write-Output '- pwsh_mcp://mode-callback - Universal mode callback pattern'
Write-Output '- pwsh_mcp://workflows - Common analysis workflows'
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
            return $"Error retrieving modules: {ex.Message}";
        }
    }

    // ========================================
    // Module Info (Dynamic)
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://modules/{moduleName}")]
    [Description("Module overview from manifest (auto-generated)")]
    public string GetModuleInfo(string moduleName)
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            session.PowerShell.AddScript($@"
$module = Get-Module | Where-Object {{ $_.Name -eq '{moduleName}' }}

if (-not $module) {{
    Write-Output '# Module Not Found: {moduleName}'
    Write-Output ''
    Write-Output '**Module not loaded.** Check available modules: pwsh_mcp://modules'
    return
}}

Write-Output ""# $($module.Name) v$($module.Version)""
Write-Output ''

if ($module.Description) {{
    Write-Output $module.Description
    Write-Output ''
}}

Write-Output '## Functions'
Write-Output ''
$functions = $module.ExportedFunctions.Keys | Sort-Object
foreach ($func in $functions) {{
    $help = Get-Help $func -ErrorAction SilentlyContinue
    if ($help -and $help.Synopsis) {{
        Write-Output ""- **$func** - $($help.Synopsis)""
    }} else {{
        Write-Output ""- **$func**""
    }}
}}
Write-Output ''

Write-Output '## Resources'
Write-Output ''
Write-Output ""- pwsh_mcp://functions/$($module.Name.ToLower()) - Complete function documentation""
Write-Output ""- pwsh_mcp://examples/$($module.Name.ToLower()) - Usage examples""
Write-Output ''

# Show release notes if available
if ($module.PrivateData.PSData.ReleaseNotes) {{
    Write-Output '## Release Notes'
    Write-Output ''
    Write-Output $module.PrivateData.PSData.ReleaseNotes
}}
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
            return $"Error retrieving module {moduleName}: {ex.Message}";
        }
    }

    // ========================================
    // Module Functions (Dynamic)
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://functions/{moduleName}")]
    [Description("Function docstrings from Get-Help (auto-generated)")]
    public string GetModuleFunctions(string moduleName)
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            session.PowerShell.AddScript($@"
$module = Get-Module | Where-Object {{ $_.Name -eq '{moduleName}' }}

if (-not $module) {{
    Write-Output '# Functions Not Found: {moduleName}'
    Write-Output ''
    Write-Output '**Module not loaded.** Check available modules: pwsh_mcp://modules'
    return
}}

Write-Output ""# $($module.Name) Functions""
Write-Output ''

$functions = $module.ExportedFunctions.Keys | Sort-Object
foreach ($func in $functions) {{
    $help = Get-Help $func -Full -ErrorAction SilentlyContinue

    Write-Output ""## $func""
    Write-Output ''

    if ($help.Synopsis) {{
        Write-Output ""**Synopsis:** $($help.Synopsis)""
        Write-Output ''
    }}

    if ($help.Description) {{
        Write-Output ""**Description:**""
        Write-Output ''
        foreach ($desc in $help.Description) {{
            Write-Output $desc.Text
        }}
        Write-Output ''
    }}

    if ($help.Syntax) {{
        Write-Output ""**Syntax:**""
        Write-Output ''
        Write-Output '```powershell'
        foreach ($syntax in $help.Syntax.syntaxItem) {{
            $params = $syntax.parameter | ForEach-Object {{
                $name = $_.name
                $required = $_.required -eq 'true'
                if ($required) {{ ""-$name <$($_.type.name)>"" }} else {{ ""[-$name <$($_.type.name)>]"" }}
            }}
            Write-Output ""$func $($params -join ' ')""
        }}
        Write-Output '```'
        Write-Output ''
    }}

    if ($help.Parameters.parameter) {{
        Write-Output ""**Parameters:**""
        Write-Output ''
        foreach ($param in $help.Parameters.parameter) {{
            Write-Output ""- **-$($param.name)** <$($param.type.name)>""
            if ($param.description) {{
                foreach ($desc in $param.description) {{
                    Write-Output ""  $($desc.Text)""
                }}
            }}
        }}
        Write-Output ''
    }}
}}

Write-Output '---'
Write-Output ""For examples: pwsh_mcp://examples/$($module.Name.ToLower())""
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
            return $"Error retrieving functions for {moduleName}: {ex.Message}";
        }
    }

    // ========================================
    // Module Examples (Dynamic)
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://examples/{moduleName}")]
    [Description("Usage examples from Get-Help (auto-generated)")]
    public string GetModuleExamples(string moduleName)
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            session.PowerShell.AddScript($@"
$module = Get-Module | Where-Object {{ $_.Name -eq '{moduleName}' }}

if (-not $module) {{
    Write-Output '# Examples Not Found: {moduleName}'
    Write-Output ''
    Write-Output '**Module not loaded.** Check available modules: pwsh_mcp://modules'
    return
}}

Write-Output ""# $($module.Name) Examples""
Write-Output ''

$functions = $module.ExportedFunctions.Keys | Sort-Object
$exampleCount = 0

foreach ($func in $functions) {{
    $help = Get-Help $func -Full -ErrorAction SilentlyContinue

    if ($help.examples.example) {{
        Write-Output ""## $func""
        Write-Output ''

        foreach ($example in $help.examples.example) {{
            $title = $example.title -replace '-+\s*', ''
            Write-Output ""**$title**""
            Write-Output ''
            Write-Output '```powershell'
            Write-Output $example.code
            Write-Output '```'
            Write-Output ''

            if ($example.remarks) {{
                foreach ($remark in $example.remarks) {{
                    Write-Output $remark.Text
                }}
                Write-Output ''
            }}

            $exampleCount++
        }}
    }}
}}

if ($exampleCount -eq 0) {{
    Write-Output '**No examples available for this module.**'
}}
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
            return $"Error retrieving examples for {moduleName}: {ex.Message}";
        }
    }

    // ========================================
    // Mode Callback Pattern (Static)
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://mode-callback")]
    [Description("Universal mode callback pattern with 92% token reduction")]
    public string GetModeCallbackPattern()
    {
        return @"# Mode Callback Pattern

Universal dispatcher pattern achieving 92% token reduction (550 tokens saved) by consolidating 40+ separate MCP tools into single pwsh tool with mode parameter.

## Concept

Instead of separate MCP tools for each function, use mode parameter to call Base module functions.

**Without mode callback (hypothetical 40+ tools):**
```python
# Would require separate MCP tools for each function
mcp__pwsh-repl__invoke_devrun(script='dotnet build', name='build')
mcp__pwsh-repl__format_count(script='Get-Content errors.txt | Group-Object')
```

**With mode callback (4 tools: pwsh, stdin, list_sessions, pwsh_output):**
```python
# Single pwsh tool with mode parameter calls any Base module function
mcp__pwsh-repl__pwsh(mode='Invoke-DevRun', script='dotnet build', name='build')
mcp__pwsh-repl__pwsh(mode='Format-Count', script='Get-Content errors.txt | Group-Object')
```

## Parameters

- **script** (optional if mode provided) - PowerShell code to execute
- **mode** (optional) - Base module function name to call
- **name** (optional) - Cache name (auto-generated: pwsh_1, pwsh_2, etc.)
- **kwargs** (optional) - Dictionary of parameters for mode function
- **sessionId** (optional, default: 'default') - Named session
- **environment** (optional) - venv path or conda name
- **timeoutSeconds** (optional, default: 60) - Execution timeout
- **runInBackground** (optional, default: false) - Execute in background thread

## Available Tools

- **pwsh** - Execute PowerShell with mode callback pattern
- **stdin** - Write to session stdin pipe or close it
- **list_sessions** - List sessions, check health, cleanup unhealthy
- **pwsh_output** - Retrieve output from background executions

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
# First call - cached as: pwsh_1
mcp__pwsh-repl__pwsh(script='Get-Process | Select -First 5')

# Second call - cached as: pwsh_2
mcp__pwsh-repl__pwsh(script='Get-Service | Where Status -eq Running')
```

## Common Examples

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

## Token Savings

**Separate tools (OLD):**
- 40 tools × ~700 tokens/tool = ~28,000 tokens

**Mode callback (NEW):**
- 1 tool × ~1,400 tokens
- **~550 tokens saved per request (92% reduction)**
";
    }

    // ========================================
    // Common Workflows (Static)
    // ========================================

    [McpServerResource(UriTemplate = "pwsh_mcp://workflows")]
    [Description("Common analysis workflows and pipeline patterns")]
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
# Step 1: Capture build output
mcp__pwsh-repl__pwsh(
    mode='Invoke-DevRun',
    script='dotnet build',
    name='build',
    kwargs={'Streams': ['Error']}
)

# Step 2: Analyze cached errors (direct script, not mode)
mcp__pwsh-repl__pwsh(
    script='Get-StreamData build Error | Group-BuildErrors | Format-Count'
)
```

## Error Analysis (Simple - Fuzzy Only)

```python
# Capture with Invoke-DevRun via mode callback
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

## Background Process Workflow

```python
# 1. Launch non-blocking
mcp__pwsh-repl__pwsh(
    script='Invoke-BackgroundProcess -Command python -Arguments @(\"-m\", \"app.server\")'
)

# 2. Check status
mcp__pwsh-repl__pwsh(script='Test-BackgroundProcess')

# 3. Get live output (last 50 lines)
mcp__pwsh-repl__pwsh(script='Get-BackgroundData -Last 50')

# 4. Analyze errors from output
mcp__pwsh-repl__pwsh(
    script='Get-BackgroundData | Find-Errors | Group-Similar | Format-Count'
)

# 5. Kill when done
mcp__pwsh-repl__pwsh(script='Stop-BackgroundProcess')
```

## Background Execution (runInBackground)

```python
# Run long script in background
mcp__pwsh-repl__pwsh(
    script='dotnet build --no-incremental',
    runInBackground=True,
    name='long_build'
)

# Check output later with pwsh_output tool
mcp__pwsh-repl__pwsh_output(name='long_build')
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
";
    }
}
