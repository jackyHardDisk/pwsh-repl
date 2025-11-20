using System.ComponentModel;
using System.Management.Automation;
using System.Text;
using ModelContextProtocol.Server;
using PowerShellMcpServer.Core;

namespace PowerShellMcpServer.Tools;

/// <summary>
///     MCP tool for executing PowerShell scripts with persistent state.
///     Named sessions provide isolated PowerShell runspaces with independent variable
///     scopes.
/// </summary>
[McpServerToolType]
public class PwshTool
{
    private readonly SessionManager _sessionManager;

    public PwshTool(SessionManager sessionManager)
    {
        _sessionManager = sessionManager ??
                          throw new ArgumentNullException(nameof(sessionManager));
    }

    [McpServerTool]
    [Description(
        "Execute PowerShell script with persistent session state. Variables and state persist across calls within the same session.\n\nAuto-loads AgentBricks module with 31 functions: Transform (Format-Count, Group-By, Measure-Frequency, Group-Similar, Group-BuildErrors), Extract (Extract-Regex, Extract-Between, Extract-Column), Analyze (Find-Errors, Find-Warnings, Parse-BuildOutput), Present (Show, Export-ToFile, Get-StreamData, Show-StreamSummary), Meta (Find-ProjectTools, Set-Pattern, Get-Patterns, Test-Pattern, Learn-OutputPattern), State (Save-Project, Load-Project, Get-BrickStore, Export-Environment, Clear-Stored, Set-EnvironmentTee), DevRunCache (Initialize-DevRunCache, Get-CachedStreamData, Clear-DevRunCache, Get-DevRunCacheStats), Script (Add-DevScript, Get-DevScripts, Remove-DevScript, Update-DevScriptMetadata, Invoke-DevScript, Invoke-DevScriptChain), Utility (Invoke-WithTimeout).\n\n48 pre-configured regex patterns: JavaScript/TypeScript (ESLint, TypeScript, Jest, Vite, Webpack, Prettier, Stylelint, Node.js, Biome), Python (Pytest, Mypy, Flake8, Pylint, Black, Ruff, Traceback, Exception, Unittest, Coverage), .NET (MSBuild-Error, MSBuild-Warning, NuGet, NUnit, xUnit, MSTest, Exception, Roslyn, StyleCop, SDK), Build (GCC-Error/Warning, Clang, CMake-Error/Warning, Make, Linker, Ninja, Maven, Gradle, Rustc, Cargo, Go, Docker), PowerShell (PowerShell-Error), Git (Git-Status, Git-Conflict, Git-MergeConflict), CI/CD (GitHub-Actions).\n\nExamples:\n- mcp__powershell-persistent__pwsh(script='npm test 2>&1 | Find-Errors | Format-Count')\n- mcp__powershell-persistent__pwsh(script='git status --short | Extract-Regex Git-Status | Group-By status', sessionId='myproject')\n- mcp__powershell-persistent__pwsh(script='python -m pytest', environment='C:\\\\projects\\\\myapp\\\\venv', sessionId='testing')\n- mcp__powershell-persistent__pwsh(script='Get-Patterns | Where-Object {$_.Category -eq \"lint\"}', sessionId='analysis', timeoutSeconds=30)")]
    public string Pwsh(
        [Description("PowerShell script to execute")]
        string script,
        [Description(
            "Session ID (default: 'default'). Use the same session ID to maintain variables across calls.")]
        string sessionId = "default",
        [Description(
            "Virtual environment path or conda environment name (optional). Activates the environment before script execution.")]
        string? environment = null,
        [Description(
            "Initial session state: 'default' (standard cmdlets + current env) or 'create' (minimal blank slate). Default: 'default'")]
        string initialSessionState = "default",
        [Description(
            "Timeout in seconds (default: 60). Script execution will be terminated if it exceeds this duration.")]
        int timeoutSeconds = 60)
    {
        var session =
            _sessionManager.GetOrCreateSession(sessionId, environment,
                initialSessionState);

        try
        {
            session.PowerShell.AddScript(script);

            // Execute with timeout using async pattern
            var invokeTask = Task.Run(() => session.PowerShell.Invoke());
            var timeout = TimeSpan.FromSeconds(timeoutSeconds);

            if (invokeTask.Wait(timeout))
            {
                var results = invokeTask.Result;
                return FormatResults(results, session.PowerShell);
            }
            else
            {
                // Timeout occurred
                session.PowerShell.Stop();
                return
                    $"Error: Script execution timeout after {timeoutSeconds} seconds.\n" +
                    $"The script was terminated. Consider increasing the timeout parameter or optimizing the script.";
            }
        }
        catch (Exception ex)
        {
            return $"Error: {ex.GetType().Name}: {ex.Message}\nStack: {ex.StackTrace}";
        }
        finally
        {
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();
        }
    }

