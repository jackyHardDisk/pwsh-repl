---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Stop-BackgroundProcess

## SYNOPSIS
Stop background process and move output to DevRun cache.

## SYNTAX

```
Stop-BackgroundProcess [-Name] <String> [-KeepFiles] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Stops background process started with Invoke-BackgroundProcess and
moves captured output to DevRun cache ($global:DevRunCache) for analysis with Get-StreamData,
Get-BuildError, Group-BuildErrors, and all other Base/AgentBricks functions.

After stopping, output is stored in $global:DevRunCache using the same format as Invoke-DevRun,
making background process output compatible with all Base/AgentBricks analysis functions.

This makes background process output fully compatible with Invoke-DevRun workflows.

## EXAMPLES

### EXAMPLE 1

```powershell
Stop-BackgroundProcess -Name 'devserver'
Get-StreamData devserver Error | Find-Errors | Group-BuildErrors | Format-Count
```

### EXAMPLE 2

```powershell
# Stop and analyze build errors with regex + fuzzy hybrid
Stop-BackgroundProcess -Name 'build'
Get-StreamData build Error | Group-BuildErrors | Format-Count
```

### EXAMPLE 3

```powershell
# Stop and analyze with custom pattern
Stop-BackgroundProcess -Name 'server'
Get-StreamData server Output |
    Select-RegexMatch -Pattern 'Listening on: (?<url>https?://[^\s]+)' |
    Select-Object -ExpandProperty url
```

### EXAMPLE 4

```powershell
# Keep temp files for debugging
Stop-BackgroundProcess -Name 'test' -KeepFiles
```

## PARAMETERS

### -Name
Name of background process to stop.

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

### -KeepFiles
Keep temporary output files (don't clean up).
Useful for debugging.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
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
Output stored in DevRun cache ($global:DevRunCache) under key Name.
Compatible with all Base/AgentBricks analysis functions.

Returns summary with error counts and top errors (like Invoke-DevRun).

## RELATED LINKS
