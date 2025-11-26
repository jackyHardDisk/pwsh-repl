---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Select-TextBetween

## SYNOPSIS
Select text between two marker strings.

## SYNTAX

```
Select-TextBetween -InputObject <String> [-Start] <String> [-End] <String> [-Greedy] [-IncludeMarkers]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Extracts substring between start and end markers.
Useful for parsing structured
text like XML-ish formats, quoted strings, or delimited sections in logs.

Supports greedy (longest match) and non-greedy (shortest match) modes.
Default is non-greedy to extract first occurrence.

## EXAMPLES

### EXAMPLE 1

```powershell
"The <b>quick</b> brown fox" | Select-TextBetween -Start "<b>" -End "</b>"
quick
```

### EXAMPLE 2

```powershell
'Error: "file not found" in module' | Select-TextBetween -Start '"' -End '"'
file not found
```

### EXAMPLE 3

```powershell
Get-Content log.txt | Select-TextBetween -Start "[ERROR]" -End "[/ERROR]"
# Extracts error details between markers
```

### EXAMPLE 4

```powershell
"start{outer{inner}outer}end" | Select-TextBetween -Start "{" -End "}" -Greedy
outer{inner}outer
```

### EXAMPLE 5

```powershell
"start{outer{inner}outer}end" | Select-TextBetween -Start "{" -End "}"
outer{inner
```

## PARAMETERS

### -InputObject
Text to search.

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

### -Start
Starting marker string.
The marker itself is excluded from output.

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

### -End
Ending marker string.
The marker itself is excluded from output.

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

### -Greedy
Use greedy matching (extract longest possible match).
Default is non-greedy.

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

### -IncludeMarkers
Include start and end markers in the output.

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
Returns $null for lines without both markers.
For nested markers, use -Greedy carefully or process with regex instead.

## RELATED LINKS
