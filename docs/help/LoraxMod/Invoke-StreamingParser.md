---
external help file: LoraxMod-help.xml
Module Name: LoraxMod
online version:
schema: 2.0.0
---

# Invoke-StreamingParser

## SYNOPSIS
Process files through a streaming Node.js parser using stdin/stdout JSON protocol

## SYNTAX

```
Invoke-StreamingParser [-ParserScript] <String> [[-Files] <Object[]>] [[-RootPath] <String>]
 [[-OutputJson] <String>] [[-TimeoutSeconds] <Int32>] [-ContinueOnError] [[-ProgressInterval] <Int32>]
 [[-CustomCommand] <String>] [[-CommandBuilder] <ScriptBlock>] [[-ResultProcessor] <ScriptBlock>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Manages lifecycle of a long-running Node.js process that accepts JSON commands via stdin
and returns JSON responses via stdout.
Optimized for processing large file sets by
eliminating per-file process spawn overhead.

## EXAMPLES

### EXAMPLE 1

```powershell
# Basic usage
Get-ChildItem *.c -Recurse | Invoke-StreamingParser -ParserScript ./parser.js
```

### EXAMPLE 2

```powershell
# With custom command builder
$files | Invoke-StreamingParser -ParserScript ./parser.js -CommandBuilder {
    param($FilePath, $Index)
    @{ cmd = 'analyze'; path = $FilePath; options = @{ complexity = $true } }
}
```

### EXAMPLE 3

```powershell
# With result transformation
$files | Invoke-StreamingParser -ParserScript ./parser.js -ResultProcessor {
    param($Response, $File)
    [PSCustomObject]@{
        Name = $File.Name
        Functions = $Response.result.stats.functions
        Complexity = $Response.result.complexity.cyclomatic
    }
}
```

## PARAMETERS

### -ParserScript
Path to Node.js script that implements streaming protocol

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Files
Array of file paths to process, or pipeline input

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases: FullName, Path, FilePath

Required: False
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -RootPath
Root directory to make file paths relative to (optional)

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

### -OutputJson
Path to save JSON results (optional)

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

### -TimeoutSeconds
Timeout for each file parse operation (default: 30)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: 30
Accept pipeline input: False
Accept wildcard characters: False
```

### -ContinueOnError
Continue processing if individual files fail

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

### -ProgressInterval
Show progress every N files (default: 50)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: 50
Accept pipeline input: False
Accept wildcard characters: False
```

### -CustomCommand
Custom command name (default: 'parse')

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: Parse
Accept pipeline input: False
Accept wildcard characters: False
```

### -CommandBuilder
ScriptBlock to build custom command object.
Receives $FilePath, $Index.
Default: @{ command = 'parse'; file = $FilePath; request_id = $Index }

```yaml
Type: ScriptBlock
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: { param($FilePath, $Index) @{ command = $CustomCommand; file = $FilePath; request_id = $Index } }
Accept pipeline input: False
Accept wildcard characters: False
```

### -ResultProcessor
ScriptBlock to transform parser response into result object.
Receives $Response, $File.
Default: returns response as-is

```yaml
Type: ScriptBlock
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: { param($Response, $File) $Response }
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

## RELATED LINKS
