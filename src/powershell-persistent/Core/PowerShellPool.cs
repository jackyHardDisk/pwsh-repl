using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading.Channels;

namespace PowerShellMcpServer.Core;

/// <summary>
/// Channel-based pool of PowerShell instances for thread-safe async execution.
/// Pattern based on PowerAuger's BackgroundProcessor.
/// </summary>
public class PowerShellPool : IDisposable
{
    private readonly Channel<PowerShellSession> _pool;
    private readonly List<PowerShellSession> _instances = new();
    private readonly int _poolSize;
    private bool _disposed;

    public PowerShellPool(int poolSize = 5)
    {
        Console.Error.WriteLine($"PowerShellPool: Starting initialization with pool size {poolSize}");
        _poolSize = poolSize;
        _pool = Channel.CreateUnbounded<PowerShellSession>();
        Console.Error.WriteLine("PowerShellPool: Channel created, initializing pool...");
        InitializePool();
        Console.Error.WriteLine("PowerShellPool: Initialization complete");
    }

    private void InitializePool()
    {
        for (int i = 0; i < _poolSize; i++)
        {
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
                Console.Error.WriteLine($"Failed to initialize PowerShell session {i}: {ex.Message}");
                throw;
            }
        }
    }

    /// <summary>
    /// Check out a PowerShell session from the pool.
    /// </summary>
    public async Task<PowerShellSession> CheckOutAsync(CancellationToken ct = default)
    {
        return await _pool.Reader.ReadAsync(ct);
    }

    /// <summary>
    /// Return a PowerShell session to the pool after use.
    /// CRITICAL: Clears streams to prevent error accumulation.
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

    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;
        _pool.Writer.TryComplete();

        foreach (var session in _instances)
        {
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
        }

        _instances.Clear();
    }
}

/// <summary>
/// Wrapper around PowerShell instance and its runspace.
/// </summary>
public class PowerShellSession
{
    public PowerShell PowerShell { get; }
    public Runspace Runspace { get; }

    public PowerShellSession(PowerShell powerShell, Runspace runspace)
    {
        PowerShell = powerShell ?? throw new ArgumentNullException(nameof(powerShell));
        Runspace = runspace ?? throw new ArgumentNullException(nameof(runspace));
    }
}
