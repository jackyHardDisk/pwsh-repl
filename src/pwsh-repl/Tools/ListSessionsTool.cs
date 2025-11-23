using System.ComponentModel;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Tools;

/// <summary>
///     MCP tool for listing active PowerShell session IDs.
/// </summary>
[McpServerToolType]
public class ListSessionsTool
{
    private readonly SessionManager _sessionManager;

    public ListSessionsTool(SessionManager sessionManager)
    {
        _sessionManager = sessionManager ??
                          throw new ArgumentNullException(nameof(sessionManager));
    }

    [McpServerTool]
    [Description("List active PowerShell session IDs")]
    public string ListSessions()
    {
        var sessionIds = _sessionManager.GetSessionIds().ToList();

        if (!sessionIds.Any())
            return "No active sessions";

        return string.Join("\n", sessionIds);
    }
}
