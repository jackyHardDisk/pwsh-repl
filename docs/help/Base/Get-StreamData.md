---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Get-StreamData

## SYNOPSIS
Retrieve specific stream data from Invoke-DevRun cached storage.

## SYNTAX

```
Get-StreamData [-Name] <String> [-Stream] <String> [-Force] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Extracts a specific PowerShell stream (Error, Warning, Verbose, Debug, Information, Output)
from DevRun cache ($global:DevRunCache).
Returns raw array of stream items for pipeline processing.

Uses $global:DevRunCache for performance - first access loads and caches data,
subsequent accesses retrieve from cache (much faster for repeated queries).

Used to access individual streams from Invoke-DevRun results for post-hoc analysis.
Complements Show-StreamSummary which displays formatted summaries.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-StreamData -Name "build" -Stream Error
file.cs(10): error CS0103: The name 'foo' does not exist
file.cs(42): error CS0168: Variable declared but not used
```

### EXAMPLE 2

```powershell
Get-StreamData -Name "build" -Stream Error | Group-Similar
Count Example                                        Items
----- -------                                        -----
    2 error CS0103: The name 'foo' does not exist  {...}
    1 error CS0168: Variable declared but not used  {...}
```

### EXAMPLE 3

```powershell
Get-StreamData -Name "build" -Stream Error | Group-BuildErrors | Format-Table
Count Code   Files Message
----- ----   ----- -------
    2 CS0103     2 The name 'foo' does not exist
    1 CS0168     1 Variable declared but not used
```

### EXAMPLE 4

```powershell
Get-StreamData -Name "build" -Stream Error -Force
# Forces reload from cache (local copy bypassed)
```

## PARAMETERS

### -Name
Name used in Invoke-DevRun (e.g., "build" for Invoke-DevRun -Name build).

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
Stream to retrieve: Error, Warning, Verbose, Debug, Information, or Output.

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
Force reload from cache (invalidate local copy).
Use if cache was modified externally.

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
Requires Invoke-DevRun to have been executed with stream storage enabled (default behavior).
Returns $null if name or stream not found.
Cache automatically invalidated when Invoke-DevRun executes with same name.
Performance: ~10-100x faster for repeated access (no JSON parsing).

## RELATED LINKS
