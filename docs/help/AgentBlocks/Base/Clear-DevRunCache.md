---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Clear-DevRunCache

## SYNOPSIS
Clear cached DevRun data.

## SYNTAX

```
Clear-DevRunCache [[-Name] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Invalidates cache entries for DevRun stream data.
Useful after running
Invoke-DevRun again with same name to ensure fresh data is loaded.

Can clear specific script's cache or all cached data.

## EXAMPLES

### EXAMPLE 1

```powershell
Clear-DevRunCache -Name "build"
Clears cached data for "build" script only
```

### EXAMPLE 2

```powershell
Clear-DevRunCache
Clears all cached DevRun data
```

## PARAMETERS

### -Name
Script name to clear from cache.
If omitted, clears all cache entries.

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
Does not affect $env storage - only in-memory cache.
Next Get-CachedStreamData call will reload from $env.

## RELATED LINKS
