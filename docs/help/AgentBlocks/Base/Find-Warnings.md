---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Find-Warnings

## SYNOPSIS
Extract and count warnings from text output.

## SYNTAX

### Pipeline (Default)
```
Find-Warnings [-InputObject <Object>] [-Pattern <String>] [-CaseSensitive] [-Top <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### File
```
Find-Warnings [[-Source] <String>] [-Pattern <String>] [-CaseSensitive] [-Top <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Searches input text for warning patterns and returns frequency analysis of warnings found.
Similar to Find-Errors but specifically targets warning-level messages.

By default matches common warning keywords, but supports custom patterns for
language-specific or tool-specific warning formats.

## EXAMPLES

### EXAMPLE 1

```powershell
Find-Warnings build.log
     15x: warning: Unused variable 'temp'
      8x: warning: Deprecated function usage
      3x: warning: Missing semicolon
```

### EXAMPLE 2

```powershell
Get-Content compiler.log | Find-Warnings -Pattern "warning (C\d+):" | Format-Count
# Extract MSVC warning codes
```

### EXAMPLE 3

```powershell
Find-Warnings eslint-output.txt -Top 10
# Show top 10 ESLint warnings
```

## PARAMETERS

### -InputObject
Text to search.
Can be array of strings, file content, or pipeline input.

```yaml
Type: Object
Parameter Sets: Pipeline
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Source
Path to file to analyze.
Alternative to piping content.

```yaml
Type: String
Parameter Sets: File
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Pattern
Custom regex pattern for matching warnings.
Default: \bwarning\b

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: \bwarning\b
Accept pipeline input: False
Accept wildcard characters: False
```

### -CaseSensitive
Make pattern matching case-sensitive.
Default is case-insensitive.

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

### -Top
Return only top N most frequent warnings.
Default is all warnings.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0
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
Returns PSCustomObject with Count and Item properties.
Particularly useful for code quality analysis and identifying common code smells.

## RELATED LINKS
