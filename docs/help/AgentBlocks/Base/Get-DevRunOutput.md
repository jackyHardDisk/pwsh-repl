---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Get-DevRunOutput

## SYNOPSIS
Retrieve cached output from previous Invoke-DevRun or pwsh tool execution.

## SYNTAX

```
Get-DevRunOutput [-Name] <String> [[-Stream] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Gets full output from cached execution.
Useful for detailed analysis after
reviewing condensed summary from Invoke-DevRun.

All pwsh tool executions (with or without mode='Invoke-DevRun') are auto-cached
and retrievable via this function.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-DevRunOutput -Name 'build' -Stream 'Error'
# Returns: Array of all error messages from 'build' execution
```

### EXAMPLE 2

```powershell
Get-DevRunOutput -Name 'build' -Stream 'All'
# Returns: Complete cache entry with Script, Timestamp, and all streams
```

### EXAMPLE 3

```powershell
Get-DevRunOutput -Name 'build' -Stream 'Stdout' | Select-String 'warning'
# Pipe stdout to further analysis
```

## PARAMETERS

### -Name
Cache name to retrieve.
Use Get-DevRunCacheList to see available names.

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

### -Stream
Which output to retrieve:
- Stdout: Regular command output (default)
- Stderr: Error stream output
- Error, Warning, Verbose, Debug, Information, Progress: PowerShell streams
- All: Complete cached object with all data and metadata

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: Stdout
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
Use Export-Environment to save to disk.

## RELATED LINKS
