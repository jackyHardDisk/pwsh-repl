---
external help file: AgentBricks-help.xml
Module Name: AgentBricks
online version:
schema: 2.0.0
---

# Register-OutputPattern

## SYNOPSIS
Interactively register a tool's output pattern by running it and analyzing output.

## SYNTAX

```
Register-OutputPattern [-Name] <String> [-Command] <String> [-Interactive] [-Category <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Executes a command, captures output, and helps you define a regex pattern to
extract structured data.
This is the primary meta-learning tool for teaching
AgentBricks about new tools.

In interactive mode, presents auto-detected patterns and lets you choose or
define a custom pattern.
In non-interactive mode, auto-detects and stores
the best-guess pattern.

## EXAMPLES

### EXAMPLE 1

```powershell
Register-OutputPattern -Name "myapp-lint" -Command "myapp lint src/" -Interactive
# Runs command, shows detected patterns, prompts for selection
```

### EXAMPLE 2

```powershell
Register-OutputPattern -Name "custom-test" -Command "npm test" -Category test
# Auto-learn test output pattern
```

## PARAMETERS

### -Name
Name to register pattern under (e.g., 'myapp-lint').

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

### -Command
Command to execute to generate sample output.

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

### -Interactive
Enable interactive mode to review and refine detected patterns.

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

### -Category
Pattern category: 'error', 'warning', 'test', 'build'.

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
Stores both the pattern and sample output for later testing.
Use Get-Patterns to see learned patterns.
Use Test-Pattern to verify patterns work.

This function represents the "learning" capability - agents can teach themselves
about new tools by observing output and extracting patterns.

## RELATED LINKS
