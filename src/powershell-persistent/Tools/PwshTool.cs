using System.ComponentModel;
using System.Linq;
using System.Management.Automation;
using System.Text;
using ModelContextProtocol.Server;
using PowerShellMcpServer.Core;

namespace PowerShellMcpServer.Tools;

/// <summary>
/// MCP tool for executing PowerShell scripts with persistent state.
/// Named sessions provide isolated PowerShell runspaces with independent variable scopes.
/// </summary>
[McpServerToolType]
public class PwshTool
{
    private readonly SessionManager _sessionManager;

    public PwshTool(SessionManager sessionManager)
    {
        _sessionManager = sessionManager ?? throw new ArgumentNullException(nameof(sessionManager));
    }

    [McpServerTool]
    [Description("Execute PowerShell script with persistent session state. Variables and state persist across calls within the same session.")]
    public string Pwsh(
        [Description("PowerShell script to execute")] string script,
        [Description("Session ID (default: 'default'). Use the same session ID to maintain variables across calls.")] string sessionId = "default")
    {
        var session = _sessionManager.GetOrCreateSession(sessionId);

        try
        {
            session.PowerShell.AddScript(script);
            var results = session.PowerShell.Invoke();

            // Check if results contain PowerShell formatting objects
            bool hasFormattingObjects = results.Any(r =>
                r?.BaseObject?.GetType().FullName?.StartsWith(
                    "Microsoft.PowerShell.Commands.Internal.Format",
                    StringComparison.Ordinal) == true);

            // If formatting objects detected, re-invoke with Out-String to get proper output
            if (hasFormattingObjects)
            {
                session.PowerShell.Commands.Clear();
                session.PowerShell.Streams.ClearStreams();
                session.PowerShell.AddScript(script);
                session.PowerShell.AddCommand("Out-String");
                session.PowerShell.AddParameter("Stream", false); // Return single string, not per-line
                results = session.PowerShell.Invoke();
            }

            return FormatResults(results, session.PowerShell);
        }
        catch (Exception ex)
        {
            return $"Error: {ex.GetType().Name}: {ex.Message}\nStack: {ex.StackTrace}";
        }
        finally
        {
            // Don't check back in - session stays allocated to this sessionId
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();
        }
    }

    private static string FormatResults(ICollection<PSObject> results, PowerShell pwsh)
    {
        var output = new StringBuilder();

        // Format output
        if (results.Count > 0)
        {
            foreach (var result in results)
            {
                if (result?.BaseObject is string str)
                    output.AppendLine(str);
                else
                    output.AppendLine(result?.ToString() ?? "(null)");
            }
        }

        // Append errors if any
        if (pwsh.HadErrors)
        {
            output.AppendLine("\nErrors:");
            foreach (var error in pwsh.Streams.Error)
            {
                output.AppendLine($"  {error}");
            }
        }

        // Append warnings if any
        if (pwsh.Streams.Warning.Count > 0)
        {
            output.AppendLine("\nWarnings:");
            foreach (var warning in pwsh.Streams.Warning)
            {
                output.AppendLine($"  {warning}");
            }
        }

        return output.ToString().TrimEnd();
    }
}
