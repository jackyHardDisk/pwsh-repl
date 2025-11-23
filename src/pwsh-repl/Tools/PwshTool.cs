using System.ComponentModel;
using System.Management.Automation;
using System.Text;
using System.Text.Json;
using ModelContextProtocol.Server;
using PowerShellMcpServer.pwsh_repl.Core;

namespace PowerShellMcpServer.pwsh_repl.Tools;

/// <summary>
///     MCP tool for executing PowerShell scripts with persistent state.
///     Named sessions provide isolated PowerShell runspaces with independent variable
///     scopes.
/// </summary>
[McpServerToolType]
public class PwshTool
{
    private readonly SessionManager _sessionManager;

    public PwshTool(SessionManager sessionManager)
    {
        _sessionManager = sessionManager ??
                          throw new ArgumentNullException(nameof(sessionManager));
    }

    [McpServerTool]
    [Description(
        "Execute PowerShell with persistent sessions. Modules auto-load from PWSH_MCP_MODULES. IMPORTANT: Automatically fetch pwsh_mcp_modules://modules on first use to discover available module functions and PowerShell examples. Use mode parameter to call Base module functions (e.g., mode='Invoke-DevRun'). All executions auto-cache in $global:DevRunCache.")]
    public string Pwsh(
        [Description("PowerShell script to execute (optional if mode is provided)")]
        string? script = null,
        [Description(
            "Base module function name to call (e.g., 'Invoke-DevRun', 'Format-Count'). When provided, calls the function with script and kwargs parameters.")]
        string? mode = null,
        [Description(
            "Cache name for storing execution results in $global:DevRunCache. Auto-generated (pwsh_1, pwsh_2, etc.) if not provided.")]
        string? name = null,
        [Description(
            "Additional parameters for mode function (e.g., {\"Streams\": [\"Error\", \"Warning\"]}). Passed as hashtable to mode function.")]
        Dictionary<string, object>? kwargs = null,
        [Description(
            "Session ID (default: 'default'). Use the same session ID to maintain variables across calls.")]
        string sessionId = "default",
        [Description(
            "Virtual environment path or conda environment name (optional). Activates the environment before script execution.")]
        string? environment = null,
        [Description(
            "Initial session state: 'default' (standard cmdlets + current env) or 'create' (minimal blank slate). Default: 'default'")]
        string initialSessionState = "default",
        [Description(
            "Timeout in seconds (default: 60). Script execution will be terminated if it exceeds this duration.")]
        int timeoutSeconds = 60)
    {
        var session =
            _sessionManager.GetOrCreateSession(sessionId, environment,
                initialSessionState);

        try
        {
            // Validation: either script or mode must be provided
            if (string.IsNullOrWhiteSpace(script) && string.IsNullOrWhiteSpace(mode))
                return "Error: Either 'script' or 'mode' parameter must be provided.";

            // Build PowerShell script based on mode
            string executionScript;
            if (!string.IsNullOrWhiteSpace(mode))
            {
                // Mode callback pattern: call Base module function
                var sb = new StringBuilder();
                sb.Append($"{mode}");

                // Add -Script parameter if script provided
                if (!string.IsNullOrWhiteSpace(script))
                    sb.Append($" -Script {{{script}}}");

                // Add kwargs as hashtable parameters
                if (kwargs != null && kwargs.Count > 0)
                    foreach (var kvp in kwargs)
                    {
                        var value = ConvertToPs(kvp.Value);
                        sb.Append($" -{kvp.Key} {value}");
                    }

                executionScript = sb.ToString();
            }
            else
            {
                // Direct script execution
                executionScript = script!;
            }

            // Auto-generate cache name if not provided
            if (string.IsNullOrWhiteSpace(name))
            {
                // Increment counter and generate name
                session.PowerShell.AddScript(
                    "if (-not $global:DevRunCacheCounter) { $global:DevRunCacheCounter = 0 }; $global:DevRunCacheCounter++; $global:DevRunCacheCounter");
                var counterResult = session.PowerShell.Invoke();
                session.PowerShell.Commands.Clear();
                session.PowerShell.Streams.ClearStreams();

                var counter = counterResult.FirstOrDefault()?.ToString() ?? "1";
                name = $"pwsh_{counter}";
            }

            // Execute with timeout using async pattern
            // ExecuteScript handles stdin swapping and command cleanup
            var invokeTask = Task.Run(() => _sessionManager.ExecuteScript(session, executionScript));
            var timeout = TimeSpan.FromSeconds(timeoutSeconds);

            if (invokeTask.Wait(timeout))
            {
                var results = invokeTask.Result;
                var output = FormatResults(results, session.PowerShell);

                // Store in cache (only if not already cached by mode function like Invoke-DevRun)
                if (string.IsNullOrWhiteSpace(mode))
                {
                    var cacheScript = $@"
if (-not $global:DevRunCache.ContainsKey('{name}')) {{
    $global:DevRunCache['{name}'] = @{{
        Script = @'
{executionScript.Replace("'", "''")}
'@
        Timestamp = Get-Date
        Output = @'
{output.Replace("'", "''")}
'@
    }}
}}
";
                    session.PowerShell.AddScript(cacheScript);
                    session.PowerShell.Invoke();
                    session.PowerShell.Commands.Clear();
                    session.PowerShell.Streams.ClearStreams();
                }

                return output;
            }
            else
            {
                // Timeout occurred
                session.PowerShell.Stop();
                return
                    $"Error: Script execution timeout after {timeoutSeconds} seconds.\n" +
                    $"The script was terminated. Consider increasing the timeout parameter or optimizing the script.";
            }
        }
        catch (Exception ex)
        {
            return $"Error: {ex.GetType().Name}: {ex.Message}\nStack: {ex.StackTrace}";
        }
        finally
        {
            session.PowerShell.Streams.ClearStreams();
        }
    }

