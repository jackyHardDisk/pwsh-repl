---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Group-Similar

## SYNOPSIS
Group similar items using fuzzy string matching.

## SYNTAX

```
Group-Similar [-InputObject] <Object> [[-Threshold] <Double>] [[-Property] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Groups items by similarity using Jaro-Winkler distance.
Items above the similarity
threshold are grouped together, with the first item in each group becoming the exemplar.

Particularly useful for grouping error messages that differ only in variable names,
line numbers, or other minor variations.

## EXAMPLES

### EXAMPLE 1

```powershell
$errors = @(
    "file1.cs(10): error CS0103: The name 'foo' does not exist",
    "file2.cs(42): error CS0103: The name 'bar' does not exist",
    "file3.cs(55): error CS0168: Variable declared but not used"
)
PS> $errors | Group-Similar -Threshold 0.80
Count Example                                                    Items
----- -------                                                    -----
    2 file1.cs(10): error CS0103: The name 'foo' does not exist {...}
    1 file3.cs(55): error CS0168: Variable declared but not used {...}
```

### EXAMPLE 2

```powershell
Get-StreamData -Name "build" -Stream Error | Group-Similar | Format-Count
     42x: error CS0103: The name 'X' does not exist
      8x: error CS0168: Variable declared but not used
```

## PARAMETERS

### -InputObject
Items to group.
Can be strings or objects (use -Property for objects).

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

### -Threshold
Similarity threshold (0.0-1.0).
Items with similarity \>= threshold are grouped together.
Default: 0.85 (85% similar).

```yaml
Type: Double
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 0.85
Accept pipeline input: False
Accept wildcard characters: False
```

### -Property
Property name to compare for object inputs.
If omitted, compares entire object as string.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
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
Groups are sorted by count (descending).
Each group includes:
- Count: Number of items in group
- Example: Exemplar item (first in group)
- Items: All items in the group

## RELATED LINKS
