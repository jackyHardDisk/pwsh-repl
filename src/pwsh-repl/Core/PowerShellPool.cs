using System.IO.Pipes;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Runtime.InteropServices;
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
    {
        PowerShell = powerShell ?? throw new ArgumentNullException(nameof(powerShell));
        Runspace = runspace ?? throw new ArgumentNullException(nameof(runspace));

        // Create per-session stdin pipe
        // PipeDirection.Out means server writes, client reads
        StdinPipe = new AnonymousPipeServerStream(PipeDirection.Out, HandleInheritability.Inheritable);

        // Note: We keep the client handle open so writes don't fail with "broken pipe"
        // Child processes will inherit a copy of the handle when they spawn
        // StdinPipe.DisposeLocalCopyOfClientHandle();
    }

    public PowerShell PowerShell { get; }
    public Runspace Runspace { get; }
    public AnonymousPipeServerStream? StdinPipe { get; set; }

    public void Dispose()
    {
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

internal static class NativeMethods
{
    public const int STD_INPUT_HANDLE = -10;

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetStdHandle(int nStdHandle, IntPtr hHandle);
}