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

        // Create Job Object for this session - all child processes will be assigned to it
        // When session disposes, closing the Job kills all processes atomically
        JobHandle = NativeMethods.CreateKillOnCloseJob($"PwshSession_{Guid.NewGuid():N}");

        // Note: We keep the client handle open so writes don't fail with "broken pipe"
        // Child processes will inherit a copy of the handle when they spawn
        // StdinPipe.DisposeLocalCopyOfClientHandle();
    }

    public PowerShell PowerShell { get; }
    public Runspace Runspace { get; }
    public AnonymousPipeServerStream? StdinPipe { get; set; }

    /// <summary>
    ///     Job Object handle for this session. All spawned processes are assigned to this Job.
    ///     Closing the handle kills all processes in the Job atomically.
    /// </summary>
    public IntPtr JobHandle { get; private set; }

    /// <summary>
    ///     Background processes managed by this session.
    ///     Key is process name, value is process info with stdout/stderr buffers.
    /// </summary>
    public ConcurrentDictionary<string, BackgroundProcessInfo> BackgroundProcesses { get; } = new();

    public void Dispose()
    {
        // Close Job Object first - this kills ALL processes in the Job atomically
        // No need to manually kill individual background processes
        if (JobHandle != IntPtr.Zero)
        {
            try
            {
                NativeMethods.CloseHandle(JobHandle);
                JobHandle = IntPtr.Zero;
            }
            catch
            {
                // Suppress disposal errors
            }
        }

        // Clear background process tracking (processes already killed by Job closure)
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

    /// <summary>
    ///     Terminate all processes in this session's Job Object.
    ///     Use this for timeout cleanup without disposing the session.
    /// </summary>
    public void TerminateJobProcesses()
    {
        if (JobHandle != IntPtr.Zero)
        {
            NativeMethods.TerminateJobObject(JobHandle, 1);
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
                var pid = Process.Id;

                // Kill entire process tree using taskkill /T /F
                // This ensures child processes (python, node, etc.) are also terminated
                // Without this, child processes would be orphaned and continue running
                try
                {
                    var killProcess = new Process
                    {
                        StartInfo = new ProcessStartInfo
                        {
                            FileName = "taskkill",
                            Arguments = $"/PID {pid} /T /F",
                            UseShellExecute = false,
                            CreateNoWindow = true,
                            RedirectStandardOutput = true,
                            RedirectStandardError = true
                        }
                    };
                    killProcess.Start();
                    killProcess.WaitForExit(5000); // 5 second timeout
                    killProcess.Dispose();
                }
                catch
                {
                    // Fallback to regular Kill() if taskkill fails
                    try
                    {
                        Process.Kill();
                    }
                    catch
                    {
                        // Suppress fallback kill errors
                    }
                }
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

    // Process tree enumeration APIs for kill-on-timeout
    private const uint TH32CS_SNAPPROCESS = 0x00000002;

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr CreateToolhelp32Snapshot(uint dwFlags, uint th32ProcessID);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool Process32First(IntPtr hSnapshot, ref PROCESSENTRY32 lppe);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool Process32Next(IntPtr hSnapshot, ref PROCESSENTRY32 lppe);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    private struct PROCESSENTRY32
    {
        public uint dwSize;
        public uint cntUsage;
        public uint th32ProcessID;
        public IntPtr th32DefaultHeapID;
        public uint th32ModuleID;
        public uint cntThreads;
        public uint th32ParentProcessID;
        public int pcPriClassBase;
        public uint dwFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string szExeFile;
    }

    /// <summary>
    ///     Kill a process and all its descendants recursively.
    ///     Used for timeout cleanup to ensure child processes don't become orphans.
    /// </summary>
    public static void KillProcessTree(int parentPid)
    {
        // First, find and kill all children recursively
        var snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if (snapshot == IntPtr.Zero || snapshot == new IntPtr(-1))
            return;

        try
        {
            var entry = new PROCESSENTRY32 { dwSize = (uint)Marshal.SizeOf<PROCESSENTRY32>() };

            if (Process32First(snapshot, ref entry))
            {
                do
                {
                    if (entry.th32ParentProcessID == (uint)parentPid)
                    {
                        // Recursively kill grandchildren first
                        KillProcessTree((int)entry.th32ProcessID);

                        // Then kill this child
                        try
                        {
                            var childProcess = Process.GetProcessById((int)entry.th32ProcessID);
                            if (!childProcess.HasExited)
                            {
                                childProcess.Kill();
                                childProcess.WaitForExit(1000);
                            }
                            childProcess.Dispose();
                        }
                        catch
                        {
                            // Process may have already exited
                        }
                    }
                } while (Process32Next(snapshot, ref entry));
            }
        }
        finally
        {
            CloseHandle(snapshot);
        }

        // Finally, kill the parent process itself
        try
        {
            var parentProcess = Process.GetProcessById(parentPid);
            if (!parentProcess.HasExited)
            {
                parentProcess.Kill();
                parentProcess.WaitForExit(1000);
            }
            parentProcess.Dispose();
        }
        catch
        {
            // Process may have already exited
        }
    }

    /// <summary>
    ///     Get all child process IDs for a given parent PID.
    ///     Useful for taking a snapshot before execution to compare after timeout.
    /// </summary>
    public static List<int> GetChildProcessIds(int parentPid)
    {
        var children = new List<int>();

        var snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if (snapshot == IntPtr.Zero || snapshot == new IntPtr(-1))
            return children;

        try
        {
            var entry = new PROCESSENTRY32 { dwSize = (uint)Marshal.SizeOf<PROCESSENTRY32>() };

            if (Process32First(snapshot, ref entry))
            {
                do
                {
                    if (entry.th32ParentProcessID == (uint)parentPid)
                    {
                        children.Add((int)entry.th32ProcessID);
                        // Also get grandchildren
                        children.AddRange(GetChildProcessIds((int)entry.th32ProcessID));
                    }
                } while (Process32Next(snapshot, ref entry));
            }
        }
        finally
        {
            CloseHandle(snapshot);
        }

        return children;
    }

    #region Job Object APIs

    // Job Object constants
    public const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000;

    // Job Object information classes
    private const int JobObjectExtendedLimitInformation = 9;

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string? lpName);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool AssignProcessToJobObject(IntPtr hJob, IntPtr hProcess);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool TerminateJobObject(IntPtr hJob, uint uExitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetInformationJobObject(
        IntPtr hJob,
        int jobObjectInfoClass,
        ref JOBOBJECT_EXTENDED_LIMIT_INFORMATION lpJobObjectInfo,
        int cbJobObjectInfoLength);

    [StructLayout(LayoutKind.Sequential)]
    public struct IO_COUNTERS
    {
        public ulong ReadOperationCount;
        public ulong WriteOperationCount;
        public ulong OtherOperationCount;
        public ulong ReadTransferCount;
        public ulong WriteTransferCount;
        public ulong OtherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct JOBOBJECT_BASIC_LIMIT_INFORMATION
    {
        public long PerProcessUserTimeLimit;
        public long PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize;
        public UIntPtr MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint PriorityClass;
        public uint SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION
    {
        public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
        public IO_COUNTERS IoInfo;
        public UIntPtr ProcessMemoryLimit;
        public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed;
        public UIntPtr PeakJobMemoryUsed;
    }

    /// <summary>
    ///     Create a Job Object configured to kill all processes when closed.
    ///     Returns IntPtr.Zero on failure.
    /// </summary>
    public static IntPtr CreateKillOnCloseJob(string? name = null)
    {
        var job = CreateJobObject(IntPtr.Zero, name);
        if (job == IntPtr.Zero)
            return IntPtr.Zero;

        // Configure job to kill all processes when the job handle is closed
        var info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION
        {
            BasicLimitInformation = new JOBOBJECT_BASIC_LIMIT_INFORMATION
            {
                LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            }
        };

        if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation,
                ref info, Marshal.SizeOf<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>()))
        {
            CloseHandle(job);
            return IntPtr.Zero;
        }

        return job;
    }

    #endregion
}