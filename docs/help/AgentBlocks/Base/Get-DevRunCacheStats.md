---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Get-DevRunCacheStats

## SYNOPSIS
Display DevRun cache statistics.

## SYNTAX

```
Get-DevRunCacheStats [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Shows overview of current cache state including cached scripts count,
script registry count, and lists of cached names.

Useful for debugging cache behavior and understanding cache hit patterns.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-DevRunCacheStats
```

```output
DevRun Cache Statistics
=======================
Cached Streams: 3
Script Registry: 2

Cached Scripts:
  build
  test
  analyze

Registered Scripts:
  build (2024-11-18 12:34:56)
  test (2024-11-18 12:40:12)
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
Does not show cache memory usage (future enhancement).

## RELATED LINKS
