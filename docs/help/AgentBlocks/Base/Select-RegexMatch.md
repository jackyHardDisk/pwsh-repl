---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Select-RegexMatch

## SYNOPSIS
Select data using regular expressions with named groups.

## SYNTAX

```
Select-RegexMatch -InputObject <Object> [-Pattern] <String> [-Group <String>] [-All]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Applies a regex pattern to input text and extracts data into PSCustomObject properties
based on named capture groups.
This enables structured data extraction from unstructured
text like log files, compiler output, or API responses.

Named groups in the pattern become properties on the output object.
For example,
pattern '(?\<file\>\S+):(?\<line\>\d+)' creates objects with 'file' and 'line' properties.

Supports both single-match and multi-match modes.
By default, returns first match per
input line.
Use -All to extract all matches.

## EXAMPLES

### EXAMPLE 1

```powershell
"app.js:42:15: error: undefined variable" | Select-RegexMatch -Pattern '(?<file>[\w.]+):(?<line>\d+):(?<col>\d+): (?<msg>.+)'
```

```output
file   line col msg
----   ---- --- ---
app.js 42   15  error: undefined variable
```

### EXAMPLE 2

```powershell
Get-Content errors.log | Select-RegexMatch -Pattern 'ERROR: (?<message>.+)' -Group message
Database connection failed
Invalid API key
Timeout after 30 seconds
```

### EXAMPLE 3

```powershell
"key1=value1 key2=value2" | Select-RegexMatch -Pattern '(?<key>\w+)=(?<value>\S+)' -All
```

```output
key  value
---  -----
key1 value1
key2 value2
```

### EXAMPLE 4

```powershell
Get-Content build.log | Select-RegexMatch -Pattern '(?<file>[\w/\\.-]+)\((?<line>\d+),(?<col>\d+)\): error (?<code>\w+): (?<msg>.+)'
# Extracts structured error data from MSBuild output
```

## PARAMETERS

### -InputObject
Text to search.
Can be string or object with ToString() method.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Pattern
Regular expression pattern with named groups.
Example: '(?\<key\>\w+)=(?\<value\>\S+)'

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

### -Group
Specific named group to extract as simple string (instead of full object).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -All
Extract all matches instead of just the first match per line.

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
Returns PSCustomObject for easy pipeline processing and filtering.
Unmatched lines are skipped (no output for non-matching input).

## RELATED LINKS
