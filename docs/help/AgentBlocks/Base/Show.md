---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Show

## SYNOPSIS
Format and limit output with multiple format options.

## SYNTAX

```
Show [-InputObject] <Object> [[-Format] <String>] [[-Top] <Int32>] [[-AutoSize] <Boolean>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Formats pipeline input in various ways (count, table, json, list) and optionally
limits results.
This is a convenience wrapper around PowerShell's built-in formatting
cmdlets with sensible defaults for common analysis tasks.

Particularly useful as the final step in analysis pipelines to present results
in a readable format without overwhelming output.

## EXAMPLES

### EXAMPLE 1

```powershell
Find-Errors build.log | Show -Format count -Top 5
    42x: Cannot find module 'foo'
    12x: Undefined variable 'bar'
     3x: Type mismatch
     2x: Missing semicolon
     1x: Invalid syntax
```

### EXAMPLE 2

```powershell
Get-BuildError gcc.log | Show -Format table
File          Line Col Message
----          ---- --- -------
main.c        42   15  undefined reference to 'foo'
utils.c       128  8   conflicting types for 'bar'
```

### EXAMPLE 3

```powershell
Get-Process | Select-Object Name, CPU | Show -Format json -Top 3
[
    {"Name": "chrome", "CPU": 142.5},
    {"Name": "code", "CPU": 89.2},
    {"Name": "pwsh", "CPU": 12.1}
]
```

### EXAMPLE 4

```powershell
Find-Warnings app.log | Show -Top 10
# Show top 10 warnings in table format (default)
```

## PARAMETERS

### -InputObject
Objects to format and display.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Format
Output format: 'count', 'table', 'json', 'list'.
Default is 'table'.
- count: Use with Count/Item objects from Format-Count
- table: Tabular format (Format-Table)
- json: JSON format (ConvertTo-Json)
- list: List format (Format-List)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: Table
Accept pipeline input: False
Accept wildcard characters: False
```

### -Top
Limit output to first N items.
Useful for large result sets.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -AutoSize
Auto-size table columns.
Only applies to 'table' format.
Default is $true.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
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
The 'count' format expects objects with Count and Item properties (from Format-Count).
For other formats, any PSObject is accepted.

## RELATED LINKS
