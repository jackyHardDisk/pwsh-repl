using System.ComponentModel;
using System.Management.Automation;
using System.Text;
using System.Text.RegularExpressions;
using ModelContextProtocol.Server;
using PowerShellMcpServer.Core;
using System.Linq;

namespace PowerShellMcpServer.Tools;

/// <summary>
/// MCP tool for iterative development workflows with output capture and analysis.
/// Executes scripts, captures stdout/stderr separately, stores in session variables,
/// and returns condensed summary with error/warning counts.
/// </summary>
[McpServerToolType]
public class DevRunTool
{
    private readonly SessionManager _sessionManager;

    public DevRunTool(SessionManager sessionManager)
    {
        _sessionManager = sessionManager ?? throw new ArgumentNullException(nameof(sessionManager));
    }

    [McpServerTool]
    [Description("Iterative development wrapper with output capture. Runs script, stores stdout/stderr in session variables, and returns condensed summary with error/warning counts.")]
    public string DevRun(
        [Description("PowerShell script to execute (optional if name is provided for re-run)")] string? script = null,
        [Description("Name for stored results (creates $env:name_stdout, $env:name_stderr, $env:name)")] string? name = null,
        [Description("Session ID (default: 'default')")] string sessionId = "default",
        [Description("Virtual environment path or conda environment name (optional). Activates the environment before script execution.")] string? environment = null,
        [Description("Initial session state: 'default' (standard cmdlets + current env) or 'create' (minimal blank slate). Default: 'default'")] string initialSessionState = "default",
        [Description("Timeout in seconds (default: 60). Script execution will be terminated if it exceeds this duration.")] int timeoutSeconds = 60)
    {
        var session = _sessionManager.GetOrCreateSession(sessionId, environment, initialSessionState);

        try
        {
            // Re-run capability: if script is empty but name is provided, load saved script
            if (string.IsNullOrWhiteSpace(script) && !string.IsNullOrWhiteSpace(name))
            {
                session.PowerShell.AddScript($"$env:{name}");
                var savedScriptResults = session.PowerShell.Invoke();
                script = savedScriptResults.FirstOrDefault()?.ToString();
                session.PowerShell.Commands.Clear();
                session.PowerShell.Streams.ClearStreams();

                if (string.IsNullOrWhiteSpace(script))
                {
                    return $"Error: No saved script found for name '{name}'.\nRun with script parameter first to save a script.";
                }
            }

            // Validate inputs
            if (string.IsNullOrWhiteSpace(script))
            {
                return "Error: Either 'script' or 'name' (for re-run) must be provided.";
            }

            if (string.IsNullOrWhiteSpace(name))
            {
                // Generate automatic name if not provided
                name = $"temp_{DateTime.Now:HHmmss}";
            }

            // Sanitize name for use as environment variable (replace invalid chars with underscore)
            var safeName = System.Text.RegularExpressions.Regex.Replace(name, @"[^a-zA-Z0-9_]", "_");

            // Environment activation is now handled by SessionManager on session creation
            // No need to activate here

            // Execute script directly (no redirection) to preserve formatted objects with timeout
            session.PowerShell.AddScript(script);

            var invokeTask = Task.Run(() => session.PowerShell.Invoke());
            var timeout = TimeSpan.FromSeconds(timeoutSeconds);

            ICollection<PSObject> results;
            if (invokeTask.Wait(timeout))
            {
                results = invokeTask.Result;
            }
            else
            {
                // Timeout occurred
                session.PowerShell.Stop();
                return $"Error: Script execution timeout after {timeoutSeconds} seconds.\n" +
                       $"The script was terminated. Consider increasing the timeout parameter or optimizing the script.";
            }

            var exitCode = session.PowerShell.HadErrors ? 1 : 0;

            // Capture all output using the same pattern as PwshTool
            var formattedOutput = FormatAllStreams(results, session.PowerShell);

            // Store formatted output and script in environment variables for re-run capability
            var storeScript = $@"
$env:{safeName}_output = @'
{formattedOutput.Replace("'", "''")}
'@
$env:{safeName} = @'
{script.Replace("'", "''")}
'@
$env:{safeName}_timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
";
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();
            session.PowerShell.AddScript(storeScript);
            session.PowerShell.Invoke();

            // Generate summary
            return GenerateSummary(script, safeName, formattedOutput, exitCode);
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

    /// <summary>
    /// Formats all PowerShell streams (output + errors + warnings + verbose + debug + information)
    /// using the same pattern as PwshTool. Handles formatted objects properly.
    /// </summary>
    private static string FormatAllStreams(ICollection<PSObject> results, PowerShell pwsh)
    {
        var output = new StringBuilder();

        // Process output stream (may contain format objects)
        if (results.Count > 0)
        {
            var formatBuffer = new List<PSObject>();

            foreach (var result in results)
            {
                if (IsFormatObject(result))
                {
                    formatBuffer.Add(result);
                }
                else
                {
                    if (formatBuffer.Count > 0)
                    {
                        output.Append(RenderFormatObjects(formatBuffer));
                        formatBuffer.Clear();
                    }

                    if (result?.BaseObject is string str)
                        output.AppendLine(str);
                    else
                        output.AppendLine(result?.ToString() ?? "(null)");
                }
            }

            if (formatBuffer.Count > 0)
            {
                output.Append(RenderFormatObjects(formatBuffer));
            }
        }

        // Append all six streams
        if (pwsh.HadErrors)
        {
            output.AppendLine("\nErrors:");
            foreach (var error in pwsh.Streams.Error)
                output.AppendLine($"  {error}");
        }

        if (pwsh.Streams.Warning.Count > 0)
        {
            output.AppendLine("\nWarnings:");
            foreach (var warning in pwsh.Streams.Warning)
                output.AppendLine($"  {warning}");
        }

        if (pwsh.Streams.Verbose.Count > 0)
        {
            output.AppendLine("\nVerbose:");
            foreach (var verbose in pwsh.Streams.Verbose)
                output.AppendLine($"  {verbose}");
        }

        if (pwsh.Streams.Debug.Count > 0)
        {
            output.AppendLine("\nDebug:");
            foreach (var debug in pwsh.Streams.Debug)
                output.AppendLine($"  {debug}");
        }

        if (pwsh.Streams.Information.Count > 0)
        {
            output.AppendLine("\nInformation:");
            foreach (var info in pwsh.Streams.Information)
                output.AppendLine($"  {info}");
        }

        return output.ToString().TrimEnd();
    }

    private static bool IsFormatObject(PSObject? obj)
    {
        if (obj?.BaseObject == null) return false;
        var typeName = obj.BaseObject.GetType().FullName;
        return typeName != null &&
               typeName.Contains("Microsoft.PowerShell.Commands.Internal.Format");
    }

    private static string RenderFormatObjects(IEnumerable<PSObject> formatObjects)
    {
        try
        {
            using var renderPs = PowerShell.Create();
            renderPs.AddCommand("Out-String")
                    .AddParameter("Stream", false)
                    .AddParameter("Width", 120);

            var renderResults = renderPs.Invoke(formatObjects);
            var sb = new StringBuilder();
            foreach (var item in renderResults)
            {
                if (item != null) sb.Append(item.ToString());
            }
            return sb.ToString();
        }
        catch (Exception ex)
        {
            return $"[Error rendering format objects: {ex.Message}]";
        }
    }

    private static string GenerateSummary(string script, string name, string fullOutput, int exitCode)
    {
        var summary = new StringBuilder();

        // Script info
        var displayScript = script.Length > 50 ? script.Substring(0, 47) + "..." : script;
        summary.AppendLine($"Script: {displayScript}");
        summary.AppendLine($"Exit Code: {exitCode}");
        summary.AppendLine();

        // Analyze output for errors/warnings
        var lines = fullOutput.Split('\n', StringSplitOptions.RemoveEmptyEntries);

        // Extract errors (case-insensitive patterns)
        var errorPattern = new Regex(@"\b(error|exception|failed|failure)\b", RegexOptions.IgnoreCase);
        var errors = lines.Where(line => errorPattern.IsMatch(line)).ToList();
        var uniqueErrors = errors.GroupBy(e => e.Trim())
                                .OrderByDescending(g => g.Count())
                                .Take(5)
                                .ToList();

        // Extract warnings
        var warningPattern = new Regex(@"\bwarning\b", RegexOptions.IgnoreCase);
        var warnings = lines.Where(line => warningPattern.IsMatch(line)).ToList();
        var uniqueWarnings = warnings.GroupBy(w => w.Trim())
                                    .OrderByDescending(g => g.Count())
                                    .Take(5)
                                    .ToList();

        // Summary statistics
        var totalLines = fullOutput.Split('\n', StringSplitOptions.RemoveEmptyEntries).Length;
        summary.AppendLine($"Errors:   {errors.Count,3}  ({uniqueErrors.Count} unique)");
        summary.AppendLine($"Warnings: {warnings.Count,3}  ({uniqueWarnings.Count} unique)");
        summary.AppendLine($"Output:   {totalLines,3} lines");
        summary.AppendLine();

        // Top errors
        if (uniqueErrors.Any())
        {
            summary.AppendLine("Top Errors:");
            foreach (var errorGroup in uniqueErrors)
            {
                var count = errorGroup.Count();
                var message = errorGroup.Key.Trim();
                // Truncate long messages
                if (message.Length > 80)
                    message = message.Substring(0, 77) + "...";
                summary.AppendLine($"    {count,2}x: {message}");
            }
            summary.AppendLine();
        }

        // Top warnings
        if (uniqueWarnings.Any())
        {
            summary.AppendLine("Top Warnings:");
            foreach (var warningGroup in uniqueWarnings)
            {
                var count = warningGroup.Count();
                var message = warningGroup.Key.Trim();
                if (message.Length > 80)
                    message = message.Substring(0, 77) + "...";
                summary.AppendLine($"    {count,2}x: {message}");
            }
            summary.AppendLine();
        }

        // Storage info
        summary.AppendLine($"Stored: $env:{name}_output (formatted with all streams)");
        summary.AppendLine($"Re-run: dev-run(name=\"{name}\")");

        return summary.ToString().TrimEnd();
    }
}
