---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Get-BackgroundData

## SYNOPSIS
Retrieve background process output from DevRun cache.

## SYNTAX

```
Get-BackgroundData [-Name] <String> [[-Stream] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Convenience wrapper over Get-StreamData for background processes.
Retrieves captured output for analysis with AgentBricks functions.

Functionally identical to Get-StreamData - use whichever feels more natural.
This function exists for semantic clarity when working with background processes.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-BackgroundData build Error | Find-Errors | Format-Count
```

### EXAMPLE 2

```powershell
\d+)'
```

### EXAMPLE 3

```powershell
# Equivalent to Get-StreamData
Get-BackgroundData test Error | Group-BuildErrors
Get-StreamData test Error | Group-BuildErrors
```

## PARAMETERS

### -Name
Name of background process (from Invoke-BackgroundProcess).

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

### -Stream
Which stream to retrieve (Error, Warning, Output, etc.).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: Output
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
Alias for Get-StreamData - use whichever is clearer in context.
Requires Stop-BackgroundProcess to have been called first to populate cache.

## RELATED LINKS
