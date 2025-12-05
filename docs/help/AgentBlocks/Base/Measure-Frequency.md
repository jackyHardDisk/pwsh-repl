---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Measure-Frequency

## SYNOPSIS
Count occurrences and sort by frequency.

## SYNTAX

```
Measure-Frequency -InputObject <Object> [[-Property] <String>] [-Ascending]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Counts how many times each unique item appears in the input stream and returns
results sorted by frequency (most common first).
This is effectively Group-By with
a more intuitive name for frequency analysis tasks.

Particularly useful for analyzing error messages, log entries, or test failures
to quickly identify the most common issues.

## EXAMPLES

### EXAMPLE 1

```powershell
"error", "warning", "error", "info", "error" | Measure-Frequency
     3x: error
     1x: warning
     1x: info
```

### EXAMPLE 2

```powershell
Get-Content build.log | Select-String "error:" | Measure-Frequency
    42x: error: Cannot find module
    12x: error: Undefined variable
     3x: error: Type mismatch
```

### EXAMPLE 3

```powershell
Get-Process | Measure-Frequency -Property ProcessName | Select-Object -First 5
    15x: chrome
     8x: node
     5x: pwsh
     3x: code
     2x: explorer
```

### EXAMPLE 4

```powershell
Import-Csv errors.csv | Measure-Frequency -Property ErrorCode | Format-Count -Width 4
  245x: E001
   89x: E042
   12x: E404
```

## PARAMETERS

### -InputObject
Items to count.
Each unique item becomes one result row.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Property
Optional property to group by.
If omitted, groups by the entire object.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Ascending
Sort by frequency ascending (least common first) instead of descending.

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
This is an alias-style wrapper around Group-By for better discoverability.
Use this when your intent is frequency analysis rather than general grouping.

## RELATED LINKS
