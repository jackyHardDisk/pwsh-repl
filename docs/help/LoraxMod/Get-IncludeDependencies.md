---
external help file: LoraxMod-help.xml
Module Name: LoraxMod
online version:
schema: 2.0.0
---

# Get-IncludeDependencies

## SYNOPSIS
Parse include directives from C/C++ files

## SYNTAX

### File
```
Get-IncludeDependencies -FilePath <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Code
```
Get-IncludeDependencies [-Code <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Extracts #include directives and categorizes them as system, local, or POSIX headers.
Based on Chandra include dependency analysis pattern.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-IncludeDependencies -FilePath main.c
Parse includes from C file
```

### EXAMPLE 2

```powershell
Get-IncludeDependencies -FilePath header.h | Select-Object -ExpandProperty posix
Get only POSIX headers
```

## PARAMETERS

### -FilePath
Path to C/C++ source or header file

```yaml
Type: String
Parameter Sets: File
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
Returns object with:
- system: array of system includes (from \<header.h\>)
- local: array of local includes (from "header.h")
- posix: array of POSIX headers

## RELATED LINKS
