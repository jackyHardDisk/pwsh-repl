---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Set-EnvironmentTee

## SYNOPSIS
Capture pipeline input to environment variable while passing through.

## SYNTAX

```
Set-EnvironmentTee -InputObject <Object> [-Name] <String> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Tee-style function that stores all pipeline input to an environment variable
while simultaneously passing all items through to the next pipeline stage.

Forces full enumeration to guarantee all items are captured, then returns
all items for continued processing.
Useful for non-destructive analysis where
you want to capture full output while still allowing downstream filtering.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-Process | Set-EnvironmentTee -Name "procs" | Select-Object -First 5
Captures all processes to $env:procs, displays first 5
```

### EXAMPLE 2

```powershell
Invoke-DevRun -Script 'dotnet build' -Name build
PS> Get-StreamData build Error | Set-EnvironmentTee -Name "build_archive" | Find-Errors | Show -Top 10
Archives full output, shows top 10 errors
```

### EXAMPLE 3

```powershell
"error","warning","error","info" | Set-EnvironmentTee -Name "test" -Verbose | Measure-Frequency
VERBOSE: Tee: error
VERBOSE: Tee: warning
VERBOSE: Tee: error
VERBOSE: Tee: info
VERBOSE: Stored 4 items to $env:test
```

## PARAMETERS

### -InputObject
Pipeline input to capture and pass through.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Name
Environment variable name (without $ env: prefix).

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
Use -Verbose to see items as they're captured.
Stored as Out-String formatted text for easy retrieval and analysis.

## RELATED LINKS
