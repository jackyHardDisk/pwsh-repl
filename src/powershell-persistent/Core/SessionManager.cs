using System.Collections.Concurrent;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

namespace PowerShellMcpServer.Core;

/// <summary>
/// Manages named PowerShell sessions with persistent state.
/// Each session has its own dedicated runspace that persists variables across calls.
/// </summary>
public class SessionManager : IDisposable
{
    private readonly ConcurrentDictionary<string, PowerShellSession> _sessions = new();
    private bool _disposed;

    /// <summary>
    /// Get or create a named session.
    /// </summary>
    public PowerShellSession GetOrCreateSession(string sessionId = "default")
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SessionManager));

        return _sessions.GetOrAdd(sessionId, _ => CreateSession(sessionId));
    }

    private PowerShellSession CreateSession(string sessionId)
    {
        Console.Error.WriteLine($"SessionManager: Creating new session '{sessionId}'");

        var runspace = RunspaceFactory.CreateRunspace();
        runspace.Open();

        var pwsh = PowerShell.Create();
        pwsh.Runspace = runspace;

        // Pre-load AgentBricks module
        try
        {
            var modulePath = Path.Combine(AppContext.BaseDirectory, "Modules", "AgentBricks");
            if (Directory.Exists(modulePath))
            {
                pwsh.AddScript($"Import-Module '{modulePath}' -DisableNameChecking -ErrorAction SilentlyContinue");
                pwsh.Invoke();
                pwsh.Commands.Clear();
                pwsh.Streams.ClearStreams();

                // Validate module loaded successfully
                pwsh.AddScript("$global:BrickStore.Patterns.Count");
                var testResult = pwsh.Invoke();
                pwsh.Commands.Clear();
                pwsh.Streams.ClearStreams();

                if (testResult.Count == 0 || testResult[0] == null || testResult[0].ToString() == "0")
                {
                    Console.Error.WriteLine($"WARNING: AgentBricks module loaded but appears non-functional (no patterns loaded)");
                }
                else
                {
                    Console.Error.WriteLine($"SessionManager: Loaded AgentBricks module for session '{sessionId}' ({testResult[0]} patterns)");
                }
            }
            else
            {
                Console.Error.WriteLine($"SessionManager: AgentBricks module not found at '{modulePath}'");
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SessionManager: Failed to load AgentBricks module: {ex.Message}");
        }

        return new PowerShellSession(pwsh, runspace);
    }

    /// <summary>
    /// Clear a session (reset variables but keep the runspace alive).
    /// </summary>
    public void ClearSession(string sessionId)
    {
        if (_sessions.TryGetValue(sessionId, out var session))
        {
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();

            // Reset runspace state by re-creating PowerShell instance
            session.PowerShell.Dispose();
            var newPwsh = PowerShell.Create();
            newPwsh.Runspace = session.Runspace;

            _sessions[sessionId] = new PowerShellSession(newPwsh, session.Runspace);
        }
    }

    /// <summary>
    /// Remove a session entirely.
    /// </summary>
    public void RemoveSession(string sessionId)
    {
        if (_sessions.TryRemove(sessionId, out var session))
        {
            session.Runspace?.Close();
            session.Runspace?.Dispose();
            session.PowerShell?.Dispose();
        }
    }

    /// <summary>
    /// List all active sessions.
    /// </summary>
    public IEnumerable<string> ListSessions()
    {
        return _sessions.Keys.ToList();
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;

        foreach (var kvp in _sessions)
        {
            try
            {
                kvp.Value.Runspace?.Close();
                kvp.Value.Runspace?.Dispose();
                kvp.Value.PowerShell?.Dispose();
            }
            catch
            {
                // Suppress disposal errors
            }
        }

        _sessions.Clear();
    }
}
