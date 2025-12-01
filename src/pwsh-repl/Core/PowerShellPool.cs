using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO.Pipes;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Channels;

namespace PowerShellMcpServer.pwsh_repl.Core;

/// <summary>
///     Channel-based pool of PowerShell instances for thread-safe async execution.
///     Pattern based on PowerAuger's BackgroundProcessor.
/// </summary>
public class PowerShellPool : IDisposable
{
    private readonly List<PowerShellSession> _instances = new();
    private readonly Channel<PowerShellSession> _pool;
    private readonly int _poolSize;
    private bool _disposed;

    public PowerShellPool(int poolSize = 5)
    {
        Console.Error.WriteLine(
            $"PowerShellPool: Starting initialization with pool size {poolSize}");
        _poolSize = poolSize;
        _pool = Channel.CreateUnbounded<PowerShellSession>();
        Console.Error.WriteLine(
            "PowerShellPool: Channel created, initializing pool...");
        InitializePool();
        Console.Error.WriteLine("PowerShellPool: Initialization complete");
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;
        _pool.Writer.TryComplete();

        foreach (var session in _instances)
            try
            {
                session.Runspace?.Close();
                session.Runspace?.Dispose();
                session.PowerShell?.Dispose();
            }
            catch
            {
                // Suppress disposal errors
            }

        _instances.Clear();
    }

    private void InitializePool()
    {
        // Note: PowerShellPool does not support per-session stdin pipes
        // Each pooled session has its own stdin pipe created in PowerShellSession constructor
        // Pool is designed for stateless execution where stdin is not typically needed

        for (var i = 0; i < _poolSize; i++)
            try
            {
                // Create runspace with default state
                var runspace = RunspaceFactory.CreateRunspace();
                runspace.Open();

                // Create PowerShell instance attached to runspace
                var pwsh = PowerShell.Create();
                pwsh.Runspace = runspace;

                // Skip pre-loading for now - test basic functionality first
                // pwsh.AddScript(@"
                //     Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue
                //     Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue
                // ").Invoke();
                // pwsh.Commands.Clear();
                // pwsh.Streams.ClearStreams();
                var session = new PowerShellSession(pwsh, runspace);
                _instances.Add(session);
                _pool.Writer.TryWrite(session);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(
                    $"Failed to initialize PowerShell session {i}: {ex.Message}");
                throw;
            }
    }

    /// <summary>
    ///     Check out a PowerShell session from the pool.
    /// </summary>
    public async Task<PowerShellSession> CheckOutAsync(CancellationToken ct = default)
    {
        return await _pool.Reader.ReadAsync(ct);
    }

    /// <summary>
    ///     Return a PowerShell session to the pool after use.
    ///     CRITICAL: Clears streams to prevent error accumulation.
    /// </summary>
    public void CheckIn(PowerShellSession session)
    {
        if (session == null || _disposed)
            return;

        // Clear state for reuse (CRITICAL pattern from PowerAuger)
        session.PowerShell.Commands.Clear();
        session.PowerShell.Streams.ClearStreams();

        _pool.Writer.TryWrite(session);
    }

    // Note: PowerShellPool does not support stdin operations
    // Per-session stdin pipes are managed by PowerShellSession and SessionManager
    // This pool is designed for stateless execution where stdin is not needed
}

/// <summary>
///     Wrapper around PowerShell instance and its runspace.
/// </summary>
public class PowerShellSession : IDisposable
{
    public PowerShellSession(PowerShell powerShell, Runspace runspace)
        : this(powerShell, runspace, null)
    {
    }

    public PowerShellSession(PowerShell powerShell, Runspace runspace, AnonymousPipeServerStream? stdinPipe)
    {
        PowerShell = powerShell ?? throw new ArgumentNullException(nameof(powerShell));
        Runspace = runspace ?? throw new ArgumentNullException(nameof(runspace));

        // Use provided stdin pipe or create new one
        // Pipe must exist BEFORE any child processes are spawned to prevent stdin hangs
        StdinPipe = stdinPipe ?? new AnonymousPipeServerStream(PipeDirection.Out, HandleInheritability.Inheritable);

        // Note: We keep the client handle open so writes don't fail with "broken pipe"
        // Child processes will inherit a copy of the handle when they spawn
        // StdinPipe.DisposeLocalCopyOfClientHandle();
    }

