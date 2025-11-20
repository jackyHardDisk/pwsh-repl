using System.ComponentModel;
using System.Management.Automation;
using System.Text;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Tools;

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
        "Execute PowerShell with persistent sessions. Modules auto-load from PWSH_MCP_MODULES (default: AgentBricks). Use Get-Command or pwsh_mcp_modules:// resources for discovery.")]
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
            // Execute with timeout using async pattern
            // ExecuteScript handles stdin swapping and command cleanup
            var invokeTask = Task.Run(() => _sessionManager.ExecuteScript(session, script));
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