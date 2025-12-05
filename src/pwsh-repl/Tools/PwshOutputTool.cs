using System.ComponentModel;
using System.Text;
using System.Text.RegularExpressions;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Tools;

/// <summary>
///     MCP tool for retrieving output from background processes.
///     Uses SessionManager for process tracking (C#-managed background processes).
///     Auto-finalizes to DevRun cache when process completes.
/// </summary>
[McpServerToolType]
public class PwshOutputTool
{
    private readonly SessionManager _sessionManager;

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
        try
        {
            // Check if background process exists using SessionManager
            var processInfo = GetBackgroundProcess(sessionId, name);

            if (!processInfo.Exists)
            {
                var activeProcesses = GetActiveBackgroundProcesses(sessionId);
                return $"Background process '{name}' not found.\nActive processes: {activeProcesses}";
            }

            // If process still running, stream new output
            if (processInfo.Running)
            {
                var newOutput = GetNewOutputSinceLastCheck(sessionId, name, filter);
                return $"[RUNNING]\n\n{newOutput}";
            }

            // Process completed - get session for cache operations
            var session = _sessionManager.GetOrCreateSession(sessionId);

            // Check if already finalized to cache
            if (IsInDevRunCache(session, name))
            {
                // Already cached - return summary
                var cachedSummary = GetCacheSummary(session, name);
                return $"[CACHED] Process '{name}' results:\n\n{cachedSummary}";
            }

            // First completion check - auto-finalize to cache
            var summary = FinalizeToCache(sessionId, name);
            return $"[COMPLETED] Process '{name}' finished (exit code {processInfo.ExitCode})\n\n{summary}\n\nMoved to DevRun cache - use Get-StreamData for detailed analysis.";
        }
        catch (Exception ex)
        {
            return $"Error retrieving background process output: {ex.GetType().Name}: {ex.Message}";
        }
    }

    /// <summary>
    ///     Query background process status from SessionManager (C#-managed).
    /// </summary>
    private ProcessStatusInfo GetBackgroundProcess(string sessionId, string name)
    {
        try
        {
            var status = _sessionManager.GetBackgroundProcessStatus(sessionId, name);
            return new ProcessStatusInfo
            {
                Exists = true,
                Running = status.IsRunning,
                ExitCode = status.ExitCode?.ToString()
            };
        }
        catch (InvalidOperationException)
        {
            // Process not found
            return new ProcessStatusInfo { Exists = false };
        }
    }

    /// <summary>
    ///     Get list of active background process names from SessionManager.
    /// </summary>
    private string GetActiveBackgroundProcesses(string sessionId)
    {
        try
        {
            var processes = _sessionManager.ListBackgroundProcesses(sessionId);
            var names = processes.Select(p => p.Name).ToList();
            return names.Count > 0 ? string.Join(", ", names) : "(none)";
        }
        catch (InvalidOperationException)
        {
            return "(none)";
        }
    }

    /// <summary>
    ///     Read new output since last check using SessionManager incremental reads.
    ///     C# BackgroundProcessInfo tracks position via LastStdoutPosition/LastStderrPosition.
    /// </summary>
    private string GetNewOutputSinceLastCheck(string sessionId, string name, string? filter)
    {
        try
        {
            var (stdout, stderr) = _sessionManager.ReadBackgroundOutput(sessionId, name, incremental: true);

            // Apply regex filter if specified
            if (!string.IsNullOrWhiteSpace(filter))
            {
                var regex = new Regex(filter);
                stdout = FilterLines(stdout, regex);
                stderr = FilterLines(stderr, regex);
            }

            return FormatStreamOutput(stdout, stderr);
        }
        catch (InvalidOperationException ex)
        {
            return $"(Error reading output: {ex.Message})";
        }
    }

    /// <summary>
    ///     Filter lines matching regex pattern.
    /// </summary>
    private static string FilterLines(string content, Regex regex)
    {
        if (string.IsNullOrEmpty(content))
            return content;

        var matchingLines = content
            .Split('\n')
            .Where(line => regex.IsMatch(line));

        return string.Join("\n", matchingLines);
    }

    /// <summary>
    ///     Format stdout and stderr streams with labeled sections.
    /// </summary>
    private static string FormatStreamOutput(string stdout, string stderr)
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
    private static bool IsInDevRunCache(PowerShellSession session, string name)
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
    ///     Finalize background process to DevRun cache using SessionManager.StopBackgroundProcess.
    /// </summary>
    private string FinalizeToCache(string sessionId, string name)
    {
        try
        {
            // StopBackgroundProcess with populateCache=true populates DevRun cache
            _sessionManager.StopBackgroundProcess(sessionId, name, populateCache: true);

            // Get session for cache summary
            var session = _sessionManager.GetOrCreateSession(sessionId);
            return GetCacheSummary(session, name);
        }
        catch (InvalidOperationException ex)
        {
            return $"(Error finalizing: {ex.Message})";
        }
    }

    /// <summary>
    ///     Get summary of cached results (error/warning counts, top errors).
    /// </summary>
    private static string GetCacheSummary(PowerShellSession session, string name)
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
    private static string FormatCacheSummary(CacheSummary summary)
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
///     Background process status from SessionManager query.
/// </summary>
internal class ProcessStatusInfo
{
    public bool Exists { get; set; }
    public bool Running { get; set; }
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
