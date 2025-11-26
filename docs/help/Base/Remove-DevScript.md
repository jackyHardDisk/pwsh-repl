---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Remove-DevScript

## SYNOPSIS
Remove script from $global:DevRunScripts registry.

## SYNTAX

```
Remove-DevScript [-Name] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Removes script metadata from global registry.
Useful for cleanup or
removing obsolete scripts.

Does not affect cached stream data (use Clear-DevRunCache for that).

## EXAMPLES

### EXAMPLE 1

```powershell
Remove-DevScript -Name "build"
Removed script 'build' from registry
```

## PARAMETERS

### -Name
Script name to remove.

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
Does not check for dependencies - other scripts may reference removed script.

## RELATED LINKS
