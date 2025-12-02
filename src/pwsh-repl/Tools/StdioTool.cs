using System.ComponentModel;
using System.Text;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Tools;

[McpServerToolType]
public class StdioTool
{
    private readonly SessionManager _sessionManager;

    public StdioTool(SessionManager sessionManager)
    {
        _sessionManager = sessionManager;
    }

    [McpServerTool]
    [Description("Interact with background process stdio or session stdin pipe")]
    public string Stdio(
        [Description("Background process name. If provided, interacts with that process. If omitted, writes to session stdin pipe.")]
        string? name = null,
        [Description("Data to write to stdin (optional)")]
        string? data = null,
        [Description("Close stdin to signal EOF")]
        bool close = false,
        [Description("Read and return stdout/stderr output (only for background processes, default: true)")]
        bool readOutput = true,
        [Description("Session ID (default: 'default')")]
        string sessionId = "default")
    {
        // If background process name specified, interact with that process
        if (!string.IsNullOrEmpty(name))
        {
            return HandleBackgroundProcess(sessionId, name, data, close, readOutput);
        }

        // Otherwise, write to session stdin pipe (legacy behavior)
        _sessionManager.GetOrCreateSession(sessionId);

        if (close)
        {
            _sessionManager.CloseSessionStdin(sessionId);
            return $"Closed session '{sessionId}' stdin pipe (EOF signaled)";
        }

        if (!string.IsNullOrEmpty(data))
        {
            _sessionManager.WriteToSessionStdin(sessionId, data);
            return $"Wrote {data.Length} chars to session '{sessionId}' stdin pipe";
        }

        return "No action (specify name for background process, or data/close for session stdin)";
    }

    /// <summary>
    ///     Handle background process stdio operations via SessionManager.
    /// </summary>
    private string HandleBackgroundProcess(string sessionId, string name, string? data, bool close, bool readOutput)
    {
        var result = new StringBuilder();

        try
        {
            // Write data if provided
            if (!string.IsNullOrEmpty(data))
            {
                _sessionManager.WriteToBackgroundProcess(sessionId, name, data);
                result.AppendLine($"Wrote {data.Length} chars to '{name}' stdin");
            }

            // Close stdin if requested
            if (close)
            {
                _sessionManager.CloseBackgroundProcessStdin(sessionId, name);
                result.AppendLine($"Closed '{name}' stdin (EOF)");
            }

            // Read output if requested
            if (readOutput)
            {
                // Small delay to let async output handlers catch up
                Thread.Sleep(100);

                var (stdout, stderr) = _sessionManager.ReadBackgroundOutput(sessionId, name, incremental: true);

                if (!string.IsNullOrEmpty(stdout))
                {
                    result.AppendLine();
                    result.AppendLine("=== stdout ===");
                    result.Append(stdout);
                }

                if (!string.IsNullOrEmpty(stderr))
                {
                    result.AppendLine();
                    result.AppendLine("=== stderr ===");
                    result.Append(stderr);
                }
            }

            // If no action was taken, just return status
            if (result.Length == 0)
            {
                var status = _sessionManager.GetBackgroundProcessStatus(sessionId, name);
                return $"Background process '{name}': {(status.IsRunning ? "running" : "stopped")} (runtime: {status.Runtime:hh\\:mm\\:ss})";
            }

            return result.ToString().TrimEnd();
        }
        catch (InvalidOperationException ex)
        {
            return $"Error: {ex.Message}";
        }
        catch (Exception ex)
        {
            return $"Error with background process '{name}': {ex.Message}";
        }
    }
}
