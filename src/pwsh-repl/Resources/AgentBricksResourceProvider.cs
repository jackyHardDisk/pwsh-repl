using System.ComponentModel;
using System.Text;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Resources;

/// <summary>
/// Provides MCP resources for PowerShell module documentation.
/// Auto-generates from PWSH_MCP_MODULES environment variable.
/// Resources are fetched on-demand, not included in tool descriptions.
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
    [Description("List of all loaded PowerShell modules from PWSH_MCP_MODULES")]
    public string GetModules()
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            session.PowerShell.AddScript(@"
Get-Module | Where-Object { $_.Path -like '*AgentBricks*' -or $_.Path -like '*Base*' -or $_.Name -match 'SessionLog|TokenCounter' } |
    Select-Object Name, Description, @{N='Functions';E={($_.ExportedCommands.Values | Measure-Object).Count}} |
    Format-Table -AutoSize |
    Out-String -Width 120
");
            var results = session.PowerShell.Invoke();
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();

            var output = new StringBuilder();
            output.AppendLine("Loaded PowerShell Modules");
            output.AppendLine("========================");
            output.AppendLine();
            output.AppendLine("From PWSH_MCP_MODULES environment variable:");
            output.AppendLine();

            foreach (var result in results)
            {
                output.Append(result.ToString());
            }

            return output.ToString();
        }
        catch (Exception ex)
        {
            return $"Error retrieving modules: {ex.Message}";
        }
    }

    [McpServerResource(UriTemplate = "pwsh_mcp_modules://functions")]
    [Description("Complete list of functions from all loaded PowerShell modules")]
    public string GetFunctions()
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            session.PowerShell.AddScript(@"
$modules = Get-Module | Where-Object { $_.Path -like '*AgentBricks*' -or $_.Path -like '*Base*' -or $_.Name -match 'SessionLog|TokenCounter' }
$modules | ForEach-Object {
    $moduleName = $_.Name
    ""=== $moduleName ===""
    Get-Command -Module $moduleName | Sort-Object Name | ForEach-Object {
        $help = Get-Help $_.Name -ErrorAction SilentlyContinue
        ""  $($_.Name) - $($help.Synopsis)""
    }
    """"
}
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

    [McpServerResource(UriTemplate = "pwsh_mcp_modules://patterns")]
    [Description("Pre-configured regex patterns from modules (AgentBricks, etc.)")]
    public string GetPatterns()
    {
        var session = _sessionManager.GetOrCreateSession("resource_temp");

        try
        {
            session.PowerShell.AddScript(@"
Get-Patterns |
    Sort-Object Category, Name |
    Format-Table -AutoSize Category, Name, Description |
    Out-String -Width 120
");
            var results = session.PowerShell.Invoke();
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();

            var output = new StringBuilder();
            output.AppendLine("Pre-configured Patterns");
            output.AppendLine("=======================");
            output.AppendLine();

            foreach (var result in results)
            {
                output.Append(result.ToString());
            }

            return output.ToString();
        }
        catch (Exception ex)
        {
            return $"Error retrieving patterns: {ex.Message}";
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
- **List patterns:** `Get-Patterns`
- **Filter patterns:** `Get-Patterns | Where-Object { $_.Category -eq 'error' }`
- **Test pattern:** `Test-Pattern <pattern-name> <sample-text>`

## Key Functions

- **Transform:** Format-Count, Group-By, Measure-Frequency, Group-Similar
- **Extract:** Select-RegexMatch, Select-TextBetween, Select-Column
- **Analyze:** Find-Errors, Find-Warnings, Get-BuildError, Group-BuildErrors
- **Present:** Show, Export-ToFile, Get-StreamData
- **Meta:** Find-ProjectTools, Set-Pattern, Get-Patterns, Test-Pattern
- **State:** Save-Project, Load-Project, Get-BrickStore

## Discovery Resources

- `pwsh_mcp_modules://modules` - List loaded modules
- `pwsh_mcp_modules://functions` - All functions from all modules
- `pwsh_mcp_modules://patterns` - Pattern catalog (AgentBricks)
";
    }
}
