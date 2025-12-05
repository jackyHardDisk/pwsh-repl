---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Export-ToFile

## SYNOPSIS
Save results to file in various formats.

## SYNTAX

```
Export-ToFile -InputObject <Object> [-Path] <String> [-Format <String>] [-Append] [-NoClobber]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Exports pipeline input to a file in specified format (text, csv, json, xml).
Provides a consistent interface for saving analysis results with automatic
format detection from file extension.

Particularly useful for saving analysis results for later review, sharing
with team members, or importing into other tools.

## EXAMPLES

### EXAMPLE 1

```powershell
Find-Errors build.log | Export-ToFile errors.csv
# Auto-detects CSV format from extension
```

### EXAMPLE 2

```powershell
Get-BuildError gcc.log | Export-ToFile build-errors.json -Format json
# Explicit JSON format
```

### EXAMPLE 3

```powershell
Find-Warnings app.log | Export-ToFile warnings.txt -Format text
# Plain text output (one item per line)
```

### EXAMPLE 4

```powershell
Get-Process | Select-Object Name, CPU | Export-ToFile processes.xml
# Export as XML
```

### EXAMPLE 5

```powershell
Find-Errors test1.log | Export-ToFile all-errors.txt -Append
PS> Find-Errors test2.log | Export-ToFile all-errors.txt -Append
# Accumulate errors from multiple sources
```

## PARAMETERS

### -InputObject
Objects to export.

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

### -Path
Output file path.
Format auto-detected from extension if not specified.

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

### -Format
Output format: 'text', 'csv', 'json', 'xml'.
Auto-detects from extension if omitted.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Auto
Accept pipeline input: False
Accept wildcard characters: False
```

### -Append
Append to file instead of overwriting.
Only applies to text format.

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

### -NoClobber
Fail if file already exists instead of overwriting.

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
Creates parent directory if it doesn't exist.
CSV format requires objects (not plain strings).

## RELATED LINKS
