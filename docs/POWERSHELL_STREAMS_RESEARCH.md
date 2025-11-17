# PowerShell Streams Research

**Research Goal:** Capture all six PowerShell output streams in pwsh and dev_run MCP tools

**Date:** 2025-11-16

## PowerShell Six Stream Architecture

**Reference:** IMPLEMENTATION_OUTLINE.md Section 3.1 + Microsoft Learn [PipelineResultTypes Enum](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.pipelineresulttypes)

PowerShell has six distinct output streams (numbered 1-6):

| Stream | Number | PSDataStreams Property | Type | Write Cmdlet | Description |
|--------|--------|----------------------|------|--------------|-------------|
| Output | 1 | N/A (returned directly) | `PSObject` collection | Write-Output | Success pipeline objects |
| Error | 2 | `.Error` | `PSDataCollection<ErrorRecord>` | Write-Error | Non-terminating errors |
| Warning | 3 | `.Warning` | `PSDataCollection<WarningRecord>` | Write-Warning | Warning messages |
| Verbose | 4 | `.Verbose` | `PSDataCollection<VerboseRecord>` | Write-Verbose | Detailed logging |
| Debug | 5 | `.Debug` | `PSDataCollection<DebugRecord>` | Write-Debug | Debug messages |
| Information | 6 | `.Information` | `PSDataCollection<InformationRecord>` | Write-Information, Write-Host | Informational messages |

**Key Discovery:** Write-Host writes to the **Information stream (6)**, NOT a separate "host" stream.

**Accessing Streams (from IMPLEMENTATION_OUTLINE.md:102-109):**
```csharp
PSDataCollection<ErrorRecord> errors = powershell.Streams.Error;
PSDataCollection<WarningRecord> warnings = powershell.Streams.Warning;
PSDataCollection<VerboseRecord> verbose = powershell.Streams.Verbose;
PSDataCollection<DebugRecord> debug = powershell.Streams.Debug;
PSDataCollection<InformationRecord> info = powershell.Streams.Information;
```

## Current Implementation Status

### PwshTool.cs (Lines 70-107)

**Currently captures:**
- ✅ Output stream (1) - via `results` collection
- ✅ Error stream (2) - via `pwsh.Streams.Error`
- ✅ Warning stream (3) - via `pwsh.Streams.Warning`

**Missing:**
- ❌ Verbose stream (4) - `pwsh.Streams.Verbose`
- ❌ Debug stream (5) - `pwsh.Streams.Debug`
- ❌ Information stream (6) - `pwsh.Streams.Information` (includes Write-Host)

### DevRunTool.cs (Lines 72-109)

**Currently uses:** Script-based redirection with `2>&1` operator

**Captures:**
- ✅ Output stream (1) - via `$stdoutLines`
- ⚠️ Error stream (2) - partially via ErrorRecord detection in `2>&1` output

**Missing:**
- ❌ Warning stream (3)
- ❌ Verbose stream (4)
- ❌ Debug stream (5)
- ❌ Information stream (6)

**Problem:** Script uses string-based capture which loses structured stream information.

## Solution: PowerShell.Streams Property

### API Reference

`System.Management.Automation.PowerShell.Streams` property provides:

```csharp
public sealed class PSDataStreams
{
    public PSDataCollection<ErrorRecord> Error { get; set; }
    public PSDataCollection<WarningRecord> Warning { get; set; }
    public PSDataCollection<VerboseRecord> Verbose { get; set; }
    public PSDataCollection<DebugRecord> Debug { get; set; }
    public PSDataCollection<InformationRecord> Information { get; set; }
    public PSDataCollection<ProgressRecord> Progress { get; set; }

    public void ClearStreams();
}
```

**Note:** Progress stream exists but rarely used (auto-generated activity tracking).

### Code Example from Microsoft Docs

From runspace04-sample (Runspace04.cs:48-54) and IMPLEMENTATION_OUTLINE.md:111-123:

```csharp
// After powershell.Invoke()
PSDataCollection<ErrorRecord> errors = powershell.Streams.Error;
if (errors != null && errors.Count > 0)
{
    foreach (ErrorRecord err in errors)
    {
        System.Console.WriteLine("    error: {0}", err.ToString());
    }
}
```

### Error Handling Strategy (from IMPLEMENTATION_OUTLINE.md:125-161)

**Two Error Types:**

1. **Non-Terminating Errors** (collected in Streams.Error)
   - Continue execution
   - Access via `powershell.Streams.Error`
   - Check `powershell.HadErrors` boolean

2. **Terminating Errors** (throw RuntimeException)
   - Stop execution
   - Catch with `catch (RuntimeException ex)`
   - Access via `ex.ErrorRecord`

