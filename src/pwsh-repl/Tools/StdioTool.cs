// Copyright (c) 2025 jackyHardDisk. Licensed under the MIT License.

using System.ComponentModel;
using System.Text;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Tools;

[McpServerToolType]
public class StdioTool
{
    private readonly SessionManager _sessionManager;

    public StdioTool(SessionManager sessionManager)
    {
        _sessionManager = sessionManager;
    }

    [McpServerTool]
    [Description(@"Interact with background process stdio (write stdin, read stdout/stderr, close stdin, stop process)

**Usage pattern:**
  pwsh(script='python server.py', runInBackground=true, name='srv')
  stdio(name='srv')  # read output
  stdio(name='srv', data='command\n')  # send input
  stdio(name='srv', stop=true)  # stop and cache for Get-BackgroundData")]
    public string Stdio(
        [Description("Background process name (required)")]
        string name,
        [Description("Data to write to stdin (optional)")]
        string? data = null,
        [Description("Close stdin to signal EOF")]
        bool close = false,
        [Description("Stop/kill the background process and populate DevRun cache for Get-BackgroundData")]
        bool stop = false,
        [Description("Read and return stdout/stderr output (default: true)")]
        bool readOutput = true,
        [Description("Session ID (default: 'default')")]
        string sessionId = "default")
    {
        if (string.IsNullOrEmpty(name))
            return "Error: Background process name is required";

        return HandleBackgroundProcess(sessionId, name, data, close, stop, readOutput);
    }

    /// <summary>
    ///     Handle background process stdio operations via SessionManager.
    /// </summary>
    private string HandleBackgroundProcess(string sessionId, string name, string? data, bool close, bool stop, bool readOutput)
    {
        var result = new StringBuilder();

        try
        {
            // Stop process if requested (do this first, before other operations)
            if (stop)
            {
                // Get final output before stopping
                var (finalStdout, finalStderr) = _sessionManager.ReadBackgroundOutput(sessionId, name, incremental: false);

                _sessionManager.StopBackgroundProcess(sessionId, name, populateCache: true);
                result.AppendLine($"Stopped background process '{name}' (output cached for Get-BackgroundData)");

                if (!string.IsNullOrEmpty(finalStdout))
                {
                    result.AppendLine();
                    result.AppendLine("=== final stdout ===");
                    result.Append(finalStdout);
                }

                if (!string.IsNullOrEmpty(finalStderr))
                {
                    result.AppendLine();
                    result.AppendLine("=== final stderr ===");
                    result.Append(finalStderr);
                }

                return result.ToString().TrimEnd();
            }

            // Write data if provided
            if (!string.IsNullOrEmpty(data))
            {
                _sessionManager.WriteToBackgroundProcess(sessionId, name, data);
                result.AppendLine($"Wrote {data.Length} chars to '{name}' stdin");
            }

            // Close stdin if requested
            if (close)
            {
                _sessionManager.CloseBackgroundProcessStdin(sessionId, name);
                result.AppendLine($"Closed '{name}' stdin (EOF)");
            }

            // Read output if requested
            if (readOutput)
            {
                // Small delay to let async output handlers catch up
                Thread.Sleep(100);

                var (stdout, stderr) = _sessionManager.ReadBackgroundOutput(sessionId, name, incremental: true);

                if (!string.IsNullOrEmpty(stdout))
                {
                    result.AppendLine();
                    result.AppendLine("=== stdout ===");
                    result.Append(stdout);
                }

                if (!string.IsNullOrEmpty(stderr))
                {
                    result.AppendLine();
                    result.AppendLine("=== stderr ===");
                    result.Append(stderr);
                }
            }

            // If no action was taken, just return status
            if (result.Length == 0)
            {
                var status = _sessionManager.GetBackgroundProcessStatus(sessionId, name);
                return $"Background process '{name}': {(status.IsRunning ? "running" : "stopped")} (runtime: {status.Runtime:hh\\:mm\\:ss})";
            }

            return result.ToString().TrimEnd();
        }
        catch (InvalidOperationException ex)
        {
            return $"Error: {ex.Message}";
        }
        catch (Exception ex)
        {
            return $"Error with background process '{name}': {ex.Message}";
        }
    }
}
