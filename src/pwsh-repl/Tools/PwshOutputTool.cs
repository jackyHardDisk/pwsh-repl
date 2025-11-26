using System.Collections.Concurrent;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Text.RegularExpressions;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Tools;

/// <summary>
///     MCP tool for retrieving output from background PowerShell processes.
///     Auto-finalizes to DevRun cache when process completes.
/// </summary>
[McpServerToolType]
public class PwshOutputTool
{
    private readonly SessionManager _sessionManager;

    // Offset tracking per background process (stdout and stderr separate)
    private static readonly ConcurrentDictionary<string, long> _stdoutOffsets = new();
    private static readonly ConcurrentDictionary<string, long> _stderrOffsets = new();

    public PwshOutputTool(SessionManager sessionManager)
    {
        _sessionManager = sessionManager ??
                          throw new ArgumentNullException(nameof(sessionManager));
    }

    [McpServerTool]
    [Description(
        "Retrieve output from background PowerShell process. Auto-finalizes to cached results when complete.")]
    public string PwshOutput(
        [Description("Name of the background process")]
        string name,
        [Description("Optional regex pattern to filter output lines")]
        string? filter = null,
        [Description("Session ID (default: 'default')")]
        string sessionId = "default")
    {
        var session = _sessionManager.GetOrCreateSession(sessionId);

        try
        {
            // Check if background process exists
            var processInfo = GetBackgroundProcess(session, name);

            if (!processInfo.Exists)
            {
                var activeProcesses = GetActiveBackgroundProcesses(session);
                return $"Background process '{name}' not found.\nActive processes: {activeProcesses}";
            }

            // If process still running, stream new output
            if (processInfo.Running)
            {
                var newOutput = GetNewOutputSinceLastCheck(session, name, filter);
                return $"[RUNNING]\n\n{newOutput}";
            }

            // Process completed - check if already finalized to cache
            if (IsInDevRunCache(session, name))
            {
                // Already cached - return summary
                var cachedSummary = GetCacheSummary(session, name);
                return $"[CACHED] Process '{name}' results:\n\n{cachedSummary}";
            }

            // First completion check - auto-finalize to cache
            var summary = FinalizeToCache(session, name);
            return $"[COMPLETED] Process '{name}' finished (exit code {processInfo.ExitCode})\n\n{summary}\n\nMoved to DevRun cache - use Get-StreamData for detailed analysis.";
        }
        catch (Exception ex)
        {
            return $"Error retrieving background process output: {ex.GetType().Name}: {ex.Message}";
        }
    }

    /// <summary>
    ///     Query background process status from $global:BrickBackgroundJobs.
    /// </summary>
    private BackgroundProcessInfo GetBackgroundProcess(PowerShellSession session, string name)
    {
        var checkScript = $@"
$job = $global:BrickBackgroundJobs['{name}']
if (-not $job) {{
    @{{ Exists = $false }} | ConvertTo-Json -Compress
    return
}}

$proc = Get-Process -Id $job.PID -ErrorAction SilentlyContinue
@{{
    Exists = $true
    Running = [bool]$proc
    OutFile = $job.OutFile
    ErrFile = $job.ErrFile
    ExitCode = if ($proc) {{ $null }} else {{ 'Unknown' }}
}} | ConvertTo-Json -Compress
";

        session.PowerShell.AddScript(checkScript);
        var result = session.PowerShell.Invoke();
        session.PowerShell.Commands.Clear();
        session.PowerShell.Streams.ClearStreams();

        var json = result.FirstOrDefault()?.ToString() ?? "{}";
        return System.Text.Json.JsonSerializer.Deserialize<BackgroundProcessInfo>(json)
               ?? new BackgroundProcessInfo { Exists = false };
    }

    /// <summary>
    ///     Get list of active background process names.
    /// </summary>
    private string GetActiveBackgroundProcesses(PowerShellSession session)
    {
        var listScript = "$global:BrickBackgroundJobs.Keys -join ', '";
        session.PowerShell.AddScript(listScript);
        var result = session.PowerShell.Invoke();
        session.PowerShell.Commands.Clear();
        session.PowerShell.Streams.ClearStreams();

        return result.FirstOrDefault()?.ToString() ?? "(none)";
    }

    /// <summary>
    ///     Read new output from temp files since last check.
    ///     Tracks file offsets to avoid returning duplicate content.
    /// </summary>
    private string GetNewOutputSinceLastCheck(PowerShellSession session, string name, string? filter)
    {
        var processInfo = GetBackgroundProcess(session, name);

        if (!processInfo.Exists || string.IsNullOrWhiteSpace(processInfo.OutFile))
            return "(No output available)";

        var stdoutOffset = _stdoutOffsets.GetOrAdd(name, 0);
        var stderrOffset = _stderrOffsets.GetOrAdd(name, 0);

        var newStdout = ReadFileFromOffset(processInfo.OutFile!, ref stdoutOffset, filter);
        var newStderr = ReadFileFromOffset(processInfo.ErrFile!, ref stderrOffset, filter);

        _stdoutOffsets[name] = stdoutOffset;
        _stderrOffsets[name] = stderrOffset;

        return FormatStreamOutput(newStdout, newStderr);
    }