**Pattern:**
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

### Preference Variables Control Visibility

By default, some streams require preference variables to be visible:

```powershell
$VerbosePreference = "Continue"  # Default: SilentlyContinue
$DebugPreference = "Continue"    # Default: SilentlyContinue
$InformationPreference = "Continue"  # Default: SilentlyContinue (PS 5.0+)
```

**Critical:** Even if preference is SilentlyContinue, messages ARE written to `pwsh.Streams.*` collections. Preference only controls console display, NOT stream capture.

## Implementation Recommendations

### 1. PwshTool.cs Enhancement

**Current FormatResults method (lines 70-107) enhancement:**

```csharp
private static string FormatResults(ICollection<PSObject> results, PowerShell pwsh)
{
    var output = new StringBuilder();

    // 1. Output stream (existing)
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

    // 2. Error stream (existing)
    if (pwsh.HadErrors)
    {
        output.AppendLine("\nErrors:");
        foreach (var error in pwsh.Streams.Error)
        {
            output.AppendLine($"  {error}");
        }
    }

    // 3. Warning stream (existing)
    if (pwsh.Streams.Warning.Count > 0)
    {
        output.AppendLine("\nWarnings:");
        foreach (var warning in pwsh.Streams.Warning)
        {
            output.AppendLine($"  {warning}");
        }
    }

    // 4. Verbose stream (NEW)
    if (pwsh.Streams.Verbose.Count > 0)
    {
        output.AppendLine("\nVerbose:");
        foreach (var verbose in pwsh.Streams.Verbose)
        {
            output.AppendLine($"  {verbose}");
        }
    }

    // 5. Debug stream (NEW)
    if (pwsh.Streams.Debug.Count > 0)
    {
        output.AppendLine("\nDebug:");
        foreach (var debug in pwsh.Streams.Debug)
        {
            output.AppendLine($"  {debug}");
        }
    }

    // 6. Information stream (NEW) - includes Write-Host
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
- Token increase: ~200-300 tokens (minimal)
- Show-Session function will work (Write-Host → Information stream)
- Complete stream visibility for debugging

### 2. DevRunTool.cs Redesign

**Problem:** Current script-based approach loses stream structure.

**Option A - Hybrid Approach (Recommended):**

```csharp
// Execute script normally
session.PowerShell.AddScript(script);
var results = session.PowerShell.Invoke();

// Capture from structured streams
var stdout = new StringBuilder();
foreach (var result in results)
{
    stdout.AppendLine(result?.ToString() ?? "");
}

var stderr = new StringBuilder();
foreach (var error in session.PowerShell.Streams.Error)
{
    stderr.AppendLine(error.ToString());
}

var warnings = new StringBuilder();
foreach (var warning in session.PowerShell.Streams.Warning)
{
    warnings.AppendLine(warning.ToString());
}

var verbose = new StringBuilder();
foreach (var v in session.PowerShell.Streams.Verbose)
{
    verbose.AppendLine(v.ToString());
}

var debug = new StringBuilder();
foreach (var d in session.PowerShell.Streams.Debug)
{
    debug.AppendLine(d.ToString());
}

var information = new StringBuilder();
foreach (var i in session.PowerShell.Streams.Information)
{
    information.AppendLine(i.ToString());
}

// Store in environment variables
$env:{name}_stdout = stdout.ToString()
$env:{name}_stderr = stderr.ToString()
$env:{name}_warnings = warnings.ToString()
$env:{name}_verbose = verbose.ToString()
$env:{name}_debug = debug.ToString()
$env:{name}_information = information.ToString()
```

**Option B - Keep Script-Based but Add Stream Capture:**

Keep current `2>&1` redirection for stdout/stderr, but ADD:

```csharp
// After script execution, also capture preference-controlled streams
var warningCount = session.PowerShell.Streams.Warning.Count;
var verboseCount = session.PowerShell.Streams.Verbose.Count;
var debugCount = session.PowerShell.Streams.Debug.Count;
var infoCount = session.PowerShell.Streams.Information.Count;

// Include in summary
summary.AppendLine($"Verbose:  {verboseCount,3} messages");
summary.AppendLine($"Debug:    {debugCount,3} messages");
summary.AppendLine($"Info:     {infoCount,3} messages");
```

## Stream Redirection Operators (Reference)

PowerShell script-based redirection syntax:

```powershell
command 1> stdout.txt   # Output stream
command 2> stderr.txt   # Error stream
command 3> warn.txt     # Warning stream
command 4> verbose.txt  # Verbose stream
command 5> debug.txt    # Debug stream
command 6> info.txt     # Information stream
command *> all.txt      # All streams

