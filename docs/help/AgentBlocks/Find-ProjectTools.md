---
external help file: AgentBlocks-help.xml
Module Name: AgentBlocks
online version:
schema: 2.0.0
---

# Find-ProjectTools

## SYNOPSIS
Auto-detect build tools and commands available in a project.

## SYNTAX

```
Find-ProjectTools [[-Path] <String>] [-Deep] [-Category <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Scans a project directory to discover available build tools, test runners,
linters, and other development commands by examining configuration files
and project structure.

Detects:
- JavaScript/TypeScript: package.json scripts, node_modules bins
- Python: setup.py, pyproject.toml, requirements.txt, Pipfile
- .NET: *.csproj, *.sln files and MSBuild targets
- Make: Makefile targets
- CMake: CMakeLists.txt
- Docker: Dockerfile, docker-compose.yml
- Git hooks and CI configurations

Returns structured information about discovered tools including how to invoke them.

## EXAMPLES

### EXAMPLE 1

```powershell
Find-ProjectTools
```

```output
Type       Tool        Command                  Source
----       ----        -------                  ------
JavaScript npm         npm run build            package.json scripts.build
JavaScript npm         npm run test             package.json scripts.test
JavaScript npm         npm run lint             package.json scripts.lint
Python     pytest      pytest tests/            pyproject.toml tool.pytest
Make       make        make all                 Makefile target
```

### EXAMPLE 2

```powershell
Find-ProjectTools -Category test
# Show only test-related tools
```

### EXAMPLE 3

```powershell
Find-ProjectTools C:\projects\myapp -Deep
# Deep scan of specific directory
```

### EXAMPLE 4

```powershell
$tools = Find-ProjectTools
PS> $tools | Where-Object { $_.Tool -eq 'npm' } | Select-Object -ExpandProperty Command
# Get all npm commands available
```

## PARAMETERS

### -Path
Project root directory to scan.
Defaults to current directory.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: .
Accept pipeline input: False
Accept wildcard characters: False
```

### -Deep
Perform deep scan including subdirectories.
Default is shallow scan of root only.

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

### -Category
Filter by tool category: 'build', 'test', 'lint', 'format', 'deploy'.
Default is all.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: All
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
Results can be used with dev-run() to execute discovered commands.
Parsing heuristics may not detect all tools in complex projects.

## RELATED LINKS
