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
    public PowerShellSession GetOrCreateSession(
        string sessionId = "default",
        string? environment = null,
        string initialSessionState = "default")
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SessionManager));

        // Include environment and iss in cache key
        string cacheKey = sessionId;
        if (!string.IsNullOrEmpty(environment))
            cacheKey = $"{sessionId}:env={environment}";
        if (initialSessionState != "default")
            cacheKey = $"{cacheKey}:iss={initialSessionState}";

        return _sessions.GetOrAdd(cacheKey, _ => CreateSession(sessionId, environment, initialSessionState));
    }

    private PowerShellSession CreateSession(
        string sessionId,
        string? environment = null,
        string initialSessionState = "default")
    {
        Console.Error.WriteLine($"SessionManager: Creating new session '{sessionId}' (iss={initialSessionState})");

        // Create InitialSessionState based on parameter
        InitialSessionState iss = initialSessionState.ToLowerInvariant() switch
        {
            "create" => InitialSessionState.Create(),
            "default" => InitialSessionState.CreateDefault(),
            _ => InitialSessionState.CreateDefault()
        };

        // If using "create", need to set language mode
        if (initialSessionState.ToLowerInvariant() == "create")
        {
            iss.LanguageMode = PSLanguageMode.FullLanguage;
        }

        // Set execution policy to Bypass for default and create modes (Windows only)
        // This allows venv Activate.ps1 scripts to run without user's execution policy blocking
        // JEA mode (future) will NOT set this and use stricter policies
        if (OperatingSystem.IsWindows() && initialSessionState.ToLowerInvariant() != "jea")
        {
            iss.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;
        }

        var runspace = RunspaceFactory.CreateRunspace(iss);
        runspace.Open();

        var pwsh = PowerShell.Create();
        pwsh.Runspace = runspace;

        // Activate environment if specified (BEFORE modules)
        if (!string.IsNullOrEmpty(environment))
        {
            ActivateEnvironment(pwsh, environment);
        }

        // Pre-load AgentBricks module
        LoadModule(pwsh, "AgentBricks", Path.Combine(AppContext.BaseDirectory, "Modules", "AgentBricks"), validateAgentBricks: true);

        // Load additional modules from config
        LoadAdditionalModules(pwsh);

        return new PowerShellSession(pwsh, runspace);
    }

    private void ActivateEnvironment(PowerShell pwsh, string environment)
    {
        try
        {
            // Check if it's a path (venv directory)
            if (Directory.Exists(environment))
            {
                var venvActivate = Path.Combine(environment, "Scripts", "Activate.ps1");
                var scriptsPath = Path.Combine(environment, "Scripts");

                if (File.Exists(venvActivate))
                {
                    // Full venv activation script
                    pwsh.AddScript($". '{venvActivate}'");
                    pwsh.Invoke();
                    Console.Error.WriteLine($"SessionManager: Activated venv via Activate.ps1: '{environment}'");
                }
                else if (Directory.Exists(scriptsPath))
                {
                    // Manual venv activation (PATH + VIRTUAL_ENV)
                    pwsh.AddScript($"$env:Path = '{scriptsPath};' + $env:Path");
                    pwsh.AddScript($"$env:VIRTUAL_ENV = '{environment}'");
                    pwsh.Invoke();
                    Console.Error.WriteLine($"SessionManager: Activated venv via PATH: '{environment}'");
                }
                else
                {
                    Console.Error.WriteLine($"SessionManager: Warning - '{environment}' looks like a path but no Scripts folder found");
                }
            }
            else
            {
                // Assume conda environment name
                pwsh.AddScript($"conda activate {environment}");
                pwsh.Invoke();
                Console.Error.WriteLine($"SessionManager: Activated conda environment: '{environment}'");
            }

            pwsh.Commands.Clear();
            pwsh.Streams.ClearStreams();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SessionManager: Failed to activate environment '{environment}': {ex.Message}");
            pwsh.Commands.Clear();
            pwsh.Streams.ClearStreams();
        }
    }

    private void LoadModule(PowerShell pwsh, string moduleName, string modulePath, bool validateAgentBricks = false)
    {
        try
        {
            if (Directory.Exists(modulePath) || File.Exists(modulePath))
            {
                pwsh.AddScript($"Import-Module '{modulePath}' -DisableNameChecking -ErrorAction SilentlyContinue");
                pwsh.Invoke();
                pwsh.Commands.Clear();
                pwsh.Streams.ClearStreams();

                // Validate AgentBricks loaded (only for AgentBricks)
                if (validateAgentBricks && moduleName == "AgentBricks")
                {
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
                        Console.Error.WriteLine($"SessionManager: Loaded {moduleName} module ({testResult[0]} patterns)");
                    }
                }
                else
                {
                    Console.Error.WriteLine($"SessionManager: Loaded {moduleName} module");
                }
            }
            else
            {
                Console.Error.WriteLine($"SessionManager: {moduleName} module not found at '{modulePath}'");
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SessionManager: Failed to load {moduleName} module: {ex.Message}");
        }
    }

    private void LoadAdditionalModules(PowerShell pwsh)
    {
        var additionalModules = GetAdditionalModulesFromConfig();

        foreach (var modulePath in additionalModules)
        {
            var moduleName = Path.GetFileNameWithoutExtension(modulePath);
            LoadModule(pwsh, moduleName, modulePath);
        }
    }

    private string[] GetAdditionalModulesFromConfig()
    {
        // Read from PWSH_MCP_MODULES environment variable
        var modulesEnv = Environment.GetEnvironmentVariable("PWSH_MCP_MODULES");

        if (string.IsNullOrEmpty(modulesEnv))
            return Array.Empty<string>();

        return modulesEnv
            .Split(';', StringSplitOptions.RemoveEmptyEntries)
            .Select(m => m.Trim())
            .Where(m => File.Exists(m) || Directory.Exists(m))
            .ToArray();
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