command 2>&1            # Redirect errors to output stream (merging)
command 4>&2            # Redirect verbose to error stream
```

**Note:** Redirection converts structured records to strings. For structured access, use `PowerShell.Streams.*` collections.

## Testing Plan

### Test Script for All Six Streams

```powershell
# Test all six PowerShell streams
Write-Output "Output stream (1)"
Write-Error "Error stream (2)" -ErrorAction Continue
Write-Warning "Warning stream (3)"
Write-Verbose "Verbose stream (4)" -Verbose
Write-Debug "Debug stream (5)" -Debug
Write-Information "Information stream (6)"
Write-Host "Host writes to Information stream (6)"

# Show counts
"Completed stream test"
```

### Expected Output with Enhanced PwshTool

```
Output stream (1)
Completed stream test

Errors:
  Error stream (2)

Warnings:
  Warning stream (3)

Verbose:
  Verbose stream (4)

Debug:
  Debug stream (5)

Information:
  Information stream (6)
  Host writes to Information stream (6)
```

## Show-Session Fix

**Root Cause:** Write-Host writes to Information stream, which PwshTool doesn't capture.

**Fix:** Add Information stream capture to PwshTool.FormatResults (see Implementation section above).

**Alternative:** Convert Show-Session to use Write-Output instead of Write-Host.

**Recommendation:** Fix PwshTool (captures all streams) > Fixing Show-Session (one-off).

## Performance Considerations

**Stream checking overhead:** Negligible (< 1ms per stream check)

**Token cost:** ~200-300 additional tokens for expanded output formatting

**Memory:** PSDataCollection is already allocated by PowerShell runtime, we're just reading it

**Recommendation:** Enable all six streams by default. Benefits outweigh minimal cost.

## Output Formatting (from IMPLEMENTATION_OUTLINE.md:163-193)

**Challenge:** Convert PSObject to string for MCP response

### Pattern 1: Use PowerShell's Out-String

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

### Pattern 2: BaseObject check (current PwshTool pattern)

```csharp
if (obj.BaseObject is string str)
    return str;
else
    return obj.ToString();  // Uses PowerShell's default ToString
```

**Critical Detail (from IMPLEMENTATION_OUTLINE.md:380-385):** Always set Width parameter to prevent truncation:
```csharp
ps.AddCommand("Out-String");
ps.AddParameter("Width", 250);  // Default can truncate long output
```

Current PwshTool.cs implementation uses automatic Out-String detection (lines 40-54) which is superior to manual formatting.

## References

**Project Documentation:**
- IMPLEMENTATION_OUTLINE.md Section 3 (Stream Handling)
- IMPLEMENTATION_OUTLINE.md Section 10.1 (Stream Clearing)

**Microsoft Learn:**
- [Configure runbook output and message streams](https://learn.microsoft.com/en-us/azure/automation/automation-runbook-output-and-messages)
- [PSDataStreams Class](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.psdatastreams?view=powershellsdk-7.4.0)
- [Runspace04 Sample](https://learn.microsoft.com/en-us/powershell/scripting/developer/hosting/runspace04-sample?view=powershell-7.5)
- [PipelineResultTypes Enum](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.pipelineresulttypes)
- [RedirectionStream Enum](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.language.redirectionstream?view=powershellsdk-7.4.0)
- [Out-String Cmdlet](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/out-string)

## Next Steps

1. Update PwshTool.FormatResults to capture all six streams
2. Test with stream test script
3. Verify Show-Session works (Information stream capture)
4. Decide on DevRunTool approach (Option A vs Option B)
5. Update tool descriptions in MCP server to mention complete stream capture
6. Document stream behavior in README.md

## Edge Cases

**Progress stream:** Rarely used (auto-generated activity tracking). Recommend skip for now, add if needed.

**Empty streams:** Safe to check `.Count > 0` before iterating.

**Null streams:** PSDataStreams properties are never null, but items can be.

**Preference variables:** Streams capture regardless of preference settings. Preferences only control console display.

**Stream clearing:** Current `pwsh.Streams.ClearStreams()` in finally block is correct - clears all six streams.

**CRITICAL (from IMPLEMENTATION_OUTLINE.md:360-365):** ALWAYS clear streams between uses to prevent error accumulation:
```csharp
// From PowerAuger pattern - prevents stream accumulation across calls
pwsh.Commands.Clear();
pwsh.Streams.ClearStreams();  // Critical for session reuse!
```

This is already implemented correctly in PwshTool.cs:65-66 and SessionManager.cs:117-118.
