---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Select-Column

## SYNOPSIS
Select Nth column from delimited text.

## SYNTAX

```
Select-Column -InputObject <String> [-Column] <Int32> [-Delimiter <String>] [-Trim <Boolean>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Extracts a specific column from delimited text (whitespace, comma, tab, etc.).
Useful for parsing structured log output, CSV-like data, or tabular command output.

Column numbers are 1-indexed (first column is 1).
Supports negative indexing
(-1 for last column, -2 for second-to-last, etc.).

## EXAMPLES

### EXAMPLE 1

```powershell
"ERROR 2024-11-15 Database connection failed" | Select-Column 1
ERROR
```

### EXAMPLE 2

```powershell
Get-Content access.log | Select-Column -Column 4
# Extract 4th column from each log line (e.g., HTTP status code)
```

### EXAMPLE 3

```powershell
"apple,banana,cherry,date" | Select-Column -Column 3 -Delimiter ","
cherry
```

### EXAMPLE 4

```powershell
"one    two    three    four" | Select-Column -Column -1
four
```

### EXAMPLE 5

```powershell
Get-Content errors.txt | Select-Column 2 | Measure-Frequency
# Count frequency of values in 2nd column
```

## PARAMETERS

### -InputObject
Text line to parse.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Column
Column number to extract (1-indexed).
Use negative numbers to count from end.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Delimiter
Delimiter pattern.
Default is whitespace (\s+).
Use ',' for CSV, '\t' for TSV, etc.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: \s+
Accept pipeline input: False
Accept wildcard characters: False
```

### -Trim
Trim whitespace from extracted value.
Default is $true.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: True
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
Returns $null if column doesn't exist.
Use Select-Object -First N | Select-Column for preview of large files.

## RELATED LINKS
