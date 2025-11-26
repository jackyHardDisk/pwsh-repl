---
external help file: LoraxMod-help.xml
Module Name: LoraxMod
online version:
schema: 2.0.0
---

# Stop-TreeSitterSession

## SYNOPSIS
Stop REPL session and cleanup resources

## SYNTAX

```
Stop-TreeSitterSession [[-SessionId] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Stops REPL process started with Start-TreeSitterSession -AsProcess.
Kills process, disposes resources, and removes session from tracker.

## EXAMPLES

### EXAMPLE 1

```powershell
Stop-TreeSitterSession
# Stops default session
```

### EXAMPLE 2

```powershell
Stop-TreeSitterSession -SessionId 'analysis1'
# Stops named session
```

## PARAMETERS

### -SessionId
Session identifier to stop.
Default: 'default'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: Default
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
Always stop sessions when done to free resources and cleanup temp files.

## RELATED LINKS
