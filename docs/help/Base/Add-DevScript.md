---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Add-DevScript

## SYNOPSIS
Register script metadata in $global:DevRunScripts registry.

## SYNTAX

```
Add-DevScript [-Name] <String> [-Script] <String> [-ExitCode <Int32>] [-Dependencies <String[]>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Stores script metadata (text, timestamp, exit code, dependencies) in the
global script registry.
This enables script invocation, chaining, and
tracking of script execution history.

Typically called automatically by Invoke-DevRun, but can be used manually to
register scripts for invocation.

## EXAMPLES

### EXAMPLE 1

```powershell
Add-DevScript -Name "build" -Script "dotnet build"
Registered script 'build'
```

### EXAMPLE 2

```powershell
Add-DevScript -Name "test" -Script "dotnet test" -Dependencies @("build")
Registered script 'test' with dependency on 'build'
```

## PARAMETERS

### -Name
Script name (used as registry key).

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

### -Script
PowerShell script text to store.

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

### -ExitCode
Exit code from last execution (default: 0).

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

### -Dependencies
Optional array of script names this script depends on.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: @()
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
Overwrites existing script with same name.
Use Get-DevScripts to list registered scripts.

## RELATED LINKS
