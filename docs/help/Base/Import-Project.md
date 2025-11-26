---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Import-Project

## SYNOPSIS
Import patterns and state from .brickyard.json file.

## SYNTAX

```
Import-Project [[-Path] <String>] [-Merge] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Loads previously saved patterns from a .brickyard.json file into the current
BrickStore.
This enables restoring learned patterns across sessions or
importing patterns from other projects/team members.

Automatically called during module import if .brickyard.json exists in
current directory.

## EXAMPLES

### EXAMPLE 1

```powershell
Import-Project
Loaded 15 patterns from .brickyard.json
```

### EXAMPLE 2

```powershell
Import-Project -Path "~/shared-patterns.json" -Merge
# Merge patterns from shared library
```

## PARAMETERS

### -Path
Input file path.
Defaults to .brickyard.json in current directory.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: .brickyard.json
Accept pipeline input: False
Accept wildcard characters: False
```

### -Merge
Merge with existing patterns instead of replacing.
Default is replace.

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
Validates pattern syntax before loading.
Warns if patterns have duplicate names (when merging).

## RELATED LINKS