    private static string FormatResults(ICollection<PSObject> results, PowerShell pwsh)
    {
        var output = new StringBuilder();

        // Process output stream
        if (results.Count > 0)
        {
            // Buffer to hold contiguous format objects (preserves table structure)
            var formatBuffer = new List<PSObject>();

            foreach (var result in results)
                if (IsFormatObject(result))
                {
                    formatBuffer.Add(result);
                }
                else
                {
                    // Flush buffered format objects first (preserves order)
                    if (formatBuffer.Count > 0)
                    {
                        output.Append(RenderFormatObjects(formatBuffer));
                        formatBuffer.Clear();
                    }

                    // Handle normal objects
                    if (result?.BaseObject is string str)
                        output.AppendLine(str);
                    else
                        output.AppendLine(result?.ToString() ?? "(null)");
                }

            // Flush any remaining format objects at the end
            if (formatBuffer.Count > 0)
                output.Append(RenderFormatObjects(formatBuffer));
        }

        // Append errors if any
        if (pwsh.Streams.Error.Count > 0)
        {
            output.AppendLine("\nErrors:");
            foreach (var error in pwsh.Streams.Error) output.AppendLine($"  {error}");
        }

        // Append warnings if any
        if (pwsh.Streams.Warning.Count > 0)
        {
            output.AppendLine("\nWarnings:");
            foreach (var warning in pwsh.Streams.Warning)
                output.AppendLine($"  {warning}");
        }

        // Append verbose messages if any
        if (pwsh.Streams.Verbose.Count > 0)
        {
            output.AppendLine("\nVerbose:");
            foreach (var verbose in pwsh.Streams.Verbose)
                output.AppendLine($"  {verbose}");
        }

        // Append debug messages if any
        if (pwsh.Streams.Debug.Count > 0)
        {
            output.AppendLine("\nDebug:");
            foreach (var debug in pwsh.Streams.Debug) output.AppendLine($"  {debug}");
        }

        // Append information messages if any (includes Write-Host)
        if (pwsh.Streams.Information.Count > 0)
        {
            output.AppendLine("\nInformation:");
            foreach (var info in pwsh.Streams.Information)
                output.AppendLine($"  {info}");
        }

        return output.ToString().TrimEnd();
    }

    /// <summary>
    ///     Detects if an object is a PowerShell Internal Format object.
    ///     These are formatting instructions for the host, not data.
    /// </summary>
    private static bool IsFormatObject(PSObject? obj)
    {
        if (obj?.BaseObject == null) return false;

        var typeName = obj.BaseObject.GetType().FullName;
        return typeName != null &&
               typeName.Contains("Microsoft.PowerShell.Commands.Internal.Format");
    }

    /// <summary>
    ///     Renders Internal.Format objects into a string using a temporary pipeline.
    ///     This avoids re-running the user's script while preserving formatted output.
    /// </summary>
    private static string RenderFormatObjects(IEnumerable<PSObject> formatObjects)
    {
        try
        {
            // Create a lightweight, empty shell just for rendering
            using var renderPs = PowerShell.Create();

            // Add Out-String with parameters for clean output
            renderPs.AddCommand("Out-String")
                .AddParameter("Stream", false) // Single string block per table
                .AddParameter("Width", 120); // Prevent aggressive wrapping

            // Invoke passing the existing format objects as input
            var renderResults = renderPs.Invoke(formatObjects);

            var sb = new StringBuilder();
            foreach (var item in renderResults)
                if (item != null)
                    sb.Append(item);

            return sb.ToString();
        }
        catch (Exception ex)
        {
            return $"[Error rendering format objects: {ex.Message}]";
        }
    }
}