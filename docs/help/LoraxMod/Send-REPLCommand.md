---
external help file: LoraxMod-help.xml
Module Name: LoraxMod
online version:
schema: 2.0.0
---

# Send-REPLCommand

## SYNOPSIS
Send command to interactive REPL session and read response

## SYNTAX

```
Send-REPLCommand [[-SessionId] <String>] [-Command] <String> [[-TimeoutSeconds] <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Sends JavaScript command to REPL session started with Start-TreeSitterSession -AsProcess.
Reads output from REPL stdout.

## EXAMPLES

### EXAMPLE 1

```powershell
$repl = Start-TreeSitterSession -Language c -AsProcess
Send-REPLCommand -Command 'root.childCount'
# Returns: 3
```

### EXAMPLE 2

```powershell
Send-REPLCommand -SessionId 'analysis1' -Command 'root.type'
#Returns node type
```

## PARAMETERS

### -SessionId
Session identifier from Start-TreeSitterSession.
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

### -Command
JavaScript command to execute in REPL context

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

### -TimeoutSeconds
Seconds to wait for response.
Default: 5

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 5
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
REPL must be started with -AsProcess switch.
Commands execute in async context with lorax, parser, tree, root globals available.

## RELATED LINKS
