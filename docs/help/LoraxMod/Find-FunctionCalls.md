---
external help file: LoraxMod-help.xml
Module Name: LoraxMod
online version:
schema: 2.0.0
---

# Find-FunctionCalls

## SYNOPSIS
Find function calls with context (parent function, arguments, line numbers)

## SYNTAX

### Code
```
Find-FunctionCalls -Language <String> [-Code <String>] [-FunctionNames <String[]>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### File
```
Find-FunctionCalls -Language <String> [-FilePath <String>] [-FunctionNames <String[]>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Extracts all function calls from source code with full context information.
Similar to Chandra POSIX analysis pattern.
Returns function name, location,
parent function, arguments, and source line.

## EXAMPLES

### EXAMPLE 1

```powershell
Find-FunctionCalls -Language c -FilePath main.c
Find all function calls in C file
```

### EXAMPLE 2

```powershell
Find-FunctionCalls -Language c -FilePath main.c -FunctionNames @('printf', 'malloc', 'free')
Find only POSIX memory/IO functions
```

### EXAMPLE 3

```powershell
Find-FunctionCalls -Language python -Code 'import os; os.path.join("a", "b")'
Find function calls in Python code
```

## PARAMETERS

### -Language
Programming language

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
Source code to analyze

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
Path to source file to analyze

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

### -FunctionNames
Optional filter - only return calls to these functions

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
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
Returns objects with:
- function: function name
- line: line number (1-indexed)
- column: column number
- parentFunction: containing function name (or 'global')
- arguments: array of argument text
- codeLine: full source line

## RELATED LINKS
