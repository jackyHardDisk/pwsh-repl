# Execution.ps1 - Core execution functions for PowerShell MCP Server
#
# Provides cached script execution with token-efficient summaries

function Invoke-DevRun {
    <#
    .SYNOPSIS
    Execute PowerShell script with stream capture, caching, and condensed summary output.

    .DESCRIPTION
    Runs PowerShell script in current session, captures all output streams, stores in
    $global:DevRunCache, and returns token-efficient summary (error/warning counts, top issues).

    Auto-caches ALL executions for later retrieval via Get-DevRunOutput. Use this for
    build commands, tests, linting - any script where you want results summarized but
    need full output available for analysis.

    Default behavior:
    - Returns condensed 15-line summary (99% token reduction vs full output)
    - Caches full output in $global:DevRunCache[name]
    - Shows Error and Warning streams in summary
    - Mutes Verbose, Debug, Information (available in cache)

    .PARAMETER Script
    PowerShell script to execute. Can be command, pipeline, or multi-line script.

    .PARAMETER Name
    Cache name for storing results. REQUIRED.
    Results stored in $global:DevRunCache[name] with Script, Timestamp, and all stream data.

    .PARAMETER Streams
    PowerShell streams to include in summary. Default: Error, Warning.
    Valid: Error, Warning, Verbose, Debug, Information, Progress, Output

    .EXAMPLE
    Invoke-DevRun -Script 'dotnet build' -Name 'build'
    # Returns:
    # Script: dotnet build
    #
    # Errors: 12  (3 unique)
    # Top Errors:
    #   8x: CS0246: The type or namespace name 'Foo' could not be found
    #   3x: CS1002: ; expected
    #   1x: CS0103: The name 'bar' does not exist
    #
    # Warnings: 5  (2 unique)
    # ...
    # Output: 847 lines
    #
    # Stored: $global:DevRunCache['build']
    # Retrieve: Get-DevRunOutput -Name 'build' -Stream 'Error'

    .EXAMPLE
    Invoke-DevRun -Script 'Get-Process | Where CPU -gt 100' -Name 'highcpu'
    # Executes and caches. Full output available via Get-DevRunOutput.

    .EXAMPLE
    Invoke-DevRun -Script 'npm test' -Name 'test' -Streams @('Error','Warning','Verbose')
    # Include Verbose stream in summary

    .NOTES
    Cache persists for session lifetime. Use Clear-DevRunCache to free memory.
    Use Export-Environment to save cache to disk for later sessions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Script,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [ValidateSet('Error', 'Warning', 'Verbose', 'Debug', 'Information', 'Progress', 'Output')]
        [string[]]$Streams = @('Error', 'Warning')
    )

    # Validate cache exists (should be initialized by C#)
    if (-not $global:DevRunCache) {
        throw "DevRunCache not initialized. This should be set up by SessionManager.cs"
    }

    # Capture all output streams
    $output = @{
        Script = $Script
        Timestamp = Get-Date
        Stdout = [System.Collections.ArrayList]::new()
        Stderr = [System.Collections.ArrayList]::new()
        Streams = @{
            Error = [System.Collections.ArrayList]::new()
            Warning = [System.Collections.ArrayList]::new()
            Verbose = [System.Collections.ArrayList]::new()
            Debug = [System.Collections.ArrayList]::new()
            Information = [System.Collections.ArrayList]::new()
            Progress = [System.Collections.ArrayList]::new()
        }
    }

    # Execute script with stream capture (2>&1 captures all streams)
    $scriptBlock = [scriptblock]::Create($Script)

    try {
        $results = & $scriptBlock 2>&1

        foreach ($item in $results) {
            if ($item -is [System.Management.Automation.ErrorRecord]) {
                $null = $output.Streams.Error.Add($item.ToString())
                $null = $output.Stderr.Add($item.ToString())
            }
            elseif ($item -is [System.Management.Automation.WarningRecord]) {
                $null = $output.Streams.Warning.Add($item.ToString())
            }
            elseif ($item -is [System.Management.Automation.VerboseRecord]) {
                $null = $output.Streams.Verbose.Add($item.ToString())
            }
            elseif ($item -is [System.Management.Automation.DebugRecord]) {
                $null = $output.Streams.Debug.Add($item.ToString())
            }
            elseif ($item -is [System.Management.Automation.InformationRecord]) {
                $null = $output.Streams.Information.Add($item.Message.ToString())
            }
            elseif ($item -is [System.Management.Automation.ProgressRecord]) {
                $null = $output.Streams.Progress.Add($item.ToString())
            }
            else {
                # Regular output (stdout)
                $null = $output.Stdout.Add($item.ToString())
            }
        }
    }
    catch {
        $null = $output.Streams.Error.Add($_.ToString())
        $null = $output.Stderr.Add($_.ToString())
    }

    # Store in cache
    $global:DevRunCache[$Name] = $output

    Write-Verbose "Cached output for '$Name': $($output.Stdout.Count) stdout, $($output.Streams.Error.Count) errors"

    # Generate condensed summary
    $summary = [System.Text.StringBuilder]::new()
    $null = $summary.AppendLine("Script: $(if ($Script.Length -gt 50) { $Script.Substring(0,47) + '...' } else { $Script })")
    $null = $summary.AppendLine()

    # Show requested streams with frequency analysis
    foreach ($streamName in $Streams) {
        if (-not $output.Streams.ContainsKey($streamName)) { continue }

        $items = $output.Streams[$streamName]
        if ($items.Count -eq 0) { continue }

        $unique = ($items | Select-Object -Unique).Count
        $null = $summary.AppendLine("${streamName}s: $($items.Count.ToString().PadLeft(6))  ($unique unique)")

        # Frequency analysis (top 5)
        $frequency = $items |
            Group-Object |
            Sort-Object Count -Descending |
            Select-Object -First 5 -Property Count, Name

        if ($frequency) {
            $null = $summary.AppendLine()
            $null = $summary.AppendLine("Top ${streamName}s:")
            foreach ($f in $frequency) {
                $message = if ($f.Name.Length -gt 80) { $f.Name.Substring(0,77) + '...' } else { $f.Name }
                $null = $summary.AppendLine("  $($f.Count.ToString().PadLeft(2))x: $message")
            }
            $null = $summary.AppendLine()
        }
    }

    # Output line count (always show)
    $null = $summary.AppendLine("Output: $($output.Stdout.Count.ToString().PadLeft(6)) lines")
    $null = $summary.AppendLine()

    # Storage info
    $null = $summary.AppendLine("Stored: `$global:DevRunCache['$Name']")
    $null = $summary.AppendLine("Retrieve: Get-DevRunOutput -Name '$Name' -Stream 'Error'")

    return $summary.ToString().TrimEnd()
}

