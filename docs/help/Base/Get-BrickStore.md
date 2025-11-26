---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Get-BrickStore

## SYNOPSIS
Display current BrickStore state (patterns, results, chains).

## SYNTAX

```
Get-BrickStore [[-Category] <String>] [-Detailed] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Shows overview of current BrickStore state including registered patterns,
stored results from dev-run, and saved analysis chains.

Useful for understanding what patterns and data are available for analysis.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-BrickStore
```

```output
BrickStore State
================
Patterns: 15
Results:  3
Chains:   0

Recent Patterns:
  ESLint (lint)
  Pytest (test)
  MSBuild-Error (error)
```

### EXAMPLE 2

```powershell
Get-BrickStore -Detailed
# Shows full pattern details
```

### EXAMPLE 3

```powershell
Get-BrickStore -Category error
# Show only error patterns
```

## PARAMETERS

### -Category
Filter patterns by category.

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

### -Detailed
Show detailed information including full regex patterns.

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
Returns summary object with counts and lists.

## RELATED LINKS
