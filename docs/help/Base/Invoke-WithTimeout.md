---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Invoke-WithTimeout

## SYNOPSIS
Execute a script block with a timeout, using PowerShell-conventional error handling.

## SYNTAX

```
Invoke-WithTimeout [-ScriptBlock] <ScriptBlock> [-TimeoutSeconds <Int32>] [-ArgumentList <Object[]>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Wraps script block execution in a timeout mechanism using PowerShell jobs.
Designed for use in command chains where a problematic step might hang.

Follows PowerShell conventions:
- Outputs directly to pipeline on success
- Throws terminating errors on failure or timeout
- Respects -ErrorAction parameter for error handling
- Integrates with try/catch and -ErrorVariable

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-WithTimeout { python slow_script.py } -TimeoutSeconds 10 | Find-Errors
```

```output
Execute a potentially slow command with 10-second timeout, piping output to Find-Errors.
```

### EXAMPLE 2

```powershell
try {
    Invoke-WithTimeout { dotnet build } -TimeoutSeconds 60 |
        Find-Errors | Measure-Frequency | Format-Count
} catch {
    Write-Warning "Build failed or timed out: $_"
}
```

```output
Pipeline with error handling using try/catch.
```

### EXAMPLE 3

```powershell
Invoke-WithTimeout { flaky-command } -ErrorAction Continue |
    Find-Errors
```

```output
Continue pipeline even if command fails or times out.
```

### EXAMPLE 4

```powershell
Invoke-WithTimeout { dotnet build } -ErrorVariable buildErrors -ErrorAction SilentlyContinue |
    Find-Errors
```

if ($buildErrors) {
    Write-Warning "Build had $($buildErrors.Count) error(s)"
}

Capture errors in variable for inspection without stopping pipeline.

### EXAMPLE 5

```powershell
try {
    $results = Invoke-WithTimeout { Get-Content large.log } -TimeoutSeconds 5 |
        Find-Errors | Measure-Frequency
```

$results | Format-Count
} catch \[System.TimeoutException\] {
    Write-Warning "File read timed out - file too large"
} catch {
    Write-Warning "Other error: $_"
}

Handle timeout vs.
script failure differently using typed exception catching.

### EXAMPLE 6

```powershell
# Long-running build with extended timeout
try {
    Invoke-WithTimeout {
        cmake --build . --config Release
    } -TimeoutSeconds 300 | Find-Errors
} catch [System.TimeoutException] {
    Write-Error "Build exceeded 5 minute timeout"
    exit 1
}
```

```output
Extended timeout for slow operations.
```

## PARAMETERS

### -ScriptBlock
The script block to execute with timeout protection.

```yaml
Type: ScriptBlock
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TimeoutSeconds
Timeout duration in seconds.
Default: 30 seconds.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 30
Accept pipeline input: False
Accept wildcard characters: False
```

### -ArgumentList
Arguments to pass to the script block.

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### Object
### Direct pipeline output from the script block on success.
## NOTES
Implementation uses PowerShell jobs for true timeout capability.
Job overhead: ~100-200ms startup cost.

Error Types:
- System.TimeoutException: Execution exceeded timeout duration
- System.InvalidOperationException: Script block execution failed

Error Handling:
- Default: Terminating errors (stops execution)
- With -ErrorAction Continue: Non-terminating (pipeline continues)
- With -ErrorAction SilentlyContinue: Suppressed (no error output)
- With try/catch: Can catch and handle programmatically

Design Philosophy:
- Pipeline-first: Output flows naturally without property access
- Standard errors: Follows PowerShell error handling conventions
- Composable: Works seamlessly with AgentBricks functions
- Debuggable: Error messages include duration and source info

Performance Considerations:
- Job creation overhead makes this unsuitable for sub-second timeouts
- For batch operations, consider wrapping entire batch vs.
each item
- Error messages include execution duration for performance analysis

## RELATED LINKS

[about_Try_Catch_Finally](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_try_catch_finally)

[about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216)

