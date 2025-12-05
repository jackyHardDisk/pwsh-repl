using System.Collections.Concurrent;
using System.Collections.ObjectModel;
using System.Diagnostics;
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
    private readonly ConcurrentDictionary<string, DateTime> _sessionExpiry = new();
    private readonly object _stdinHandleLock = new();
    private readonly object _auditLogLock = new();
    private readonly string? _auditLogPath;
    private Timer? _cleanupTimer;
    private bool _disposed;

    public SessionManager()
    {
        Console.Error.WriteLine("SessionManager: Per-session stdin pipes enabled");

        // Check for audit logging (opt-in via environment variable)
        _auditLogPath = Environment.GetEnvironmentVariable("PWSH_MCP_AUDIT_LOG");
        if (!string.IsNullOrEmpty(_auditLogPath))
        {
            Console.Error.WriteLine($"SessionManager: Audit logging enabled to '{_auditLogPath}'");
            try
            {
                // Ensure directory exists
                var dir = Path.GetDirectoryName(_auditLogPath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                    Directory.CreateDirectory(dir);

                // Write startup marker
                WriteAuditLog("SESSION_MANAGER_START", "default", "Audit logging initialized");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"SessionManager: Failed to initialize audit log: {ex.Message}");
                _auditLogPath = null; // Disable if can't write
            }
        }
    }

    private void WriteAuditLog(string eventType, string sessionId, string content)
    {
        if (string.IsNullOrEmpty(_auditLogPath)) return;

        try
        {
            lock (_auditLogLock)
            {
                var timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                var sanitizedContent = content.Replace("\r", "\\r").Replace("\n", "\\n");
                var logLine = $"[{timestamp}] {eventType} session={sessionId} content=\"{sanitizedContent}\"\n";
                File.AppendAllText(_auditLogPath, logLine);
            }
        }
        catch
        {
            // Silently fail - don't break execution for logging failures
        }
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

        // Create stdin pipe BEFORE any child processes are spawned (environment activation, module loading)
        // Without this, conda/python calls during ActivateEnvironment hang waiting for stdin
        AnonymousPipeServerStream? stdinPipe = null;
        IntPtr originalStdin = IntPtr.Zero;

        if (OperatingSystem.IsWindows())
        {
            stdinPipe = new AnonymousPipeServerStream(PipeDirection.Out, HandleInheritability.Inheritable);
            originalStdin = NativeMethods.GetStdHandle(NativeMethods.STD_INPUT_HANDLE);
            NativeMethods.SetStdHandle(NativeMethods.STD_INPUT_HANDLE,
                stdinPipe.ClientSafePipeHandle.DangerousGetHandle());
        }

        try
        {
            // Activate environment if specified (BEFORE modules)
            if (!string.IsNullOrEmpty(environment)) ActivateEnvironment(pwsh, environment);

            // Pre-load AgentBlocks module (foundation for all core functions)
            LoadModule(pwsh, "AgentBlocks",
                Path.Combine(AppContext.BaseDirectory, "Modules", "AgentBlocks"));

            // Load additional modules from PWSH_MCP_MODULES environment variable
            // (includes LoraxMod, SessionLog, TokenCounter, etc.)
            LoadAdditionalModules(pwsh);

            // Initialize ConcurrentDictionary for DevRun cache (in C# for thread-safety)
            pwsh.AddScript(@"
if (-not $global:DevRunCache) {
    $global:DevRunCache = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
}
if (-not $global:DevRunCacheCounter) {
    $global:DevRunCacheCounter = 0
}
").Invoke();
            pwsh.Commands.Clear();
            pwsh.Streams.ClearStreams();

            return new PowerShellSession(pwsh, runspace, stdinPipe);
        }
        finally
        {
            // Restore original stdin handle
            if (OperatingSystem.IsWindows() && originalStdin != IntPtr.Zero)
            {
                NativeMethods.SetStdHandle(NativeMethods.STD_INPUT_HANDLE, originalStdin);
            }
        }
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
        bool validateAgentBlocks = false)
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

                // Validate AgentBlocks loaded (only for AgentBlocks)
                if (validateAgentBlocks && moduleName == "AgentBlocks")
                {
                    pwsh.AddScript("$global:BrickStore.Patterns.Count");
                    var testResult = pwsh.Invoke();
                    pwsh.Commands.Clear();
                    pwsh.Streams.ClearStreams();

                    if (testResult.Count == 0 || testResult[0] == null ||
                        testResult[0].ToString() == "0")
                    {
                        Console.Error.WriteLine(
                            "WARNING: AgentBlocks module loaded but appears non-functional (no patterns loaded)");
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
        var modulePaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        // 1. Auto-discover modules from default Modules folder
        var defaultModulesPath = Path.Combine(AppContext.BaseDirectory, "Modules");
        if (Directory.Exists(defaultModulesPath))
        {
            Console.Error.WriteLine($"SessionManager: Auto-discovering modules from '{defaultModulesPath}'");
            AddModulesFromFolder(defaultModulesPath, modulePaths);
        }

        // 2. Process PWSH_MCP_MODULES environment variable (supports .psd1 files and folders)
        var modulesEnv = Environment.GetEnvironmentVariable("PWSH_MCP_MODULES");
        if (!string.IsNullOrEmpty(modulesEnv))
        {
            var entries = modulesEnv.Split(';', StringSplitOptions.RemoveEmptyEntries);
            Console.Error.WriteLine($"SessionManager: Processing {entries.Length} PWSH_MCP_MODULES entries");

            foreach (var entry in entries)
            {
                var trimmed = entry.Trim();

                if (File.Exists(trimmed) && trimmed.EndsWith(".psd1", StringComparison.OrdinalIgnoreCase))
                {
                    // Direct .psd1 file
                    var fullPath = Path.GetFullPath(trimmed);
                    modulePaths.Add(fullPath);
                    Console.Error.WriteLine($"SessionManager:   Added module file: {fullPath}");
                }
                else if (Directory.Exists(trimmed))
                {
                    // Folder - scan for .psd1 files
                    Console.Error.WriteLine($"SessionManager:   Scanning folder: {trimmed}");
                    AddModulesFromFolder(trimmed, modulePaths);
                }
                else
                {
                    Console.Error.WriteLine($"SessionManager:   Skipping invalid entry: {trimmed}");
                }
            }
        }

        // 3. Filter out AgentBlocks (loaded separately with validation)
        var AgentBlocksPath = Path.GetFullPath(
            Path.Combine(AppContext.BaseDirectory, "Modules", "AgentBlocks", "AgentBlocks.psd1"));
        if (modulePaths.Remove(AgentBlocksPath))
        {
            Console.Error.WriteLine($"SessionManager: Removed AgentBlocks from additional modules (loaded separately)");
        }

        var result = modulePaths.ToArray();
        Console.Error.WriteLine($"SessionManager: Discovered {result.Length} additional modules after deduplication");
        return result;
    }

    private void AddModulesFromFolder(string folderPath, HashSet<string> modulePaths)
    {
        try
        {
            // Scan for module subdirectories (pattern: Modules/ModuleName/ModuleName.psd1)
            var subdirs = Directory.GetDirectories(folderPath);
            foreach (var subdir in subdirs)
            {
                var moduleName = Path.GetFileName(subdir);
                var manifestPath = Path.Combine(subdir, $"{moduleName}.psd1");

                if (File.Exists(manifestPath))
                {
                    var fullPath = Path.GetFullPath(manifestPath);
                    var isNew = modulePaths.Add(fullPath);
                    if (isNew)
                    {
                        Console.Error.WriteLine($"SessionManager:     Found module: {moduleName} ({fullPath})");
                    }
                    else
                    {
                        Console.Error.WriteLine($"SessionManager:     Skipped duplicate: {moduleName}");
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SessionManager: Failed to scan folder '{folderPath}': {ex.Message}");
        }
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
    public Collection<PSObject> ExecuteScript(PowerShellSession session, string script, string? sessionId = null)
    {
        if (session == null)
            throw new ArgumentNullException(nameof(session));
        if (script == null)
            throw new ArgumentNullException(nameof(script));

        // Audit log the execution attempt
        WriteAuditLog("EXECUTE", sessionId ?? "unknown", script);

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

    /// <summary>
    ///     Get list of active session IDs.
    /// </summary>
    public IEnumerable<string> GetSessionIds()
    {
        return _sessions.Keys.OrderBy(k => k);
    }

    /// <summary>
    ///     Get health information for a specific session.
    /// </summary>
    public SessionHealthInfo GetSessionHealth(string sessionId)
    {
        if (!_sessions.TryGetValue(sessionId, out var session))
            return new SessionHealthInfo(sessionId, false, "NotFound", "NotFound", 0, false, false);

        try
        {
            var runspaceState = session.Runspace?.RunspaceStateInfo.State.ToString() ?? "Disposed";
            var invocationState = session.PowerShell?.InvocationStateInfo.State.ToString() ?? "Disposed";
            var errorCount = session.PowerShell?.Streams.Error.Count ?? -1;
            var stdinAvailable = session.StdinPipe != null;

            // Determine if healthy
            var isHealthy = runspaceState == "Opened" &&
                           (invocationState == "NotStarted" || invocationState == "Completed") &&
                           errorCount >= 0;

            // Determine if recoverable (can be cleared and reused vs needs full removal)
            var isRecoverable = runspaceState == "Opened";

            return new SessionHealthInfo(
                sessionId,
                isHealthy,
                runspaceState,
                invocationState,
                errorCount,
                stdinAvailable,
                isRecoverable);
        }
        catch (Exception ex)
        {
            return new SessionHealthInfo(sessionId, false, "Error", ex.Message, -1, false, false);
        }
    }

    /// <summary>
    ///     Get health information for all sessions.
    /// </summary>
    public IEnumerable<SessionHealthInfo> GetAllSessionHealth()
    {
        return _sessions.Keys.Select(GetSessionHealth).ToList();
    }

    /// <summary>
    ///     Remove all sessions.
    /// </summary>
    public int RemoveAllSessions()
    {
        var count = 0;
        foreach (var sessionId in _sessions.Keys.ToList())
        {
            RemoveSession(sessionId);
            count++;
        }
        return count;
    }

    /// <summary>
    ///     Remove all unhealthy sessions.
    /// </summary>
    public int RemoveUnhealthySessions()
    {
        var count = 0;
        foreach (var health in GetAllSessionHealth().Where(h => !h.IsHealthy))
        {
            RemoveSession(health.SessionId);
            count++;
        }
        return count;
    }

    /// <summary>
    ///     Set TTL for a session. Session will be removed after specified seconds.
    ///     Calling again resets the TTL (extends lifetime).
    /// </summary>
    public void SetSessionTTL(string sessionId, int seconds)
    {
        if (_disposed) return;

        var expiry = DateTime.UtcNow.AddSeconds(seconds);
        _sessionExpiry[sessionId] = expiry;

        // Ensure cleanup timer is running
        EnsureCleanupTimerRunning();

        Console.Error.WriteLine($"SessionManager: Session '{sessionId}' TTL set to {seconds}s (expires {expiry:HH:mm:ss})");
    }

    /// <summary>
    ///     Start the cleanup timer if not already running.
    /// </summary>
    private void EnsureCleanupTimerRunning()
    {
        if (_cleanupTimer != null) return;

        // Check every 30 seconds for expired sessions
        _cleanupTimer = new Timer(_ => CleanupExpiredSessions(), null, TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(30));
        Console.Error.WriteLine("SessionManager: Cleanup timer started (30s interval)");
    }

    /// <summary>
    ///     Remove sessions that have exceeded their TTL.
    /// </summary>
    private void CleanupExpiredSessions()
    {
        if (_disposed) return;

        var now = DateTime.UtcNow;
        var expiredCount = 0;

        foreach (var kvp in _sessionExpiry)
        {
            if (kvp.Value < now)
            {
                if (_sessionExpiry.TryRemove(kvp.Key, out _))
                {
                    RemoveSession(kvp.Key);
                    expiredCount++;
                    Console.Error.WriteLine($"SessionManager: Session '{kvp.Key}' expired and removed");
                }
            }
        }

        // Stop timer if no more sessions to track
        if (_sessionExpiry.IsEmpty && _cleanupTimer != null)
        {
            _cleanupTimer.Dispose();
            _cleanupTimer = null;
            Console.Error.WriteLine("SessionManager: Cleanup timer stopped (no sessions to track)");
        }
    }

    #region Background Process Management

    /// <summary>
    ///     Start a background process in a session.
    /// </summary>
    public BackgroundProcessInfo StartBackgroundProcess(
        string sessionId,
        string name,
        string filePath,
        string[]? args = null,
        string? workingDir = null)
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SessionManager));

        var session = GetOrCreateSession(sessionId);

        if (session.BackgroundProcesses.ContainsKey(name))
            throw new InvalidOperationException($"Background process '{name}' already exists in session '{sessionId}'");

        var psi = new ProcessStartInfo
        {
            FileName = filePath,
            Arguments = args != null ? string.Join(" ", args) : string.Empty,
            WorkingDirectory = workingDir ?? Environment.CurrentDirectory,
            UseShellExecute = false,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        var processInfo = new BackgroundProcessInfo
        {
            Name = name,
            FilePath = filePath,
            Arguments = psi.Arguments,
            WorkingDirectory = psi.WorkingDirectory,
            StartTime = DateTime.Now
        };

        var process = new Process { StartInfo = psi, EnableRaisingEvents = true };

        // Wire up async output handlers
        process.OutputDataReceived += (sender, e) => processInfo.AppendStdout(e.Data);
        process.ErrorDataReceived += (sender, e) => processInfo.AppendStderr(e.Data);

        try
        {
            process.Start();

            // Assign process to session's Job Object for automatic cleanup
            // All child processes will inherit Job membership
            if (session.JobHandle != IntPtr.Zero)
            {
                NativeMethods.AssignProcessToJobObject(session.JobHandle, process.Handle);
            }

            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            processInfo.Process = process;
            session.BackgroundProcesses[name] = processInfo;

            Console.Error.WriteLine(
                $"SessionManager: Started background process '{name}' (PID {process.Id}) in session '{sessionId}'");

            return processInfo;
        }
        catch (Exception ex)
        {
            process.Dispose();
            throw new InvalidOperationException($"Failed to start background process '{name}': {ex.Message}", ex);
        }
    }

    /// <summary>
    ///     Write data to a background process's stdin.
    /// </summary>
    public void WriteToBackgroundProcess(string sessionId, string name, string data)
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SessionManager));

        var processInfo = GetBackgroundProcessInfo(sessionId, name);

        if (processInfo.StdinClosed)
            throw new InvalidOperationException($"Stdin for background process '{name}' has been closed");

        if (processInfo.Process == null || processInfo.Process.HasExited)
            throw new InvalidOperationException($"Background process '{name}' is not running");

        try
        {
            processInfo.Process.StandardInput.Write(data);
            processInfo.Process.StandardInput.Flush();
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to write to background process '{name}': {ex.Message}", ex);
        }
    }

    /// <summary>
    ///     Close stdin for a background process to signal EOF.
    /// </summary>
    public void CloseBackgroundProcessStdin(string sessionId, string name)
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SessionManager));

        var processInfo = GetBackgroundProcessInfo(sessionId, name);

        if (processInfo.StdinClosed)
            return; // Already closed

        try
        {
            processInfo.Process?.StandardInput.Close();
            processInfo.StdinClosed = true;
            Console.Error.WriteLine($"SessionManager: Closed stdin for background process '{name}'");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SessionManager: Error closing stdin for '{name}': {ex.Message}");
        }
    }

    /// <summary>
    ///     Read stdout/stderr from a background process.
    /// </summary>
    public (string stdout, string stderr) ReadBackgroundOutput(string sessionId, string name, bool incremental = true)
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SessionManager));

        var processInfo = GetBackgroundProcessInfo(sessionId, name);

        var stdout = processInfo.ReadStdout(incremental);
        var stderr = processInfo.ReadStderr(incremental);

        return (stdout, stderr);
    }

    /// <summary>
    ///     Get status of a background process.
    /// </summary>
    public BackgroundProcessStatus GetBackgroundProcessStatus(string sessionId, string name)
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SessionManager));

        var processInfo = GetBackgroundProcessInfo(sessionId, name);
        var process = processInfo.Process;

        var isRunning = process != null && !process.HasExited;
        int? exitCode = null;

        if (process != null && process.HasExited)
        {
            try
            {
                exitCode = process.ExitCode;
            }
            catch
            {
                // May fail if process disposed
            }
        }

        var runtime = DateTime.Now - processInfo.StartTime;

        return new BackgroundProcessStatus(
            name,
            isRunning,
            exitCode,
            runtime,
            processInfo.FilePath,
            processInfo.Arguments);
    }

    /// <summary>
    ///     Stop a background process and optionally populate DevRun cache.
    /// </summary>
    public void StopBackgroundProcess(string sessionId, string name, bool populateCache = true)
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SessionManager));

        if (!_sessions.TryGetValue(sessionId, out var session))
            throw new InvalidOperationException($"Session '{sessionId}' does not exist");

        if (!session.BackgroundProcesses.TryRemove(name, out var processInfo))
            throw new InvalidOperationException($"Background process '{name}' not found in session '{sessionId}'");

        // Get all output before disposing
        var stdout = processInfo.ReadStdout(incremental: false);
        var stderr = processInfo.ReadStderr(incremental: false);

        // Dispose (kills process if still running)
        processInfo.Dispose();

        Console.Error.WriteLine($"SessionManager: Stopped background process '{name}' in session '{sessionId}'");

        // Populate DevRun cache if requested (for Get-StreamData compatibility)
        if (populateCache)
        {
            PopulateDevRunCache(session, name, stdout, stderr, processInfo.FilePath, processInfo.Arguments);
        }
    }

    /// <summary>
    ///     Populate DevRun cache with background process output for Get-StreamData compatibility.
    /// </summary>
    private void PopulateDevRunCache(PowerShellSession session, string name, string stdout, string stderr, string filePath, string arguments)
    {
        try
        {
            // Set environment variables that Get-StreamData expects
            var script = $@"
$env:{name}_stdout = @'
{stdout}
'@
$env:{name}_stderr = @'
{stderr}
'@
$streams = @{{
    Error = @({(string.IsNullOrEmpty(stderr) ? "" : "$env:" + name + "_stderr -split \"`n\"")})
    Warning = @()
    Output = @({(string.IsNullOrEmpty(stdout) ? "" : "$env:" + name + "_stdout -split \"`n\"")})
    Verbose = @()
    Debug = @()
    Information = @()
}}
$env:{name}_streams = $streams | ConvertTo-Json -Compress
$env:{name} = '{filePath} {arguments}'
# Invalidate cache to force reload
if ($global:DevRunCache -and $global:DevRunCache.ContainsKey('{name}')) {{
    $null = $global:DevRunCache.TryRemove('{name}', [ref]$null)
}}
";
            session.PowerShell.AddScript(script);
            session.PowerShell.Invoke();
            session.PowerShell.Commands.Clear();
            session.PowerShell.Streams.ClearStreams();

            Console.Error.WriteLine($"SessionManager: Populated DevRun cache for '{name}'");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SessionManager: Failed to populate DevRun cache for '{name}': {ex.Message}");
        }
    }

    /// <summary>
    ///     Get background process info, throwing if not found.
    /// </summary>
    private BackgroundProcessInfo GetBackgroundProcessInfo(string sessionId, string name)
    {
        if (!_sessions.TryGetValue(sessionId, out var session))
            throw new InvalidOperationException($"Session '{sessionId}' does not exist");

        if (!session.BackgroundProcesses.TryGetValue(name, out var processInfo))
            throw new InvalidOperationException($"Background process '{name}' not found in session '{sessionId}'");

        return processInfo;
    }

    /// <summary>
    ///     List all background processes in a session.
    /// </summary>
    public IEnumerable<BackgroundProcessStatus> ListBackgroundProcesses(string sessionId)
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(SessionManager));

        if (!_sessions.TryGetValue(sessionId, out var session))
            return Enumerable.Empty<BackgroundProcessStatus>();

        return session.BackgroundProcesses.Keys
            .Select(name => GetBackgroundProcessStatus(sessionId, name))
            .ToList();
    }

    #endregion
}

/// <summary>
///     Health information for a PowerShell session.
/// </summary>
public record SessionHealthInfo(
    string SessionId,
    bool IsHealthy,
    string RunspaceState,
    string InvocationState,
    int ErrorCount,
    bool StdinAvailable,
    bool IsRecoverable);