---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Clear-Stored

## SYNOPSIS
Clear stored results from BrickStore.

## SYNTAX

```
Clear-Stored [[-Name] <String>] [-Patterns] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Removes stored analysis results from BrickStore.
Useful for cleaning up
after analysis sessions or freeing memory.

Can clear specific result by name or all results.

## EXAMPLES

### EXAMPLE 1

```powershell
Clear-Stored -Name "build"
Cleared stored result: build
```

### EXAMPLE 2

```powershell
Clear-Stored
Cleared all stored results (3 items)
```

### EXAMPLE 3

```powershell
Clear-Stored -Patterns
Cleared all stored results and patterns
WARNING: This removes all learned patterns!
```

## PARAMETERS

### -Name
Name of specific result to clear.
If omitted, clears all results.

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

### -Patterns
Also clear all learned patterns (use with caution).

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
Does not affect saved .brickyard.json files.
Use Save-Project before clearing if you want to preserve patterns.

## RELATED LINKS
