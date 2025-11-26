---
external help file: LoraxMod-help.xml
Module Name: LoraxMod
online version:
schema: 2.0.0
---

# Stop-LoraxStreamParser

## SYNOPSIS
Gracefully shutdown streaming parser session

## SYNTAX

```
Stop-LoraxStreamParser [[-SessionId] <String>] [[-TimeoutSeconds] <Int32>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Sends shutdown command to parser process, retrieves final statistics,
and cleans up session resources.
Waits for graceful exit or forcibly
terminates if timeout exceeded.

## EXAMPLES

### EXAMPLE 1

```powershell
Stop-LoraxStreamParser
# Stops default session
```

### EXAMPLE 2

```powershell
Stop-LoraxStreamParser -SessionId 'batch1'
# Stops named session
```

### EXAMPLE 3

```powershell
$stats = Stop-LoraxStreamParser
Write-Host "Processed $($stats.FilesProcessed) files in $($stats.DurationSeconds)s"
# Capture and display statistics
```

## PARAMETERS

### -SessionId
Parser session ID to stop.
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

### -TimeoutSeconds
Seconds to wait for graceful shutdown.
Default: 5

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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
Always call this function to properly cleanup parser sessions.
Returns final statistics including files processed and error count.

Performance: Streaming parser provides 40x+ speedup vs per-file spawning.
Use streaming for batch processing (100+ files).
Use REPL for exploration.

## RELATED LINKS

[Start-LoraxStreamParser](Start-LoraxStreamParser.md)

[Invoke-LoraxStreamQuery](Invoke-LoraxStreamQuery.md)