    /// <summary>
    ///     Read lines from file starting at offset, applying optional regex filter.
    ///     Updates offset to new position after read.
    /// </summary>
    private string ReadFileFromOffset(string filePath, ref long offset, string? filter)
    {
        if (string.IsNullOrWhiteSpace(filePath) || !File.Exists(filePath))
            return "";

        try
        {
            using var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            fs.Seek(offset, SeekOrigin.Begin);

            using var sr = new StreamReader(fs);
            var lines = new List<string>();
            Regex? regex = !string.IsNullOrWhiteSpace(filter) ? new Regex(filter) : null;

            while (!sr.EndOfStream)
            {
                var line = sr.ReadLine();
                if (line == null) break;

                if (regex == null || regex.IsMatch(line))
                {
                    lines.Add(line);
                }
            }

            offset = fs.Position;
            return string.Join("\n", lines);
        }
        catch (Exception ex)
        {
            return $"(Error reading file: {ex.Message})";
        }
    }

    /// <summary>
    ///     Format stdout and stderr streams with labeled sections.
    /// </summary>
    private string FormatStreamOutput(string stdout, string stderr)
    {
        var output = new StringBuilder();

        if (!string.IsNullOrWhiteSpace(stdout))
        {
            output.AppendLine("=== Output ===");
            output.AppendLine(stdout);
        }

        if (!string.IsNullOrWhiteSpace(stderr))
        {
            if (output.Length > 0)
                output.AppendLine();

            output.AppendLine("=== Errors ===");
            output.AppendLine(stderr);
        }

        if (output.Length == 0)
            return "(No new output)";

        return output.ToString().TrimEnd();
    }

    /// <summary>
    ///     Check if process results are in DevRun cache.
    /// </summary>
    private bool IsInDevRunCache(PowerShellSession session, string name)
    {
        var checkScript = $"[bool]$global:DevRunCache.ContainsKey('{name}')";
        session.PowerShell.AddScript(checkScript);
        var result = session.PowerShell.Invoke();
        session.PowerShell.Commands.Clear();
        session.PowerShell.Streams.ClearStreams();

        var value = result.FirstOrDefault()?.ToString();
        return bool.TryParse(value, out var isInCache) && isInCache;
    }

    /// <summary>
    ///     Finalize background process to DevRun cache by calling Stop-BackgroundProcess.
    /// </summary>
    private string FinalizeToCache(PowerShellSession session, string name)
    {
        var finalizeScript = $"Stop-BackgroundProcess -Name '{name}'";
        session.PowerShell.AddScript(finalizeScript);
        var result = session.PowerShell.Invoke();
        session.PowerShell.Commands.Clear();
        session.PowerShell.Streams.ClearStreams();

        // Clean up offset tracking after finalization
        _stdoutOffsets.TryRemove(name, out _);
        _stderrOffsets.TryRemove(name, out _);

        // Return summary from Stop-BackgroundProcess result
        return GetCacheSummary(session, name);
    }

    /// <summary>
    ///     Get summary of cached results (error/warning counts, top errors).
    /// </summary>
    private string GetCacheSummary(PowerShellSession session, string name)
    {
        var summaryScript = $@"
$errorCount = (Get-StreamData {name} Error | Where-Object {{ $_ }}).Count
$warningCount = (Get-StreamData {name} Warning | Where-Object {{ $_ }}).Count
$outputCount = (Get-StreamData {name} Output | Where-Object {{ $_ }}).Count
$topErrors = Get-StreamData {name} Error | Where-Object {{ $_ }} | Select-Object -First 3

@{{
    ErrorCount = $errorCount
    WarningCount = $warningCount
    OutputCount = $outputCount
    TopErrors = $topErrors
}} | ConvertTo-Json -Compress
";

        session.PowerShell.AddScript(summaryScript);
        var result = session.PowerShell.Invoke();
        session.PowerShell.Commands.Clear();
        session.PowerShell.Streams.ClearStreams();

        var json = result.FirstOrDefault()?.ToString() ?? "{}";
        var summary = System.Text.Json.JsonSerializer.Deserialize<CacheSummary>(json)
                      ?? new CacheSummary();

        return FormatCacheSummary(summary);
    }

    /// <summary>
    ///     Format cache summary into human-readable text.
    /// </summary>
    private string FormatCacheSummary(CacheSummary summary)
    {
        var output = new StringBuilder();
        output.AppendLine($"Output Lines: {summary.OutputCount}");
        output.AppendLine($"Errors: {summary.ErrorCount}");
        output.AppendLine($"Warnings: {summary.WarningCount}");

        if (summary.TopErrors != null && summary.TopErrors.Length > 0)
        {
            output.AppendLine("\nTop Errors:");
            foreach (var error in summary.TopErrors)
            {
                output.AppendLine($"  {error}");
            }
        }

        return output.ToString().TrimEnd();
    }
}

/// <summary>
///     Background process status from PowerShell query.
/// </summary>
internal class BackgroundProcessInfo
{
    public bool Exists { get; set; }
    public bool Running { get; set; }
    public string? OutFile { get; set; }
    public string? ErrFile { get; set; }
    public string? ExitCode { get; set; }
}

/// <summary>
///     Cache summary with error/warning counts and top errors.
/// </summary>
internal class CacheSummary
{
    public int ErrorCount { get; set; }
    public int WarningCount { get; set; }
    public int OutputCount { get; set; }
    public string[]? TopErrors { get; set; }
}
