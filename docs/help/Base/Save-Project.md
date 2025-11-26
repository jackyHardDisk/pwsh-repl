---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Save-Project

## SYNOPSIS
Export learned patterns and state to .brickyard.json file.

## SYNTAX

```
Save-Project [[-Path] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Saves the current BrickStore state (patterns, results, chains) to a JSON file
in the project directory.
This allows patterns learned for a specific project
to persist across sessions and be shared with team members.

The .brickyard.json file can be committed to version control to share
learned patterns with other developers or AI agents working on the project.

## EXAMPLES

### EXAMPLE 1

```powershell
Save-Project
Saved 15 patterns to .brickyard.json
```

### EXAMPLE 2

```powershell
Save-Project -Path "config/brickyard.json"
# Save to custom location
```

## PARAMETERS

### -Path
Output file path.
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
File is human-readable JSON for easy review and editing.
Includes metadata: created date, pattern count, etc.

## RELATED LINKS
