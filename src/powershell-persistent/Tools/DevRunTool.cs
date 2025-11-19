using System.ComponentModel;
using System.Management.Automation;
using System.Text;
using System.Text.RegularExpressions;
using System.Text.Json;
using ModelContextProtocol.Server;
using PowerShellMcpServer.Core;
using System.Linq;

namespace PowerShellMcpServer.Tools;

/// <summary>
/// MCP tool for iterative development workflows with output capture and analysis.
/// Executes scripts, captures all PowerShell streams, stores in JSON hashtable,
/// and returns configurable summary with stream frequency analysis.
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
    [Description("Iterative development wrapper with output capture. Runs script, stores all streams in JSON hashtable, and returns configurable summary with stream analysis.\n\nStores: $env:name_streams (JSON with Error/Warning/Verbose/Debug/Information/Output arrays), $env:name_output (formatted text), $env:name (script for re-run). Retrieve with Get-StreamData, analyze with Show-StreamSummary.\n\nToken efficiency: Returns 15-line summary vs 1000+ raw output lines (99% reduction). Full output accessible via pwsh(script='Get-StreamData \"name\" stderr').\n\nExamples:\n- mcp__powershell-persistent__dev_run(script='npm test', name='test')\n- mcp__powershell-persistent__dev_run(script='dotnet build', name='build', sessionId='myproject', streams=['Error', 'Warning', 'Output'])\n- mcp__powershell-persistent__dev_run(script='pytest tests/', name='pytest', environment='planetarium-test', sessionId='testing')\n- mcp__powershell-persistent__dev_run(name='test')  # Re-run saved script\n- mcp__powershell-persistent__dev_run(script='docker build .', name='docker', timeoutSeconds=300)\n\nThen analyze: mcp__powershell-persistent__pwsh(script='Get-StreamData \"test\" stderr | Find-Errors | Group-Similar | Format-Count', sessionId='myproject')")]
    public string DevRun(
        [Description("PowerShell script to execute (optional if name is provided for re-run)")] string? script = null,
        [Description("Name for stored results (creates $env:name_streams JSON hashtable, $env:name_output, $env:name)")] string? name = null,
        [Description("Session ID (default: 'default')")] string sessionId = "default",
        [Description("Virtual environment path or conda environment name (optional). Activates the environment before script execution.")] string? environment = null,
        [Description("Initial session state: 'default' (standard cmdlets + current env) or 'create' (minimal blank slate). Default: 'default'")] string initialSessionState = "default",
        [Description("Timeout in seconds (default: 60). Script execution will be terminated if it exceeds this duration.")] int timeoutSeconds = 60,
        [Description("Streams to show in summary: Error, Warning, Verbose, Debug, Information, Output. Default: Error, Warning")] string[]? streams = null)
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

            // Default streams to Error + Warning if not specified
            var requestedStreams = streams ?? new[] { "Error", "Warning" };

            // Execute script with timeout
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

            // Capture output stream (with format object handling)
            var outputLines = FormatOutputStream(results);

            // Capture all six PowerShell streams
            var streamData = new Dictionary<string, List<string>>
            {
                ["Error"] = session.PowerShell.Streams.Error.Select(e => e.ToString()).ToList(),
                ["Warning"] = session.PowerShell.Streams.Warning.Select(w => w.ToString()).ToList(),
                ["Verbose"] = session.PowerShell.Streams.Verbose.Select(v => v.ToString()).ToList(),
                ["Debug"] = session.PowerShell.Streams.Debug.Select(d => d.ToString()).ToList(),
                ["Information"] = session.PowerShell.Streams.Information.Select(i => i.ToString()).ToList(),
                ["Output"] = outputLines
            };

            // Serialize to JSON for $env:name_streams
            var streamJson = JsonSerializer.Serialize(streamData, new JsonSerializerOptions
            {
                WriteIndented = false
            });

            // Format all streams for backwards-compatible $env:name_output display
            var formattedOutput = FormatAllStreams(outputLines, session.PowerShell);

            // Store in environment variables
            var storeScript = $@"
$env:{safeName}_streams = @'
{streamJson.Replace("'", "''")}
'@
$env:{safeName}_output = @'
{formattedOutput.Replace("'", "''")}
'@
$env:{safeName} = @'
{script}
'@
$env:{safeName}_timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# Invalidate cache for this script (if AgentBricks module is loaded)
if (Get-Command Clear-DevRunCache -ErrorAction SilentlyContinue) {{
    Clear-DevRunCache -Name '{safeName}' -ErrorAction SilentlyContinue
}}

