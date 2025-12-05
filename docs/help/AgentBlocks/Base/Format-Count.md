---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Format-Count

## SYNOPSIS
Format items with count prefix.

## SYNTAX

```
Format-Count [-InputObject] <Object> [[-Width] <Int32>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Formats frequency count results as "count x: item" with aligned counts.
Useful for showing aggregated error/warning counts from build logs or test output.

Expects input objects with Count and Item properties (typically from Measure-Frequency
or Group-Object with count).
Passes through objects without these properties unchanged.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-Content build.log | Select-String "error" | Measure-Frequency | Format-Count
    42x: Cannot find module 'foo'
    12x: Undefined variable 'bar'
     3x: Type mismatch in assignment
```

### EXAMPLE 2

```powershell
Find-Errors build.log | Format-Count -Width 4
  42x: Cannot find module 'foo'
  12x: Undefined variable 'bar'
```

### EXAMPLE 3

```powershell
"error: foo", "error: bar", "error: foo" | Measure-Frequency | Format-Count
     2x: error: foo
     1x: error: bar
```

## PARAMETERS

### -InputObject
Object with Count and Item (or Name) properties from Measure-Frequency or Group-Object.

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

### -Width
Width of count column for alignment (default: 6).
Adjust based on expected count magnitude.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 6
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
Pipeline-friendly: Processes each input object individually for streaming efficiency.

## RELATED LINKS
