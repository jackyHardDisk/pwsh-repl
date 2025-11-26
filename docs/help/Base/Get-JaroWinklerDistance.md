---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Get-JaroWinklerDistance

## SYNOPSIS
Calculate Jaro-Winkler similarity distance between two strings.

## SYNTAX

```
Get-JaroWinklerDistance [-String1] <String> [-String2] <String> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Computes Jaro-Winkler distance (0.0 to 1.0) measuring string similarity.
Values closer to 1.0 indicate higher similarity.
Useful for fuzzy matching
of error messages, file names, or other text where exact matches aren't required.

Jaro-Winkler gives higher scores to strings with matching prefixes, making it
particularly effective for matching error messages with similar patterns.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-JaroWinklerDistance "The name 'foo' does not exist" "The name 'bar' does not exist"
0.924
```

### EXAMPLE 2

```powershell
Get-JaroWinklerDistance "error CS0103" "error CS0168"
0.733
```

## PARAMETERS

### -String1
First string to compare.

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

### -String2
Second string to compare.

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
Returns 1.0 for identical strings, 0.0 for completely dissimilar strings.
Threshold of 0.85 works well for grouping similar error messages.

## RELATED LINKS
