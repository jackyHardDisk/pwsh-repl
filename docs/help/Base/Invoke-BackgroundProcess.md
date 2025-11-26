---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Invoke-BackgroundProcess

## SYNOPSIS
Start external process in background with output capture to DevRun cache.

## SYNTAX

### FilePath (Default)
```
Invoke-BackgroundProcess -Name <String> -FilePath <String> [-ArgumentList <String[]>]
 [-WorkingDirectory <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Script
```
Invoke-BackgroundProcess -Name <String> -Script <String> [-WorkingDirectory <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Runs process in background, capturing stdout/stderr to temporary files.
Compatible with DevRun cache ($global:DevRunCache) - use Stop-BackgroundProcess to move output
to cache for analysis with Get-StreamData, Get-BuildError, Group-BuildErrors, etc.

After stopping, output is stored in $global:DevRunCache using the same format as Invoke-DevRun,
making background process output compatible with all Base/AgentBricks analysis functions.

## EXAMPLES

### EXAMPLE 1

```powershell
# Start dev server
$serverCode = @'
dotnet run --project Server.csproj --urls http://localhost:5000
'@
Invoke-BackgroundProcess -Name 'devserver' -Script $serverCode

# Do work...

# Stop and analyze
Stop-BackgroundProcess -Name 'devserver'
Get-StreamData devserver Error | Find-Errors | Format-Count
```

### EXAMPLE 2

```powershell
# Start build watcher
Invoke-BackgroundProcess -Name 'watcher' -FilePath 'npm' -ArgumentList 'run', 'watch'

# Later...
Stop-BackgroundProcess -Name 'watcher'
Get-StreamData watcher Output | Select-RegexMatch -Pattern 'compiled' | Measure-Frequency
```

### EXAMPLE 3

```powershell
# Multiple background processes
$buildCode = @'
dotnet watch build
'@
Invoke-BackgroundProcess -Name 'build' -Script $buildCode

$testCode = @'
dotnet watch test
'@
Invoke-BackgroundProcess -Name 'test' -Script $testCode

Test-BackgroundProcess -Name 'build'
Test-BackgroundProcess -Name 'test'
```

## PARAMETERS

### -Name
Unique name for this background process (used as DevRun cache key).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FilePath
Executable to run (e.g., 'dotnet', 'python', 'node').

```yaml
Type: String
Parameter Sets: FilePath
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ArgumentList
Arguments for the executable.

```yaml
Type: String[]
Parameter Sets: FilePath
Aliases:

Required: False
Position: Named
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -Script
PowerShell script to run in background (alternative to FilePath).
Use here-strings (@'...'@) for multi-line scripts.

```yaml
Type: String
Parameter Sets: Script
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WorkingDirectory
Working directory for process (defaults to current location).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: (Get-Location).Path
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
Integrates with DevRun cache system ($global:DevRunCache).
After Stop-BackgroundProcess,
use Get-StreamData to retrieve output for analysis with all Base/AgentBricks functions.

Process output captured to temp files during execution, moved to DevRun cache
on stop for compatibility with Get-StreamData, Get-BuildError, etc.

## RELATED LINKS
