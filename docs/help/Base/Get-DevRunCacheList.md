---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Get-DevRunCacheList

## SYNOPSIS
List all cached execution entries with metadata.

## SYNTAX

```
Get-DevRunCacheList [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Shows cache names, timestamps, and output line counts for all cached
executions in current session.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-DevRunCacheList
# Returns: Table of cached entries
```

```output
Name      Timestamp            StdoutLines  ErrorCount  WarningCount
----      ---------            -----------  ----------  ------------
build     2025-11-22 23:45:12  847          12          5
test      2025-11-22 23:46:30  234          0           2
```

## PARAMETERS

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
Shows metadata only, not full output.
Use Get-DevRunOutput to retrieve data.

## RELATED LINKS
