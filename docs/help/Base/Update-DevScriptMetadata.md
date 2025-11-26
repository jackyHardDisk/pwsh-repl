---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Update-DevScriptMetadata

## SYNOPSIS
Update metadata for registered script.

## SYNTAX

```
Update-DevScriptMetadata [-Name] <String> [-ExitCode <Int32>] [-UpdateTimestamp] [-Dependencies <String[]>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Updates timestamp, exit code, or dependencies for an existing registered script.
Script text is not modified.

Useful for tracking re-runs or updating dependencies.

## EXAMPLES

### EXAMPLE 1

```powershell
Update-DevScriptMetadata -Name "build" -ExitCode 0 -UpdateTimestamp
Updated metadata for script 'build'
```

## PARAMETERS

### -Name
Script name to update.

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

### -ExitCode
New exit code value.

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

### -UpdateTimestamp
Update timestamp to current time.

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

### -Dependencies
New dependencies array (replaces existing).

```yaml
Type: String[]
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
At least one update parameter must be specified.

## RELATED LINKS
