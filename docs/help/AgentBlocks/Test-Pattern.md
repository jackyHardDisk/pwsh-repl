---
external help file: AgentBlocks-help.xml
Module Name: AgentBlocks
online version:
schema: 2.0.0
---

# Test-Pattern

## SYNOPSIS
Test a pattern against sample input to verify it works.

## SYNTAX

```
Test-Pattern [-Name] <String> [[-Sample] <String>] [-ShowMatches] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Validates that a registered pattern correctly extracts data from sample input.
Useful for debugging patterns and verifying they work before using them in
production analysis.

## EXAMPLES

### EXAMPLE 1

```powershell
Test-Pattern -Name "ESLint" -Sample "app.js:42:15: error: undefined variable"
```

Pattern: ESLint
Matched: 1 line(s)

Extracted fields:
file     : app.js
line     : 42
col      : 15
severity : error
message  : undefined variable

### EXAMPLE 2

```powershell
Test-Pattern -Name "pytest" -Sample "FAILED tests/test_app.py::test_login - AssertionError"
# Test pytest pattern
```

## PARAMETERS

### -Name
Name of registered pattern to test.

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

### -Sample
Sample text to test against.
If omitted, uses stored sample from Register-OutputPattern.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowMatches
Display matched values instead of just count.

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
Returns $true if pattern matches, $false otherwise.
Displays extracted fields for debugging.

## RELATED LINKS