    public PowerShell PowerShell { get; }
    public Runspace Runspace { get; }
    public AnonymousPipeServerStream? StdinPipe { get; set; }

    /// <summary>
    ///     Background processes managed by this session.
    ///     Key is process name, value is process info with stdout/stderr buffers.
    /// </summary>
    public ConcurrentDictionary<string, BackgroundProcessInfo> BackgroundProcesses { get; } = new();

    public void Dispose()
    {
        // Dispose background processes first (kill and cleanup)
        foreach (var kvp in BackgroundProcesses)
        {
            try
            {
                kvp.Value.Dispose();
            }
            catch
            {
                // Suppress disposal errors
            }
        }
        BackgroundProcesses.Clear();

        // Dispose in order: StdinPipe, Runspace, PowerShell
        try
        {
            StdinPipe?.Dispose();
            StdinPipe = null;
        }
        catch
        {
            // Suppress disposal errors
        }

        try
        {
            Runspace?.Close();
            Runspace?.Dispose();
        }
        catch
        {
            // Suppress disposal errors
        }

        try
        {
            PowerShell?.Dispose();
        }
        catch
        {
            // Suppress disposal errors
        }
    }
}

/// <summary>
///     Information about a background process managed by C# SessionManager.
///     Captures stdout/stderr via async event handlers for incremental reading.
/// </summary>
public class BackgroundProcessInfo : IDisposable
{
    private readonly object _stdoutLock = new();
    private readonly object _stderrLock = new();
    private bool _disposed;

    public Process? Process { get; set; }
    public StringBuilder StdoutBuffer { get; } = new();
    public StringBuilder StderrBuffer { get; } = new();
    public int LastStdoutPosition { get; set; }
    public int LastStderrPosition { get; set; }
    public DateTime StartTime { get; set; }
    public string Name { get; set; } = string.Empty;
    public string FilePath { get; set; } = string.Empty;
    public string Arguments { get; set; } = string.Empty;
    public string? WorkingDirectory { get; set; }
    public bool StdinClosed { get; set; }

    /// <summary>
    ///     Append to stdout buffer (thread-safe, called from async event handler).
    /// </summary>
    public void AppendStdout(string? data)
    {
        if (data == null) return;
        lock (_stdoutLock)
        {
            StdoutBuffer.AppendLine(data);
        }
    }

    /// <summary>
    ///     Append to stderr buffer (thread-safe, called from async event handler).
    /// </summary>
    public void AppendStderr(string? data)
    {
        if (data == null) return;
        lock (_stderrLock)
        {
            StderrBuffer.AppendLine(data);
        }
    }

    /// <summary>
    ///     Read stdout since last read (incremental) or all stdout.
    /// </summary>
    public string ReadStdout(bool incremental = true)
    {
        lock (_stdoutLock)
        {
            var content = StdoutBuffer.ToString();
            if (incremental)
            {
                var newContent = content.Substring(LastStdoutPosition);
                LastStdoutPosition = content.Length;
                return newContent;
            }
            return content;
        }
    }

    /// <summary>
    ///     Read stderr since last read (incremental) or all stderr.
    /// </summary>
    public string ReadStderr(bool incremental = true)
    {
        lock (_stderrLock)
        {
            var content = StderrBuffer.ToString();
            if (incremental)
            {
                var newContent = content.Substring(LastStderrPosition);
                LastStderrPosition = content.Length;
                return newContent;
            }
            return content;
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;

        try
        {
            if (Process != null && !Process.HasExited)
            {
                Process.Kill();
            }
        }
        catch
        {
            // Suppress kill errors
        }

        try
        {
            Process?.Dispose();
        }
        catch
        {
            // Suppress disposal errors
        }
    }
}

/// <summary>
///     Status information for a background process.
/// </summary>
public record BackgroundProcessStatus(
    string Name,
    bool IsRunning,
    int? ExitCode,
    TimeSpan Runtime,
    string FilePath,
    string Arguments);

internal static class NativeMethods
{
    public const int STD_INPUT_HANDLE = -10;

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetStdHandle(int nStdHandle, IntPtr hHandle);
}