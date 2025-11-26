---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Get-DevScripts

## SYNOPSIS
List all registered scripts with metadata.

## SYNTAX

```
Get-DevScripts [[-Name] <String>] [-Detailed] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Displays all scripts in $global:DevRunScripts registry with their metadata
including timestamp, exit code, and dependencies.

Useful for discovering available scripts for invocation and chaining.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-DevScripts
```

```output
Registered Scripts (3)
======================
Name      Timestamp            ExitCode Dependencies
----      ---------            -------- ------------
build     2024-11-18 12:34:56  0
test      2024-11-18 12:40:12  0        build
deploy    2024-11-18 13:15:30  1        build, test
```

### EXAMPLE 2

```powershell
Get-DevScripts -Name "build" -Detailed
```

```output
Name: build
Script: dotnet build
Timestamp: 2024-11-18 12:34:56
ExitCode: 0
Dependencies: (none)
```

## PARAMETERS

### -Name
Filter to specific script name.
If omitted, shows all scripts.

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

### -Detailed
Show full script text and all metadata.

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
Scripts registered automatically by Invoke-DevRun or manually via Add-DevScript.

## RELATED LINKS
