---
external help file: LoraxMod-help.xml
Module Name: LoraxMod
online version:
schema: 2.0.0
---

# Invoke-LoraxStreamQuery

## SYNOPSIS
Send parse or query commands to streaming parser session

## SYNTAX

```
Invoke-LoraxStreamQuery [[-SessionId] <String>] [[-Command] <String>] [[-FilePath] <String>]
 [[-Query] <String>] [[-Context] <Object>] [[-TimeoutSeconds] <Int32>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Sends JSON commands to a running streaming parser process and returns parsed results.
Supports pipeline input for batch processing multiple files efficiently.

Available commands:
- parse: Parse file and extract code segments using loraxmod
- query: Parse file and run tree-sitter query
- ping: Check parser health and get stats

## EXAMPLES

### EXAMPLE 1

```powershell
Start-LoraxStreamParser
Invoke-LoraxStreamQuery -File "sample.c" -Command parse
Stop-LoraxStreamParser
```

### EXAMPLE 2

```powershell
Start-LoraxStreamParser -SessionId 'batch'
Get-ChildItem *.c -Recurse | Invoke-LoraxStreamQuery -SessionId 'batch' -Command parse
Stop-LoraxStreamParser -SessionId 'batch'
```

### EXAMPLE 3

```powershell
$query = '(function_definition name: (identifier) @func)'
Invoke-LoraxStreamQuery -File "app.c" -Command query -Query $query
```

## PARAMETERS

### -SessionId
Parser session ID from Start-LoraxStreamParser.
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
Command type: parse, query, or ping.
Default: 'parse'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: Parse
Accept pipeline input: False
Accept wildcard characters: False
```

### -FilePath
File path to process. Accepts pipeline input. Aliases: File, FullName, Path

```yaml
Type: String
Parameter Sets: (All)
Aliases: FullName, Path, File

Required: False
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Query
Tree-sitter query string (required for 'query' command)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Context
Extraction context object for filtering results

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TimeoutSeconds
Seconds to wait for parser response.
Default: 30

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: 30
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
Parser session must be started with Start-LoraxStreamParser first.
Use pipeline for efficient batch processing of multiple files.

Performance: Single session eliminates per-file process spawn overhead.
Achieves 40x+ speedup for batch processing vs spawning node per file.
Best for processing 100+ files.
For exploration, use REPL functions.

## RELATED LINKS

[Start-LoraxStreamParser](Start-LoraxStreamParser.md)

[Stop-LoraxStreamParser](Stop-LoraxStreamParser.md)

