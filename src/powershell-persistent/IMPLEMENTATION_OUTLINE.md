# PowerShell Persistent MCP Server - Enhanced Implementation Outline

## 1. Project Structure
```
homebrew-mcp/
├── custom/
│   └── powershell-persistent/
│       ├── PowerShellMcpServer.csproj
│       ├── Program.cs                      # MCP stdio server entry point
│       ├── Core/
│       │   ├── PowerShellPool.cs           # Channel-based pool (BackgroundProcessor pattern)
│       │   ├── PowerShellSession.cs        # Wrapper around Runspace + PowerShell
│       │   └── SessionManager.cs           # Optional: Multi-session support
│       ├── Tools/
│       │   ├── PwshTool.cs                 # Execute PowerShell script/command
│       │   ├── PwshGetVariableTool.cs      # Get variable value
│       │   ├── PwshSetVariableTool.cs      # Set variable value
│       │   └── PwshResetTool.cs            # Reset session state
│       ├── Models/
│       │   ├── ExecutionResult.cs          # Result + streams
│       │   └── SessionConfig.cs            # Configuration options
│       ├── Utils/
│       │   ├── OutputFormatter.cs          # Format PSObjects to strings
│       │   └── StreamCollector.cs          # Collect all output streams
│       └── docs/                           # Documentation library
│           ├── api-references.md           # Microsoft Learn API docs
│           ├── code-examples.md            # Curated code samples
│           └── stream-handling.md          # PowerShell streams guide
```

## 2. Core Classes

### 2.1 PowerShellPool.cs (Channel-based Pool)

**Pattern:** Based on PowerAuger's `BackgroundProcessor.cs`

