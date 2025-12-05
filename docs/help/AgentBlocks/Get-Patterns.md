---
external help file: AgentBlocks-help.xml
Module Name: AgentBlocks
online version:
schema: 2.0.0
---

# Get-Patterns

## SYNOPSIS
List registered output patterns.

## SYNTAX

```
Get-Patterns [[-Name] <String>] [-Category <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves stored regex patterns from BrickStore.
Patterns can be filtered by
category or name.
Use this to discover available patterns before running
analysis pipelines.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-Patterns
```

```output
Name       Category Pattern                                   Description
----       -------- -------                                   -----------
ESLint     error    (?\<file\>\[\w/.-\]+):(?\<line\>\d+):... 
ESLint output format
pytest     test     FAILED (?\<test\>\[\w/:\]+)... 
Pytest failure format
```

### EXAMPLE 2

```powershell
Get-Patterns -Category error
# Show only error patterns
```

### EXAMPLE 3

```powershell
Get-Patterns -Name "*eslint*"
# Find patterns matching 'eslint'
```

### EXAMPLE 4

```powershell
$pattern = Get-Patterns -Name "ESLint"
PS> $env:lint_stderr | Select-RegexMatch -Pattern $pattern.Pattern
# Use stored pattern in analysis
```

## PARAMETERS

### -Name
Filter by pattern name (supports wildcards).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Category
Filter by category: 'error', 'warning', 'test', 'build'.

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
Returns PSCustomObject with Name, Pattern, Description, Category, CreatedAt.

## RELATED LINKS
