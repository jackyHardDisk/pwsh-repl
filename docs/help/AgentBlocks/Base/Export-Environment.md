---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Export-Environment

## SYNOPSIS
Export current PowerShell session environment variables to JSON/script format.

## SYNTAX

```
Export-Environment [[-Path] <String>] [-Include <String[]>] [-Exclude <String[]>] [-Format <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Captures and exports the current PowerShell session's environment variables.
Useful for debugging MCP server sessions, documenting build environments,
or reproducing development environments.

Can export to JSON (default), PowerShell script, or display to console.

## EXAMPLES

### EXAMPLE 1

```powershell
Export-Environment
Displays all environment variables to console
```

### EXAMPLE 2

```powershell
Export-Environment -Path "env-snapshot.json"
Exports all environment variables to JSON file
```

### EXAMPLE 3

```powershell
Export-Environment -Path "restore-env.ps1"
Creates executable PowerShell script to restore environment
```

### EXAMPLE 4

```powershell
Export-Environment -Include "PWSH_*","PYTHON*" -Path "mcp-env.json"
Exports only MCP-related environment variables
```

### EXAMPLE 5

```powershell
Export-Environment -Exclude "*TOKEN*","*SECRET*" -Path "safe-env.json"
Exports environment excluding sensitive variables
```

## PARAMETERS

### -Path
Output file path.
File extension determines format:
- .json: JSON format (default)
- .ps1: PowerShell script format (executable)
- Omit for console output

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

### -Include
Filter to include only matching variables (wildcard supported).
Example: "PWSH_*", "PATH", "CONDA_*"

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

### -Exclude
Filter to exclude matching variables (wildcard supported).
Example: "*TOKEN*", "*SECRET*", "*PASSWORD*"

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

### -Format
Output format: 'JSON', 'PowerShell', 'Console'.
Auto-detected from file extension if Path provided.

```yaml
Type: String
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
JSON format preserves exact values for machine parsing.
PowerShell format creates executable script with $env: assignments.
Always exclude sensitive data before sharing exports.

## RELATED LINKS
