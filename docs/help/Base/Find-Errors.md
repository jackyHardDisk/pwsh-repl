---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Find-Errors

## SYNOPSIS
Extract and count errors from text output.

## SYNTAX

### Pipeline (Default)
```
Find-Errors [-InputObject <Object>] [-Pattern <String>] [-CaseSensitive] [-Top <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### File
```
Find-Errors [[-Source] <String>] [-Pattern <String>] [-CaseSensitive] [-Top <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Searches input text for error patterns and returns frequency analysis of errors found.
By default, uses common error keywords (error, exception, failed, failure) but supports
custom patterns for project-specific error formats.

Results are automatically grouped and sorted by frequency, making it easy to identify
the most common errors in build logs, test output, or application logs.

## EXAMPLES

### EXAMPLE 1

```powershell
Find-Errors build.log
     42x: error: Cannot find module 'foo'
     12x: error: Undefined variable 'bar'
      3x: error: Type mismatch
```

### EXAMPLE 2

```powershell
Get-Content test-output.txt | Find-Errors -Top 5
# Show only top 5 most common errors
```

### EXAMPLE 3

```powershell
Find-Errors app.log -Pattern "FATAL|ERROR|EXCEPTION"
# Custom pattern for Java-style logging
```

### EXAMPLE 4

```powershell
$env:build_stderr | Find-Errors | Format-Count -Width 4
# Analyze errors from dev-run stored output
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
Custom regex pattern for matching errors.
Default: \b(error|exception|failed|failure)\b

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: \b(error|exception|failed|failure)\b
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
Return only top N most frequent errors.
Default is all errors.

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
Returns PSCustomObject with Count and Item properties for easy formatting.
Blank lines and non-matching lines are ignored.

## RELATED LINKS
