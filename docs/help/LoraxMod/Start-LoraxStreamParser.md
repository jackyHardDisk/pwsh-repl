---
external help file: LoraxMod-help.xml
Module Name: LoraxMod
online version:
schema: 2.0.0
---

# Start-LoraxStreamParser

## SYNOPSIS
Initialize a long-running Node.js streaming parser process

## SYNTAX

```
Start-LoraxStreamParser [[-SessionId] <String>] [[-ParserScript] <String>] [[-TimeoutSeconds] <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Starts a Node.js streaming parser process that accepts JSON commands via stdin
and returns JSON responses via stdout.
Optimized for batch processing of large
file sets by eliminating per-file process spawn overhead (40x+ speedup).

The parser session is stored in memory and can be reused for multiple parse/query
operations until explicitly stopped with Stop-LoraxStreamParser.

## EXAMPLES

### EXAMPLE 1

```powershell
Start-LoraxStreamParser
# Starts default parser session
```

### EXAMPLE 2

```powershell
Start-LoraxStreamParser -SessionId 'batch1'
# Starts named session for parallel processing
```

### EXAMPLE 3

```powershell
$sessionId = Start-LoraxStreamParser -SessionId 'custom'
Get-ChildItem *.c | Invoke-LoraxStreamQuery -SessionId $sessionId -Command parse
Stop-LoraxStreamParser -SessionId $sessionId
```

## PARAMETERS

### -SessionId
Unique identifier for this parser session.
Use same ID with Invoke-LoraxStreamQuery
and Stop-LoraxStreamParser.
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

### -ParserScript
Path to Node.js streaming parser script.
Default: bundled streaming_query_parser.js

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: "$script:ModuleRoot/parsers/streaming_query_parser.js"
Accept pipeline input: False
Accept wildcard characters: False
```

### -TimeoutSeconds
Seconds to wait for parser initialization.
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
Use REPL functions (Start-TreeSitterSession) for interactive exploration.
Use streaming functions for high-performance batch processing.

## RELATED LINKS

[Invoke-LoraxStreamQuery](Invoke-LoraxStreamQuery.md)

[Stop-LoraxStreamParser](Stop-LoraxStreamParser.md)

