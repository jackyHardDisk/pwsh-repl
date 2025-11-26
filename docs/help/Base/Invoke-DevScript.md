---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Invoke-DevScript

## SYNOPSIS
Execute a registered script from $global:DevRunScripts registry.

## SYNTAX

```
Invoke-DevScript [-Name] <String> [-UpdateMetadata] [-PassThru] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Retrieves and executes a script previously registered via Add-DevScript or Invoke-DevRun.
Useful for re-running saved scripts, chaining scripts, or building workflows.

Script is executed in the current PowerShell session with access to all variables
and modules.

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-DevScript -Name "build"
Executes the 'build' script from registry
```

### EXAMPLE 2

```powershell
Invoke-DevScript -Name "test" -UpdateMetadata
Executes 'test' script and updates timestamp/exit code
```

### EXAMPLE 3

```powershell
$results = Invoke-DevScript -Name "analyze" -PassThru
Executes script and captures output
```

## PARAMETERS

### -Name
Script name to execute (must exist in registry).

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

### -UpdateMetadata
Update metadata (timestamp, exit code) after execution.

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

### -PassThru
Return execution result objects.

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
Script must be registered via Add-DevScript or Invoke-DevRun first.
Updates $LASTEXITCODE based on script execution.

## RELATED LINKS