function Get-DevRunOutput {
    <#
    .SYNOPSIS
    Retrieve cached output from previous Invoke-DevRun or pwsh tool execution.

    .DESCRIPTION
    Gets full output from cached execution. Useful for detailed analysis after
    reviewing condensed summary from Invoke-DevRun.

    All pwsh tool executions (with or without mode='Invoke-DevRun') are auto-cached
    and retrievable via this function.

    .PARAMETER Name
    Cache name to retrieve. Use Get-DevRunCacheList to see available names.

    .PARAMETER Stream
    Which output to retrieve:
    - Stdout: Regular command output (default)
    - Stderr: Error stream output
    - Error, Warning, Verbose, Debug, Information, Progress: PowerShell streams
    - All: Complete cached object with all data and metadata

    .EXAMPLE
    Get-DevRunOutput -Name 'build' -Stream 'Error'
    # Returns: Array of all error messages from 'build' execution

    .EXAMPLE
    Get-DevRunOutput -Name 'build' -Stream 'All'
    # Returns: Complete cache entry with Script, Timestamp, and all streams

    .EXAMPLE
    Get-DevRunOutput -Name 'build' -Stream 'Stdout' | Select-String 'warning'
    # Pipe stdout to further analysis

    .NOTES
    Cache persists for session lifetime. Use Export-Environment to save to disk.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [ValidateSet('Stdout', 'Stderr', 'Error', 'Warning', 'Verbose', 'Debug', 'Information', 'Progress', 'All')]
        [string]$Stream = 'Stdout'
    )

    if (-not $global:DevRunCache) {
        throw "DevRunCache not initialized"
    }

    if (-not $global:DevRunCache.ContainsKey($Name)) {
        $available = ($global:DevRunCache.Keys | Sort-Object) -join ', '
        throw "No cached output found for '$Name'. Available: $available"
    }

    $cached = $global:DevRunCache[$Name]

    if ($Stream -eq 'All') {
        return $cached
    }
    elseif ($Stream -in @('Error', 'Warning', 'Verbose', 'Debug', 'Information', 'Progress')) {
        return $cached.Streams[$Stream]
    }
    else {
        return $cached[$Stream]
    }
}

# Clear-DevRunCache is in Base/State/Cache.ps1 (full-featured version from AgentBricks)

function Get-DevRunCacheList {
    <#
    .SYNOPSIS
    List all cached execution entries with metadata.

    .DESCRIPTION
    Shows cache names, timestamps, and output line counts for all cached
    executions in current session.

    .EXAMPLE
    Get-DevRunCacheList
    # Returns: Table of cached entries

    Name      Timestamp            StdoutLines  ErrorCount  WarningCount
    ----      ---------            -----------  ----------  ------------
    build     2025-11-22 23:45:12  847          12          5
    test      2025-11-22 23:46:30  234          0           2

    .NOTES
    Shows metadata only, not full output. Use Get-DevRunOutput to retrieve data.
    #>
    [CmdletBinding()]
    param()

    if (-not $global:DevRunCache -or $global:DevRunCache.Count -eq 0) {
        return "No cached executions"
    }

    $global:DevRunCache.GetEnumerator() | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Key
            Timestamp = $_.Value.Timestamp
            StdoutLines = $_.Value.Stdout.Count
            ErrorCount = $_.Value.Streams.Error.Count
            WarningCount = $_.Value.Streams.Warning.Count
        }
    } | Sort-Object Timestamp -Descending | Format-Table -AutoSize
}
