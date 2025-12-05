---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Invoke-DevRun

## SYNOPSIS
Execute PowerShell script with stream capture, caching, and condensed summary output.

## SYNTAX

```
Invoke-DevRun [-Script] <String> [-Name] <String> [[-Streams] <String[]>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Runs PowerShell script in current session, captures all output streams, stores in
$global:DevRunCache, and returns token-efficient summary (error/warning counts, top issues).

Auto-caches ALL executions for later retrieval via Get-DevRunOutput.
Use this for
build commands, tests, linting - any script where you want results summarized but
need full output available for analysis.

Default behavior:
- Returns condensed 15-line summary (99% token reduction vs full output)
- Caches full output in $global:DevRunCache\[name\]
- Shows Error and Warning streams in summary
- Mutes Verbose, Debug, Information (available in cache)

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-DevRun -Script 'dotnet build' -Name 'build'
# Returns:
# Script: dotnet build
#
# Errors: 12  (3 unique)
# Top Errors:
#   8x: CS0246: The type or namespace name 'Foo' could not be found
#   3x: CS1002: ; expected
#   1x: CS0103: The name 'bar' does not exist
#
# Warnings: 5  (2 unique)
# ...
# Output: 847 lines
#
# Stored: $global:DevRunCache['build']
# Retrieve: Get-DevRunOutput -Name 'build' -Stream 'Error'
```

### EXAMPLE 2

```powershell
Invoke-DevRun -Script 'Get-Process | Where CPU -gt 100' -Name 'highcpu'
# Executes and caches. Full output available via Get-DevRunOutput.
```

### EXAMPLE 3

```powershell
Invoke-DevRun -Script 'npm test' -Name 'test' -Streams @('Error','Warning','Verbose')
# Include Verbose stream in summary
```

## PARAMETERS

### -Script
PowerShell script to execute.
Can be command, pipeline, or multi-line script.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name
Cache name for storing results.
REQUIRED.
Results stored in $global:DevRunCache\[name\] with Script, Timestamp, and all stream data.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Streams
PowerShell streams to include in summary.
Default: Error, Warning.
Valid: Error, Warning, Verbose, Debug, Information, Progress, Output

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: @('Error', 'Warning')
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

## NOTES
Cache persists for session lifetime.
Use Clear-DevRunCache to free memory.
Use Export-Environment to save cache to disk for later sessions.

## RELATED LINKS
