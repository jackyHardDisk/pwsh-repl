using System.Collections.Concurrent;
using System.Collections.ObjectModel;
using System.IO.Pipes;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using Microsoft.PowerShell;

namespace PowerShellMcpServer.pwsh_repl.Core;

/// <summary>
///     Manages named PowerShell sessions with persistent state.
///     Each session has its own dedicated runspace that persists variables across calls.
/// </summary>
public class SessionManager : IDisposable
{
    private readonly ConcurrentDictionary<string, PowerShellSession> _sessions = new();
    private readonly object _stdinHandleLock = new();
    private bool _disposed;

    public SessionManager()
    {
        Console.Error.WriteLine("SessionManager: Per-session stdin pipes enabled");
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;

        foreach (var kvp in _sessions)
            try
            {
                kvp.Value.Dispose();
            }
            catch
            {
                // Suppress disposal errors
            }

        _sessions.Clear();
    }

    /// <summary>
    ///     Get or create a named session.
    /// </summary>
    public PowerShellSession GetOrCreateSession(
        string sessionId = "default",
        string? environment = null,
        string initialSessionState = "default")
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SessionManager));

        // Include environment and iss in cache key
        var cacheKey = sessionId;
        //if (!string.IsNullOrEmpty(environment))
        //  cacheKey = $"{sessionId}:env={environment}";
        if (initialSessionState != "default")
            cacheKey = $"{cacheKey}:iss={initialSessionState}";

        return _sessions.GetOrAdd(cacheKey,
            _ => CreateSession(sessionId, environment, initialSessionState));
    }

    private PowerShellSession CreateSession(
        string sessionId,
        string? environment = null,
        string initialSessionState = "default")
    {
        Console.Error.WriteLine(
            $"SessionManager: Creating new session '{sessionId}' (iss={initialSessionState})");

        // Create InitialSessionState based on parameter
        var iss = initialSessionState.ToLowerInvariant() switch
        {
            "create" => InitialSessionState.Create(),
            "default" => InitialSessionState.CreateDefault(),
            _ => InitialSessionState.CreateDefault()
        };

        // If using "create", need to set language mode
        if (initialSessionState.ToLowerInvariant() == "create")
            iss.LanguageMode = PSLanguageMode.FullLanguage;

        // Set execution policy to Bypass for default and create modes (Windows only)
        // This allows venv Activate.ps1 scripts to run without user's execution policy blocking
        // JEA mode (future) will NOT set this and use stricter policies
        if (OperatingSystem.IsWindows() &&
            initialSessionState.ToLowerInvariant() != "jea")
            iss.ExecutionPolicy = ExecutionPolicy.Bypass;

        var runspace = RunspaceFactory.CreateRunspace(iss);
        runspace.Open();

        var pwsh = PowerShell.Create();
        pwsh.Runspace = runspace;

        // Note: stdin handle is closed at Windows API level in Program.cs
        // Child processes inherit INVALID_HANDLE_VALUE for stdin, preventing hangs

        // Activate environment if specified (BEFORE modules)
        if (!string.IsNullOrEmpty(environment)) ActivateEnvironment(pwsh, environment);

        // Pre-load AgentBricks module
        LoadModule(pwsh, "AgentBricks",
            Path.Combine(AppContext.BaseDirectory, "Modules", "AgentBricks"), true);

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
                    Console.Error.WriteLine(
                        $"SessionManager: Activated venv via Activate.ps1: '{environment}'");
                }
                else if (Directory.Exists(scriptsPath))
                {
                    // Manual venv activation (PATH + VIRTUAL_ENV)
                    pwsh.AddScript($"$env:Path = '{scriptsPath};' + $env:Path");
                    pwsh.AddScript($"$env:VIRTUAL_ENV = '{environment}'");
                    pwsh.Invoke();
                    Console.Error.WriteLine(
                        $"SessionManager: Activated venv via PATH: '{environment}'");
                }
                else
                {
                    Console.Error.WriteLine(
                        $"SessionManager: Warning - '{environment}' looks like a path but no Scripts folder found");
                }
            }
            else
            {
                // Assume conda environment name - resolve to path and prepend to PATH
                pwsh.AddScript(
                    $"conda info --envs --json | ConvertFrom-Json | Select-Object -ExpandProperty envs | Where-Object {{ $_ -like '*{environment}' }}");
                var condaPathResult = pwsh.Invoke();
                pwsh.Commands.Clear();

                if (condaPathResult.Count > 0 && condaPathResult[0] != null)
                {
                    var envPath = condaPathResult[0].ToString();

                    if (Directory.Exists(envPath))
                    {
                        // Prepend conda environment root to PATH
                        pwsh.AddScript($"$env:Path = '{envPath};' + $env:Path");
                        pwsh.Invoke();
                        pwsh.Commands.Clear();

                        Console.Error.WriteLine(
                            $"SessionManager: Activated conda environment '{environment}' via PATH: {envPath}");
                    }
                    else
                    {
                        Console.Error.WriteLine(
                            $"SessionManager: Warning - conda environment path '{envPath}' does not exist");
                    }
                }
                else
                {
                    Console.Error.WriteLine(
                        $"SessionManager: Warning - conda environment '{environment}' not found");
                }
            }

            pwsh.Commands.Clear();
            pwsh.Streams.ClearStreams();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(
                $"SessionManager: Failed to activate environment '{environment}': {ex.Message}");
            pwsh.Commands.Clear();
            pwsh.Streams.ClearStreams();
        }
    }


    private void LoadModule(PowerShell pwsh, string moduleName, string modulePath,
        bool validateAgentBricks = false)
    {
        try
        {
            if (Directory.Exists(modulePath) || File.Exists(modulePath))
            {
                pwsh.AddScript(
                    $"Import-Module '{modulePath}' -DisableNameChecking -ErrorAction SilentlyContinue");
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

                    if (testResult.Count == 0 || testResult[0] == null ||
                        testResult[0].ToString() == "0")
                    {
                        Console.Error.WriteLine(
                            "WARNING: AgentBricks module loaded but appears non-functional (no patterns loaded)");
                    }
                    else
                    {
                        Console.Error.WriteLine(
                            $"SessionManager: Loaded {moduleName} module ({testResult[0]} patterns)");
                    }
                }
                else
                {
                    Console.Error.WriteLine(
                        $"SessionManager: Loaded {moduleName} module");
                }
            }
            else
            {
                Console.Error.WriteLine(
                    $"SessionManager: {moduleName} module not found at '{modulePath}'");
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(
                $"SessionManager: Failed to load {moduleName} module: {ex.Message}");
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
    ///     Clear a session (reset variables but keep the runspace alive).
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
    ///     Remove a session entirely.
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
    ///     List all active sessions.
    /// </summary>
    public IEnumerable<string> ListSessions()
    {
        return _sessions.Keys.ToList();
    }

    /// <summary>
    ///     Execute a script in a session with stdin handle swapping.
    ///     This method is thread-safe and ensures the correct stdin handle is active during execution.
    /// </summary>
    public Collection<PSObject> ExecuteScript(PowerShellSession session, string script)
    {
        if (session == null)
            throw new ArgumentNullException(nameof(session));
        if (script == null)
            throw new ArgumentNullException(nameof(script));

        lock (_stdinHandleLock)
        {
            IntPtr originalStdin = IntPtr.Zero;

            try
            {
                // Windows-only: Save original stdin handle and swap to session-specific stdin
                if (OperatingSystem.IsWindows() && session.StdinPipe != null)
                {
                    originalStdin = NativeMethods.GetStdHandle(NativeMethods.STD_INPUT_HANDLE);
                    var sessionStdinHandle = session.StdinPipe.ClientSafePipeHandle.DangerousGetHandle();
                    NativeMethods.SetStdHandle(NativeMethods.STD_INPUT_HANDLE, sessionStdinHandle);
                }

                // Execute the script
                session.PowerShell.AddScript(script);
                var results = session.PowerShell.Invoke();

                // Clear commands for next execution
                session.PowerShell.Commands.Clear();

                return results;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"SessionManager: ExecuteScript failed: {ex.Message}");
                throw;
            }
            finally
            {
                // Windows-only: Restore original stdin handle
                if (OperatingSystem.IsWindows() && originalStdin != IntPtr.Zero)
                {
                    NativeMethods.SetStdHandle(NativeMethods.STD_INPUT_HANDLE, originalStdin);
                }
            }
        }
    }

    /// <summary>
    ///     Write data to a session-specific stdin pipe.
    /// </summary>
    public void WriteToSessionStdin(string sessionId, string data)
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SessionManager));

        if (!_sessions.TryGetValue(sessionId, out var session))
            throw new InvalidOperationException($"Session '{sessionId}' does not exist");

        if (session.StdinPipe == null)
            throw new ObjectDisposedException($"Session '{sessionId}' stdin pipe has been closed");

        try
        {
            using var writer = new StreamWriter(session.StdinPipe, leaveOpen: true)
            {
                AutoFlush = true
            };

            // Write data - it will be buffered in the pipe until a child process reads it
            writer.Write(data);
            writer.Flush();

            Console.Error.WriteLine($"SessionManager: Wrote {data.Length} characters to session '{sessionId}' stdin (buffered)");
        }
        catch (IOException ex) when (ex.Message.Contains("pipe"))
        {
            // Pipe error - likely no reader or pipe is broken
            Console.Error.WriteLine($"SessionManager: Pipe error writing to session '{sessionId}': {ex.Message}");
            throw new InvalidOperationException($"Cannot write to stdin pipe for session '{sessionId}': {ex.Message}", ex);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SessionManager: Failed to write to session '{sessionId}' stdin: {ex.Message}");
            throw;
        }
    }

    /// <summary>
    ///     Write data to the stdin pipe (legacy global method - deprecated).
    /// </summary>
    [Obsolete("Use WriteToSessionStdin instead")]
    public void WriteToStdin(string data)
    {
        // Legacy method - writes to default session for backwards compatibility
        WriteToSessionStdin("default", data);
    }

    /// <summary>
    ///     Close the stdin pipe for a specific session to signal EOF.
    /// </summary>
    public void CloseSessionStdin(string sessionId)
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SessionManager));

        if (!_sessions.TryGetValue(sessionId, out var session))
            throw new InvalidOperationException($"Session '{sessionId}' does not exist");

        try
        {
            session.StdinPipe?.Dispose();
            session.StdinPipe = null;
            Console.Error.WriteLine($"SessionManager: Stdin closed for session '{sessionId}'");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SessionManager: Failed to close stdin for session '{sessionId}': {ex.Message}");
            throw;
        }
    }

    /// <summary>
    ///     Close the stdin pipe write end to signal EOF (legacy global method - deprecated).
    /// </summary>
    [Obsolete("Use CloseSessionStdin instead")]
    public void CloseStdin()
    {
        // Legacy method - closes default session stdin for backwards compatibility
        CloseSessionStdin("default");
    }
}