    /// <summary>
    ///     Convert C# object to PowerShell syntax for parameter passing.
    ///     Handles JsonElement from MCP SDK dictionary values.
    /// </summary>
    private static string ConvertToPs(object value)
    {
        // Handle JsonElement from MCP SDK
        if (value is JsonElement jsonElement)
        {
            return jsonElement.ValueKind switch
            {
                JsonValueKind.Null => "$null",
                JsonValueKind.True => "$true",
                JsonValueKind.False => "$false",
                JsonValueKind.String => $"'{jsonElement.GetString()?.Replace("'", "''")}'",
                JsonValueKind.Number => jsonElement.ToString(),
                JsonValueKind.Array => $"@({string.Join(", ", jsonElement.EnumerateArray().Select(e => ConvertToPs(e)))})",
                JsonValueKind.Object => ConvertJsonObjectToHashtable(jsonElement),
                _ => $"'{jsonElement}'"
            };
        }

        return value switch
        {
            null => "$null",
            string s => $"'{s.Replace("'", "''")}'",
            bool b => b ? "$true" : "$false",
            int or long or double or float => value.ToString()!,
            string[] arr => $"@({string.Join(", ", arr.Select(s => $"'{s.Replace("'", "''")}'"))})",
            IEnumerable<object> list => $"@({string.Join(", ", list.Select(ConvertToPs))})",
            _ => $"'{value.ToString()?.Replace("'", "''")}'"
        };
    }

    /// <summary>
    ///     Convert JsonElement object to PowerShell hashtable syntax.
    /// </summary>
    private static string ConvertJsonObjectToHashtable(JsonElement obj)
    {
        var pairs = obj.EnumerateObject()
            .Select(prop => $"{prop.Name} = {ConvertToPs(prop.Value)}");
        return $"@{{ {string.Join("; ", pairs)} }}";
    }

    private static string FormatResults(ICollection<PSObject> results, PowerShell pwsh)
    {
        var output = new StringBuilder();

        // Process output stream
        if (results.Count > 0)
        {
            // Buffer to hold contiguous format objects (preserves table structure)
            var formatBuffer = new List<PSObject>();

            foreach (var result in results)
                if (IsFormatObject(result))
                {
                    formatBuffer.Add(result);
                }
                else
                {
                    // Flush buffered format objects first (preserves order)
                    if (formatBuffer.Count > 0)
                    {
                        output.Append(RenderFormatObjects(formatBuffer));
                        formatBuffer.Clear();
                    }

                    // Handle normal objects
                    if (result?.BaseObject is string str)
                        output.AppendLine(str);
                    else
                        output.AppendLine(result?.ToString() ?? "(null)");
                }

            // Flush any remaining format objects at the end
            if (formatBuffer.Count > 0)
                output.Append(RenderFormatObjects(formatBuffer));
        }

        // Append errors if any
        if (pwsh.Streams.Error.Count > 0)
        {
            output.AppendLine("\nErrors:");
            foreach (var error in pwsh.Streams.Error) output.AppendLine($"  {error}");
        }

        // Append warnings if any
        if (pwsh.Streams.Warning.Count > 0)
        {
            output.AppendLine("\nWarnings:");
            foreach (var warning in pwsh.Streams.Warning)
                output.AppendLine($"  {warning}");
        }

        // Append verbose messages if any
        if (pwsh.Streams.Verbose.Count > 0)
        {
            output.AppendLine("\nVerbose:");
            foreach (var verbose in pwsh.Streams.Verbose)
                output.AppendLine($"  {verbose}");
        }

        // Append debug messages if any
        if (pwsh.Streams.Debug.Count > 0)
        {
            output.AppendLine("\nDebug:");
            foreach (var debug in pwsh.Streams.Debug) output.AppendLine($"  {debug}");
        }

        // Append information messages if any (includes Write-Host)
        if (pwsh.Streams.Information.Count > 0)
        {
            output.AppendLine("\nInformation:");
            foreach (var info in pwsh.Streams.Information)
                output.AppendLine($"  {info}");
        }

        return output.ToString().TrimEnd();
    }

    /// <summary>
    ///     Detects if an object is a PowerShell Internal Format object.
    ///     These are formatting instructions for the host, not data.
    /// </summary>
    private static bool IsFormatObject(PSObject? obj)
    {
        if (obj?.BaseObject == null) return false;

        var typeName = obj.BaseObject.GetType().FullName;
        return typeName != null &&
               typeName.Contains("Microsoft.PowerShell.Commands.Internal.Format");
    }

    /// <summary>
    ///     Renders Internal.Format objects into a string using a temporary pipeline.
    ///     This avoids re-running the user's script while preserving formatted output.
    /// </summary>
    private static string RenderFormatObjects(IEnumerable<PSObject> formatObjects)
    {
        try
        {
            // Create a lightweight, empty shell just for rendering
            using var renderPs = PowerShell.Create();

            // Add Out-String with parameters for clean output
            renderPs.AddCommand("Out-String")
                .AddParameter("Stream", false) // Single string block per table
                .AddParameter("Width", 120); // Prevent aggressive wrapping

            // Invoke passing the existing format objects as input
            var renderResults = renderPs.Invoke(formatObjects);

            var sb = new StringBuilder();
            foreach (var item in renderResults)
                if (item != null)
                    sb.Append(item);

            return sb.ToString();
        }
        catch (Exception ex)
        {
            return $"[Error rendering format objects: {ex.Message}]";
        }
    }
}