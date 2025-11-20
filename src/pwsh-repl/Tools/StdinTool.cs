using System.ComponentModel;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Tools;

[McpServerToolType]
public class StdinTool
{
    private readonly SessionManager _sessionManager;

    public StdinTool(SessionManager sessionManager)
    {
        _sessionManager = sessionManager;
    }

    [McpServerTool]
    [Description("Write data to stdin pipe or close it to signal EOF")]
    public string Stdin(
        [Description("Data to write to stdin (optional)")]
        string? data = null,
        [Description("Close the write end to signal EOF")]
        bool close = false,
        [Description("Session ID to target (default: 'default')")]
        string sessionId = "default")
    {
        // Ensure session exists before attempting stdin operations
        _sessionManager.GetOrCreateSession(sessionId);

        if (close)
        {
            _sessionManager.CloseSessionStdin(sessionId);
            return $"Stdin write end closed for session '{sessionId}' (EOF signaled)";
        }

        if (!string.IsNullOrEmpty(data))
        {
            _sessionManager.WriteToSessionStdin(sessionId, data);
            return $"Wrote {data.Length} characters to session '{sessionId}' stdin";
        }

        return "No action taken (specify data or close=true)";
    }
}