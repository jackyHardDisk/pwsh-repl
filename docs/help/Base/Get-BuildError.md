---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Get-BuildError

## SYNOPSIS
Get build errors from common build tools (MSBuild, GCC, CMake, etc.).

## SYNTAX

### Pipeline (Default)
```
Get-BuildError [-InputObject <Object>] [-ToolType <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### File
```
Get-BuildError [[-Source] <String>] [-ToolType <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Analyzes build output from various compilers and build systems, extracting
structured error information including file, line, column, error code, and message.

Automatically detects output format from common build tools:
- MSBuild/Visual Studio: file(line,col): error C####: message
- GCC/Clang: file:line:col: error: message
- CMake: CMake Error at file:line (function): message
- Maven/Gradle: \[ERROR\] message

Returns structured objects for easy filtering and analysis.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-BuildError build.log
```

```output
File          Line Col Code Message
----          ---- --- ---- -------
Program.cs    42   15  CS0103 The name 'foo' does not exist
Utils.cs      128  8   CS0029 Cannot convert type 'int' to 'string'
```

### EXAMPLE 2

```powershell
Get-Content cmake-output.txt | Get-BuildError -ToolType CMake
# Parse CMake configure errors
```

### EXAMPLE 3

```powershell
$env:build_stderr | Get-BuildError | Where-Object { $_.Code -like "CS*" }
# Filter C# compiler errors from dev-run output
```

### EXAMPLE 4

```powershell
Get-BuildError gcc.log | Group-Object File | Sort-Object Count -Descending
# Find files with most errors
```

## PARAMETERS

### -InputObject
Build output text.
Can be piped from Get-Content or stored dev-run output.

```yaml
Type: Object
Parameter Sets: Pipeline
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Source
Path to build log file.
Alternative to piping content.

```yaml
Type: String
Parameter Sets: File
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ToolType
Hint about build tool type: 'MSBuild', 'GCC', 'CMake', 'Maven'.
Auto-detects if omitted.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Auto
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
Returns PSCustomObject with File, Line, Col, Code, Message properties.
Not all fields available for all build tools (e.g., Maven errors lack file/line).

## RELATED LINKS
