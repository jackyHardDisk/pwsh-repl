// Copyright (c) 2025 jackyHardDisk. Licensed under the MIT License.

using System.ComponentModel;
using System.Text;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Tools;

/// <summary>
///     MCP tool for listing active PowerShell session IDs with optional health checks and cleanup.
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
    public string ListSessions(
        [Description("Include health diagnostics for each session (runspace state, error count, etc.)")]
        bool getSessionHealth = false,
        [Description("Kill all sessions (they will be recreated on next use)")]
        bool killAllSessions = false,
        [Description("Kill only unhealthy sessions (broken runspace, failed state, etc.)")]
        bool killUnhealthy = false)
    {
        var sb = new StringBuilder();

        // Handle kill operations first
        if (killAllSessions)
        {
            var count = _sessionManager.RemoveAllSessions();
            sb.AppendLine($"Killed {count} session(s)");
            return sb.ToString().TrimEnd();
        }

        if (killUnhealthy)
        {
            var count = _sessionManager.RemoveUnhealthySessions();
            sb.AppendLine($"Killed {count} unhealthy session(s)");
            sb.AppendLine();
            // Fall through to show remaining sessions
        }

        var sessionIds = _sessionManager.GetSessionIds().ToList();

        if (!sessionIds.Any())
        {
            if (sb.Length > 0)
                sb.AppendLine("No remaining sessions");
            else
                return "No active sessions";
            return sb.ToString().TrimEnd();
        }

        if (getSessionHealth)
        {
            // Detailed health output
            var healthInfos = _sessionManager.GetAllSessionHealth().ToList();
            var healthy = healthInfos.Count(h => h.IsHealthy);
            var unhealthy = healthInfos.Count - healthy;

            sb.AppendLine($"Sessions: {healthInfos.Count} ({healthy} healthy, {unhealthy} unhealthy)");
            sb.AppendLine();

            foreach (var health in healthInfos)
            {
                var status = health.IsHealthy ? "[OK]" : "[UNHEALTHY]";
                sb.AppendLine($"{status} {health.SessionId}");
                sb.AppendLine($"    Runspace: {health.RunspaceState}");
                sb.AppendLine($"    Invocation: {health.InvocationState}");
                sb.AppendLine($"    Errors: {health.ErrorCount}");
                if (!health.IsHealthy)
                    sb.AppendLine($"    Recoverable: {health.IsRecoverable}");
            }
        }
        else
        {
            // Simple list
            foreach (var id in sessionIds)
                sb.AppendLine(id);
        }

        return sb.ToString().TrimEnd();
    }
}
