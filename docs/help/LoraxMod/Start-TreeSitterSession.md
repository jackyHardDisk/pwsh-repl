---
external help file: LoraxMod-help.xml
Module Name: LoraxMod
online version:
schema: 2.0.0
---

# Start-TreeSitterSession

## SYNOPSIS
Start interactive Node.js REPL with tree-sitter loaded

## SYNTAX

### Code
```
Start-TreeSitterSession -Language <String> [-Code <String>] [-AsProcess] [-SessionId <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### File
```
Start-TreeSitterSession -Language <String> [-FilePath <String>] [-AsProcess] [-SessionId <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Initializes Node.js REPL session with loraxmod pre-loaded and parser initialized.
Sets up global variables: parser, tree, root for immediate navigation.

Two modes:
- Terminal mode (default): Blocking interactive REPL for human use
- Process mode (-AsProcess): Returns Process object for programmatic control via stdin

## EXAMPLES

### EXAMPLE 1

```powershell
Start-TreeSitterSession -Language c -Code 'int main() { printf("hi"); }'
Starts blocking REPL in terminal
```

### EXAMPLE 2

```powershell
$repl = Start-TreeSitterSession -Language fortran -FilePath code.f90 -AsProcess
$repl.Process.StandardInput.WriteLine('root.childCount')
$output = $repl.Process.StandardOutput.ReadLine()
$repl.Process.Kill()
$repl.Process.Dispose()
```

### EXAMPLE 3

```powershell
$repl = Start-TreeSitterSession -Language c -AsProcess -SessionId 'analysis1'
Send-REPLCommand -SessionId 'analysis1' -Command 'root.type'
Stop-TreeSitterSession -SessionId 'analysis1'
```

## PARAMETERS

### -Language
Programming language to parse (c, python, javascript, etc.)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Code
Source code to parse initially

```yaml
Type: String
Parameter Sets: Code
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FilePath
Path to source file to parse

```yaml
Type: String
Parameter Sets: File
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsProcess
Return Process object with stdin/stdout access for programmatic control.
Process must be manually stopped and disposed.

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

### -SessionId
Session identifier for tracking (used with -AsProcess).
Default: 'default'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
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
Terminal mode - type commands interactively:
- root.type - Get node type
- root.childCount - Count children
- root.child(0) - Get first child
- root.childForFieldName('function') - Get field
- root.parent - Get parent node
- root.startPosition - Get position {row, column}
- root.text - Get source text

Process mode - use Process.StandardInput/StandardOutput for automation

## RELATED LINKS
