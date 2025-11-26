---
external help file: Base-help.xml
Module Name: Base
online version:
schema: 2.0.0
---

# Test-BackgroundProcess

## SYNOPSIS
Check status of background process.

## SYNTAX

```
Test-BackgroundProcess [-Name] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Returns process information if running, or stopped status if completed.
Useful for monitoring multiple background processes or checking if process
is still active before stopping.

## EXAMPLES

### EXAMPLE 1

```powershell
Test-BackgroundProcess -Name 'devserver'
```

```output
Name      Running PID   CPU MemoryMB Runtime          Command
----      ------- ---   --- -------- -------          -------
devserver True    12345 2.5 125.34   00:05:23.4567890 dotnet run --project Server.csproj
```

### EXAMPLE 2

```powershell
# Monitor multiple processes
'server','worker','watcher' | ForEach-Object { Test-BackgroundProcess -Name $_ }
```

### EXAMPLE 3

```powershell
# Check before stopping
$status = Test-BackgroundProcess -Name 'build'
if ($status.Running) {
    Stop-BackgroundProcess -Name 'build'
}
```

## PARAMETERS

### -Name
Name of background process to check.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
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
Returns PSCustomObject with Running, PID, CPU, Memory, Runtime, Command properties.
If process not found or has ended, Running is $false.

## RELATED LINKS
