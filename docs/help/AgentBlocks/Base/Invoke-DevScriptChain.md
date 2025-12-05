---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Invoke-DevScriptChain

## SYNOPSIS
Execute multiple registered scripts in sequence.

## SYNTAX

```
Invoke-DevScriptChain [-Names] <String[]> [-ContinueOnError] [-UpdateMetadata]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Executes a chain of registered scripts in order.
Useful for multi-step workflows
like build -\> test -\> deploy.

Can optionally stop on first failure or continue through all scripts.

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-DevScriptChain -Names @("build", "test", "deploy")
Executes build, then test, then deploy. Stops if any fails.
```

### EXAMPLE 2

```powershell
Invoke-DevScriptChain -Names @("lint", "format", "build") -ContinueOnError
Executes all three scripts even if one fails
```

### EXAMPLE 3

```powershell
Invoke-DevScriptChain -Names @("build", "test") -UpdateMetadata
Executes scripts and updates their metadata
```

## PARAMETERS

### -Names
Array of script names to execute in order.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ContinueOnError
Continue executing remaining scripts even if one fails.
Default: stop on first failure.

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

### -UpdateMetadata
Update metadata (timestamp, exit code) for each script after execution.

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
All scripts must be registered before chaining.
Returns summary of executions.

## RELATED LINKS