# Register script metadata in global registry (if AgentBricks module is loaded)
if (Get-Command Add-DevScript -ErrorAction SilentlyContinue) {{
    Add-DevScript -Name '{safeName}' -Script $env:{safeName} -ExitCode $LASTEXITCODE -ErrorAction SilentlyContinue
}}
";
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();
            session.PowerShell.AddScript(storeScript);
            session.PowerShell.Invoke();

            // Generate summary for requested streams
            return GenerateSummary(script, safeName, requestedStreams, streamData);
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
    /// Formats output stream, handling format objects properly.
    /// Returns list of output lines for JSON storage.
    /// </summary>
    private static List<string> FormatOutputStream(ICollection<PSObject> results)
    {
        var lines = new List<string>();

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
                        var rendered = RenderFormatObjects(formatBuffer);
                        lines.AddRange(rendered.Split('\n', StringSplitOptions.RemoveEmptyEntries));
                        formatBuffer.Clear();
                    }

                    if (result?.BaseObject is string str)
                        lines.Add(str);
                    else
                        lines.Add(result?.ToString() ?? "(null)");
                }
            }

            if (formatBuffer.Count > 0)
            {
                var rendered = RenderFormatObjects(formatBuffer);
                lines.AddRange(rendered.Split('\n', StringSplitOptions.RemoveEmptyEntries));
            }
        }

        return lines;
    }

    /// <summary>
    /// Formats all streams for display (backwards-compatible format).
    /// </summary>
    private static string FormatAllStreams(List<string> outputLines, PowerShell pwsh)
    {
        var output = new StringBuilder();

        // Output stream
        if (outputLines.Count > 0)
        {
            foreach (var line in outputLines)
                output.AppendLine(line);
        }

        // Error stream
        if (pwsh.Streams.Error.Count > 0)
        {
            output.AppendLine("\nErrors:");
            foreach (var error in pwsh.Streams.Error)
                output.AppendLine($"  {error}");
        }

        // Warning stream
        if (pwsh.Streams.Warning.Count > 0)
        {
            output.AppendLine("\nWarnings:");
            foreach (var warning in pwsh.Streams.Warning)
                output.AppendLine($"  {warning}");
        }

        // Verbose stream
        if (pwsh.Streams.Verbose.Count > 0)
        {
            output.AppendLine("\nVerbose:");
            foreach (var verbose in pwsh.Streams.Verbose)
                output.AppendLine($"  {verbose}");
        }

        // Debug stream
        if (pwsh.Streams.Debug.Count > 0)
        {
            output.AppendLine("\nDebug:");
            foreach (var debug in pwsh.Streams.Debug)
                output.AppendLine($"  {debug}");
        }

        // Information stream
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

    private static string GenerateSummary(string script, string name, string[] requestedStreams, Dictionary<string, List<string>> streamData)
    {
        var summary = new StringBuilder();

        // Script info
        var displayScript = script.Length > 50 ? script.Substring(0, 47) + "..." : script;
        summary.AppendLine($"Script: {displayScript}");
        summary.AppendLine();

        // Show requested streams
        foreach (var streamName in requestedStreams)
        {
            if (!streamData.ContainsKey(streamName)) continue;

            var items = streamData[streamName];
            if (items.Count == 0) continue;

            var unique = items.Distinct().Count();
            summary.AppendLine($"{streamName}s: {items.Count,6}  ({unique} unique)");

            // Frequency analysis (top 5)
            var frequency = items
                .GroupBy(x => x)
                .Select(g => new { Count = g.Count(), Item = g.Key })
                .OrderByDescending(x => x.Count)
                .Take(5)
                .ToList();

            if (frequency.Any())
            {
                summary.AppendLine($"\nTop {streamName}s:");
                foreach (var f in frequency)
                {
                    var message = f.Item.Length > 80 ? f.Item.Substring(0, 77) + "..." : f.Item;
                    summary.AppendLine($"    {f.Count,2}x: {message}");
                }
                summary.AppendLine();
            }
        }

        // Output line count (always show)
        var outputCount = streamData["Output"].Count;
        summary.AppendLine($"Output: {outputCount,6} lines");
        summary.AppendLine();

        // Storage info
        summary.AppendLine($"Stored: $env:{name}_streams (JSON), $env:{name}_output (text)");
        summary.AppendLine($"Re-run: dev-run(name=\"{name}\")");

        return summary.ToString().TrimEnd();
    }
}
