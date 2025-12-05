---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Show-StreamSummary

## SYNOPSIS
Display formatted summary of Invoke-DevRun stream data.

## SYNTAX

```
Show-StreamSummary [-Name] <String> [-Streams <String[]>] [-TopCount <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Shows frequency analysis summary for selected PowerShell streams from Invoke-DevRun results.
Displays count, unique count, and top items for each requested stream.

Mimics Invoke-DevRun's built-in summary but allows custom stream selection and post-hoc analysis.

## EXAMPLES

### EXAMPLE 1

```powershell
Show-StreamSummary -Name "build"
Errors: 3 (2 unique)
```

Top Errors:
     2x: file.cs(10): error CS0103
     1x: file.cs(42): error CS0168

Warnings: 1 (1 unique)

Top Warnings:
     1x: file.cs(55): warning CS0169

### EXAMPLE 2

```powershell
Show-StreamSummary -Name "build" -Streams Error,Warning,Verbose
```

### EXAMPLE 3

```powershell
Show-StreamSummary -Name "test" -Streams Error -TopCount 10
```

## PARAMETERS

### -Name
Name used in Invoke-DevRun (e.g., "build" for Invoke-DevRun -Name build).

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

### -Streams
Streams to include in summary.
Default: Error, Warning (matches Invoke-DevRun default).

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: @("Error", "Warning")
Accept pipeline input: False
Accept wildcard characters: False
```

### -TopCount
Number of top items to show per stream.
Default: 5.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 5
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
Requires Invoke-DevRun to have been executed with stream storage enabled (default behavior).
Use Get-StreamData for raw stream access and custom analysis pipelines.

## RELATED LINKS
