---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Get-CachedStreamData

## SYNOPSIS
Get stream data from cache, warming from $env JSON if needed.

## SYNTAX

```
Get-CachedStreamData [-Name] <String> [-Stream] <String> [-Force] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Retrieves stream data with cache-first strategy:
1.
Check $global:DevRunCache for cached data
2.
If miss, load from $env:{name}_streams JSON
3.
Cache the parsed data for future access
4.
Return requested stream

Significantly faster than parsing JSON on every Get-StreamData call.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-CachedStreamData -Name "build" -Stream Error
Returns cached Error stream for "build" script
```

### EXAMPLE 2

```powershell
Get-CachedStreamData -Name "build" -Stream Error -Force
Invalidates cache and reloads from $env:build_streams
```

## PARAMETERS

### -Name
Script name (e.g., "build" from Invoke-DevRun -Name build).

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

### -Stream
Stream to retrieve: Error, Warning, Verbose, Debug, Information, Output.

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

### -Force
Force reload from $env (invalidate cache).

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
Cache automatically invalidated when Invoke-DevRun executes with same name.
Use -Force to manually invalidate (e.g., if cache was modified externally).

## RELATED LINKS