**Microsoft Learn References:**
- **Channel API**: [System.Threading.Channels](https://learn.microsoft.com/en-us/dotnet/core/extensions/channels)
  - Unbounded channel for pool: `Channel.CreateUnbounded<PowerShell>()`
  - Thread-safe producer/consumer without locks
  - Async-native: `await _pool.Reader.ReadAsync(cancellationToken)`

- **Runspace Creation**: [RunspaceFactory.CreateRunspace](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.runspacefactory)
  - Create with InitialSessionState: `RunspaceFactory.CreateRunspace(iss)`
  - Open runspace: `runspace.Open()`

- **PowerShell Instance**: [PowerShell.Create](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.powershell.create)
  - Create instance: `PowerShell.Create()`
  - Attach to runspace: `ps.Runspace = runspace`

**Implementation Pattern:**
```csharp
private readonly Channel<PowerShellSession> _pool;

public async Task<PowerShellSession> CheckOutAsync(CancellationToken ct)
{
    return await _pool.Reader.ReadAsync(ct);
}

public void CheckIn(PowerShellSession session)
{
    session.PowerShell.Commands.Clear();
    session.PowerShell.Streams.ClearStreams();  // Critical!
    _pool.Writer.TryWrite(session);
}
```

**Key Insight from Research:**
- `Streams.ClearStreams()` prevents error accumulation (not in original Microsoft docs)
- Channel pattern superior to locks for async MCP protocol

### 2.2 PowerShellSession.cs

**Wraps:** Runspace + PowerShell instance + metadata

**Responsibilities:**
- Track session state
- Provide clean execution API
- Manage disposal

### 2.3 SessionManager.cs (Future)

**Responsibilities:**
- Named sessions (session_id parameter)
- Session isolation
- Multi-pool management

## 3. Stream Handling (Critical Component)

### 3.1 PowerShell Stream Types

**Microsoft Learn Reference**: [PipelineResultTypes Enum](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.pipelineresulttypes)

**Six Stream Types:**
1. **Output** (1) - Success output (PSObject collection)
2. **Error** (2) - Error output (ErrorRecord collection)
3. **Warning** (3) - Warning stream (WarningRecord)
4. **Verbose** (4) - Verbose stream (VerboseRecord)
5. **Debug** (5) - Debug stream (DebugRecord)
6. **Information** (6) - Information stream (InformationRecord) - **includes Write-Host**

**CRITICAL:** Write-Host writes to the **Information stream (6)**, NOT a separate "host" stream. This stream must be captured for Write-Host output to be visible.

**Accessing Streams:**
```csharp
PSDataCollection<ErrorRecord> errors = powershell.Streams.Error;
PSDataCollection<WarningRecord> warnings = powershell.Streams.Warning;
PSDataCollection<VerboseRecord> verbose = powershell.Streams.Verbose;
PSDataCollection<DebugRecord> debug = powershell.Streams.Debug;
PSDataCollection<InformationRecord> info = powershell.Streams.Information;
```

**Microsoft Learn Code Example**: [Runspace04 Sample - Error Collection](https://learn.microsoft.com/en-us/powershell/scripting/developer/hosting/runspace04-sample)

```csharp
// From Microsoft Learn sample:
PSDataCollection<ErrorRecord> errors = powershell.Streams.Error;
if (errors != null && errors.Count > 0)
{
    foreach (ErrorRecord err in errors)
    {
        Console.WriteLine($"error: {err.ToString()}");
    }
}
```

**Current Implementation Status (2025-11-16):**

PwshTool.cs (lines 70-107) currently captures:
- ✅ Output stream (1) - via `results` collection
- ✅ Error stream (2) - via `pwsh.Streams.Error`
- ✅ Warning stream (3) - via `pwsh.Streams.Warning`
- ❌ Verbose stream (4) - NOT captured
- ❌ Debug stream (5) - NOT captured
- ❌ Information stream (6) - NOT captured (**causes Write-Host to be invisible**)

**Action Required:** Add Verbose, Debug, and Information stream capture to FormatResults method.

### 3.2 Error Handling Strategy

**Two Error Types:**

1. **Non-Terminating Errors** (collected in Streams.Error)
   - Continue execution
   - Access via `powershell.Streams.Error`
   - Check `powershell.HadErrors` boolean

2. **Terminating Errors** (throw RuntimeException)
   - Stop execution
   - Catch with `catch (RuntimeException ex)`
   - Access via `ex.ErrorRecord`

**Microsoft Learn Example**: [StopProcessSample02](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/stopprocesssample02-sample)

```csharp
try
{
    var results = powershell.Invoke();

    // Check for non-terminating errors
    if (powershell.HadErrors)
    {
        foreach (ErrorRecord error in powershell.Streams.Error)
        {
            // Process error
        }
    }
}
catch (RuntimeException ex)
{
    // Handle terminating errors
    var errorRecord = ex.ErrorRecord;
    var message = errorRecord.Exception.Message;
}
```

### 3.3 Preference Variables and Stream Visibility

**Default Preferences:**
```powershell
$VerbosePreference = "SilentlyContinue"      # Default - Verbose hidden
$DebugPreference = "SilentlyContinue"        # Default - Debug hidden
$InformationPreference = "SilentlyContinue"  # Default - Information hidden (PS 5.0+)
$WarningPreference = "Continue"              # Default - Warnings shown
$ErrorActionPreference = "Continue"          # Default - Errors shown
```

**CRITICAL:** Even when preference is SilentlyContinue, messages ARE still written to `pwsh.Streams.*` collections. Preference variables only control console display, NOT stream capture. C# code can always access all streams regardless of preferences.

**Reference**: [Configure runbook output and message streams](https://learn.microsoft.com/en-us/azure/automation/automation-runbook-output-and-messages#working-with-message-streams)

### 3.4 Output Formatting

**Challenge:** Convert PSObject to string for MCP response

**Microsoft Learn Reference**: [Out-String Cmdlet](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/out-string)

**Pattern 1: Use PowerShell's Out-String**
```csharp
public static string FormatPSObject(PSObject obj)
{
    if (obj.BaseObject is string str)
        return str;

    // Use PowerShell's own formatting
    using var ps = PowerShell.Create();
    ps.AddCommand("Out-String");
    ps.AddParameter("InputObject", obj);
    ps.AddParameter("Width", 200);  // Prevent truncation

    var formatted = ps.Invoke();
    return formatted.FirstOrDefault()?.ToString() ?? obj.ToString();
}
```

**Pattern 2: BaseObject check**
```csharp
if (obj.BaseObject is string str)
    return str;
else
    return obj.ToString();  // Uses PowerShell's default ToString
```

## 4. MCP Protocol Implementation

### 4.1 Tool Definitions

```csharp
[Tool("pwsh")]
public async Task<string> ExecutePowerShell(
    [Parameter("script")] string script,
    [Parameter("session_id", required: false)] string? sessionId = "default")
{
    var session = await _pool.CheckOutAsync();
    try
    {
        session.PowerShell.AddScript(script);
        var results = session.PowerShell.Invoke();

        return FormatResult(results, session.PowerShell.Streams);
    }
    finally
    {
        _pool.CheckIn(session);
    }
}
```

### 4.2 Complete Stream Capture Pattern

**Enhanced FormatResults for all six streams:**

```csharp
private static string FormatResults(ICollection<PSObject> results, PowerShell pwsh)
{
    var output = new StringBuilder();

    // 1. Output stream
    if (results.Count > 0)
    {
        foreach (var result in results)
        {
            if (result?.BaseObject is string str)
                output.AppendLine(str);
            else
                output.AppendLine(result?.ToString() ?? "(null)");
        }
    }

    // 2. Error stream
    if (pwsh.HadErrors)
    {
        output.AppendLine("\nErrors:");
        foreach (var error in pwsh.Streams.Error)
        {
            output.AppendLine($"  {error}");
        }
    }

    // 3. Warning stream
    if (pwsh.Streams.Warning.Count > 0)
    {
        output.AppendLine("\nWarnings:");
        foreach (var warning in pwsh.Streams.Warning)
        {
            output.AppendLine($"  {warning}");
        }
    }

    // 4. Verbose stream
    if (pwsh.Streams.Verbose.Count > 0)
    {
        output.AppendLine("\nVerbose:");
        foreach (var verbose in pwsh.Streams.Verbose)
        {
            output.AppendLine($"  {verbose}");
        }
    }

    // 5. Debug stream
    if (pwsh.Streams.Debug.Count > 0)
    {
        output.AppendLine("\nDebug:");
        foreach (var debug in pwsh.Streams.Debug)
        {
            output.AppendLine($"  {debug}");
        }
    }

    // 6. Information stream (includes Write-Host)
    if (pwsh.Streams.Information.Count > 0)
    {
        output.AppendLine("\nInformation:");
        foreach (var info in pwsh.Streams.Information)
        {
            output.AppendLine($"  {info}");
        }
    }

    return output.ToString().TrimEnd();
}
```

**Impact:**
- Minimal token cost (~200-300 tokens)
- Fixes Write-Host visibility (Information stream)
- Complete stream visibility for debugging
- All streams already captured by PowerShell runtime

## 5. Concurrency Patterns

**Microsoft Learn Reference**: [Channel-based Producer-Consumer](https://learn.microsoft.com/en-us/dotnet/core/extensions/channels)

**Key Pattern from Research:**
```csharp
// Bounded channel with backpressure
var channel = Channel.CreateBounded<T>(new BoundedChannelOptions(capacity: 4)
{
    FullMode = BoundedChannelFullMode.Wait  // Block producer if full
});

// Or unbounded for pool
var pool = Channel.CreateUnbounded<PowerShellSession>();
```

**Async patterns:**
```csharp
// Async checkout
var session = await _pool.Reader.ReadAsync(cancellationToken);

// Async checkin (non-blocking)
_pool.Writer.TryWrite(session);
```

## 6. Configuration & Initialization

### 6.1 InitialSessionState Configuration

**Microsoft Learn Reference**: [Windows PowerShell01 Sample](https://learn.microsoft.com/en-us/powershell/scripting/developer/hosting/windows-powershell01-sample)

```csharp
// Create default state (includes all cmdlets/providers)
var iss = InitialSessionState.CreateDefault();

// Windows-specific
if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
{
    iss.ExecutionPolicy = ExecutionPolicy.Unrestricted;
}

// Pre-load modules (from PowerAuger pattern)
var runspace = RunspaceFactory.CreateRunspace(iss);
runspace.Open();

using (var ps = PowerShell.Create())
{
    ps.Runspace = runspace;
    ps.AddScript(@"
        Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue
        Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue
    ");
    ps.Invoke();
    ps.Commands.Clear();
    ps.Streams.ClearStreams();
}
```

### 6.2 SessionConfig

```csharp
public class SessionConfig
{
    public int PoolSize { get; set; } = 4;
    public bool PreLoadModules { get; set; } = true;
    public string[] ModulesToPreLoad { get; set; } =
    [
        "Microsoft.PowerShell.Management",
        "Microsoft.PowerShell.Utility"
    ];
    public TimeSpan CommandTimeout { get; set; } = TimeSpan.FromSeconds(30);
}
```

## 7. Output Response Format

### 7.1 Success Response
```json
{
    "success": true,
    "output": "Process output here...",
    "warnings": [],
    "verbose": [],
    "debug": []
}
```

### 7.2 Error Response
```json
{
    "success": false,
    "output": "",
    "errors": [
        {
            "message": "Cannot bind parameter...",
            "category": "InvalidArgument",
            "targetObject": "Get-ChildItem"
        }
    ],
    "had_terminating_error": false
}
```

## 8. Testing Strategy

### 8.1 PowerShell Pool Tests
- Checkout/checkin cycle
- Concurrent access (stress test)
- Stream clearing between calls
- Disposal cleanup

### 8.2 Stream Collection Tests
- Error stream capture
- Warning/Verbose/Debug capture
- Mixed stream scenarios

### 8.3 Session Persistence Tests
```powershell
# Call 1
$myVar = 42

# Call 2 (same session)
$myVar * 2  # Should return 84
```

## 9. Dependencies

### 9.1 NuGet Packages
```xml
<PackageReference Include="System.Management.Automation" Version="7.4.0" />
<PackageReference Include="System.Threading.Channels" Version="8.0.0" />
```

### 9.2 Runtime Requirements
- .NET 8.0+
- PowerShell 7.4+ libraries
- Cross-platform (Windows/Linux/macOS)

## 10. Key Implementation Details from Research

### 10.1 Stream Clearing (Critical!)
```csharp
// ALWAYS clear between uses (from PowerAuger)
pwsh.Commands.Clear();
pwsh.Streams.ClearStreams();  // Prevents error accumulation
```

### 10.2 Channel vs Lock
**Use Channel (from research):**
- Thread-safe by design
- Async-native
- Better for MCP stdio protocol
- No deadlock potential

**NOT this (lock-based):**
```csharp
private readonly object _lock = new object();
lock (_lock) { /* execute */ }  // Blocking, not async-friendly
```

### 10.3 Out-String Width Parameter
```csharp
// Prevent truncation (from Microsoft Learn)
ps.AddCommand("Out-String");
ps.AddParameter("Width", 250);  // Default can truncate long output
```

## 11. PowerShell Modules

### 11.1 AgentBricks Module (Implemented)
**Location:** `src/powershell-persistent/Modules/AgentBricks/`

**Purpose:** Token-efficient analysis and transformation functions for build logs, error messages, and structured data.

**Features:**
- 20 PowerShell functions (Transform, Extract, Analyze, Present, Meta)
- 40+ pre-configured patterns for build tools (MSBuild, GCC, CMake, ESLint, Pytest)
- Auto-loads on session creation
- Comment-based help (Get-Help)
- Zero upfront token cost (discovered via Get-Help)

**Pattern:**
```powershell
# Run build with dev_run
dev_run("dotnet build", "build")

# Analyze with AgentBricks
pwsh('$env:build_stderr | Find-Errors | Measure-Frequency | Format-Count')
```

### 11.2 SessionLog Module (Implemented)
**Location:** `.gary/scripts/SessionLog.psm1`

**Purpose:** JSONL-based session logging for tracking completed tasks, todos, notes, and bugs.

**Functions:**
- `Add-SessionLog` - Create session entry
- `Read-SessionLog` - Query entries (Last, Date, Show-Session)
- `Get-SessionDate` - Calculate session date (4 AM boundary)

**Pattern:**
```powershell
Add-SessionLog -Completed @("Task 1") -Todos @("Task 2") -Notes @("Note") -Bugs @()
Read-SessionLog -Last 1
```

**Loading:** Via PWSH_MCP_MODULES environment variable in .mcp.json

### 11.3 TokenCounter Module (Planned)
**Location:** `.gary/scripts/TokenCounter.psm1` (to be created)

**Purpose:** Measure token costs for MCP optimization metrics.

**Proposed Functions:**
- `Measure-Tokens` - Count tokens in text/files (approximate or API-based)
- `Measure-McpTools` - Analyze MCP tool schema token costs
- `Compare-TokenUsage` - Before/after optimization comparison
- `Find-TokenHogs` - Identify highest-cost items in MCP configuration
- `Show-TokenBreakdown` - Visual breakdown similar to `/context` output

**Use Cases:**
- Optimize MCP tool schemas (identify verbose descriptions)
- Measure token savings from filtering/wrapping
- Guide documentation length decisions
- Real-time feedback during slash command development

**Implementation Options:**
1. **Approximate counting** - Words × 1.3 factor (fast, good enough for optimization)
2. **tiktoken via Python** - Accurate Claude tokenization (requires Python interop)
3. **API-based** - Use Claude API for exact counts (requires API key, slower)

**Pattern:**
```powershell
# Measure tool schema
Get-Content .mcp.json | ConvertFrom-Json |
  Select-Object -ExpandProperty mcpServers |
  Measure-McpTools

# Find token hogs
Find-TokenHogs -Path .claude/commands/*.md -Top 10

# Compare optimization
$before = Measure-Tokens -Path old_schema.json
$after = Measure-Tokens -Path new_schema.json
Compare-TokenUsage -Before $before -After $after
```

**Token Efficiency:**
- Module itself: ~500 tokens (description + parameters)
- Replaces need for separate Python token counter tool
- Leverages existing PWSH_MCP_MODULES infrastructure
- Direct integration with PowerShell pipeline

## 12. Future Enhancements

### 12.1 Named Sessions (Implemented)
```csharp
public async Task<string> ExecutePowerShell(string script, string sessionId)
{
    var pool = _sessionManager.GetPool(sessionId);
    // ...
}
```

### 12.2 JEA Integration
- Restricted runspaces
- Command whitelisting
- Parameter filtering

### 12.3 Async Execution
```csharp
// BeginInvoke for long-running commands
var asyncResult = ps.BeginInvoke();
// Poll or callback pattern
```

## 12. Microsoft Learn Documentation Library

See `/docs` directory for curated references:
- `api-references.md` - Core API documentation links
- `code-examples.md` - Working code samples
- `stream-handling.md` - Complete stream handling guide

## 13. Implementation Phases

### Phase 1: Core Pool (Week 1)
- PowerShellPool.cs with Channel pattern
- Basic PowerShellSession wrapper
- Stream clearing logic

### Phase 2: MCP Integration (Week 1)
- Program.cs stdio server
- PwshTool implementation
- Output formatting

### Phase 3: Stream Handling (Week 2)
- Full stream collection
- Error formatting
- Response JSON structure

### Phase 4: Testing & Polish (Week 2)
- Unit tests
- Integration tests
- Documentation
- Examples

---

**Total Estimated Effort:** 2-3 weeks part-time

**Key Success Metrics:**
- Variables persist across calls
- No memory leaks (stream accumulation)
- Handles concurrent requests
- Proper error reporting
