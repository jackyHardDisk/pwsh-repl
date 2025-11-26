---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Group-BuildErrors

## SYNOPSIS
Group build errors by code and similar messages using pattern extraction.

## SYNTAX

```
Group-BuildErrors [-InputObject] <Object> [[-Pattern] <String>] [[-Threshold] <Double>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Extracts structured error information using regex patterns, groups by error code,
then fuzzy-matches error messages within each code group.
Produces a clean summary
showing error frequency, codes, and representative messages.

More powerful than Group-Similar alone because it first extracts semantic structure
(file, line, code, message) before grouping.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-StreamData -Name "build" -Stream Error | Group-BuildErrors
Count Code   Files Message
----- ----   ----- -------
    3 CS0103     3 The name 'foo' does not exist
    2 CS0168     2 Variable declared but not used
```

### EXAMPLE 2

```powershell
Get-Content gcc.log | Group-BuildErrors -Pattern "GCC"
Count Code    Files Message
----- ----    ----- -------
   12 error       5 undefined reference to 'foo'
    3 warning     2 unused variable 'bar'
```

## PARAMETERS

### -InputObject
Error text lines (e.g., from build logs).

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Pattern
Pattern name from Get-Patterns.
Default: "MSBuild-Error".
Supports: MSBuild-Error, GCC, Clang, etc.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: MSBuild-Error
Accept pipeline input: False
Accept wildcard characters: False
```

### -Threshold
Similarity threshold for message fuzzy matching.
Default: 0.85.

```yaml
Type: Double
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 0.85
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
Requires AgentBricks patterns to be loaded (Get-Patterns).
Pattern must have named groups: file, line, code, message.

## RELATED LINKS
