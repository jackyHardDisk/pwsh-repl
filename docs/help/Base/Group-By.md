---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Group-By

## SYNOPSIS
Group objects by property value.

## SYNTAX

```
Group-By [[-Property] <String>] -InputObject <Object> [-NoSort] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Groups input objects by a specified property, returning objects with Count and Item properties.
Wrapper around Group-Object that returns a more pipeline-friendly format with sorted results.

Results are sorted by count (descending) by default, making it easy to identify most frequent values.

## EXAMPLES

### EXAMPLE 1

```powershell
Get-ChildItem | Group-By Extension
     42x: .txt
     12x: .log
      3x: .md
```

### EXAMPLE 2

```powershell
Get-Content errors.log | Select-String "file: (\S+)" | ForEach-Object { $_.Matches.Groups[1].Value } | Group-By
     15x: app.js
      8x: utils.js
      2x: config.json
```

### EXAMPLE 3

```powershell
Import-Csv log.csv | Group-By Level | Format-Count
    245x: ERROR
     89x: WARN
     12x: INFO
```

## PARAMETERS

### -Property
Property name to group by.
Can be a simple property name or nested property path.

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

### -InputObject
Objects to group.
Typically piped in from previous command.

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

### -NoSort
Skip sorting by count.
Returns groups in order encountered.

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
Output format: PSCustomObject with Count and Item properties for easy consumption by Format-Count.

## RELATED LINKS
