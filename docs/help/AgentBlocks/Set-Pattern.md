---
external help file: AgentBlocks-help.xml
Module Name: AgentBlocks
online version:
schema: 2.0.0
---

# Set-Pattern

## SYNOPSIS
Define or update a named regex pattern for tool output parsing.

## SYNTAX

```
Set-Pattern [-Name] <String> [-Pattern] <String> [-Description] <String> [-Category <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Stores a named regex pattern in the BrickStore for use with Select-RegexMatch and
other analysis functions.
Patterns should use named capture groups to extract
structured data from tool output.

This is the foundational meta-tool for teaching AgentBlocks about new tools.
Once a pattern is defined, it can be used across analysis pipelines.

## EXAMPLES

### EXAMPLE 1

```powershell
Set-Pattern -Name "ESLint" -Pattern '(?<file>[\w/.-]+):(?<line>\d+):(?<col>\d+): (?<severity>error|warning): (?<message>.+)' -Description "ESLint output format"
```

### EXAMPLE 2

```powershell
Set-Pattern -Name "pytest-fail" -Pattern 'FAILED (?<test>[\w/:]+) - (?<reason>.+)' -Description "Pytest failure format" -Category "test"
```

## PARAMETERS

### -Name
Unique pattern name (e.g., 'ESLint', 'pytest', 'gcc-error').

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

### -Pattern
Regular expression pattern with named groups.
Example: '(?\<file\>\S+):(?\<line\>\d+)'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Description
Human-readable description of what the pattern matches.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Category
Optional category: 'error', 'warning', 'test', 'build'.
Used for filtering.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Info
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
Patterns are stored in $global:BrickStore.Patterns and persist within the session.
Use Save-Project to persist patterns across sessions.

## RELATED LINKS
