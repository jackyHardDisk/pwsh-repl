function Format-Count {
    <#
    .SYNOPSIS
    Format items with count prefix.

    .DESCRIPTION
    Formats frequency count results as "count x: item" with aligned counts.
    Useful for showing aggregated error/warning counts from build logs or test output.

    Expects input objects with Count and Item properties (typically from Measure-Frequency
    or Group-Object with count). Passes through objects without these properties unchanged.

    .PARAMETER InputObject
    Object with Count and Item (or Name) properties from Measure-Frequency or Group-Object.

    .PARAMETER Width
    Width of count column for alignment (default: 6). Adjust based on expected count magnitude.

    .EXAMPLE
    PS> Get-Content build.log | Select-String "error" | Measure-Frequency | Format-Count
        42x: Cannot find module 'foo'
        12x: Undefined variable 'bar'
         3x: Type mismatch in assignment

    .EXAMPLE
    PS> Find-Errors build.log | Format-Count -Width 4
      42x: Cannot find module 'foo'
      12x: Undefined variable 'bar'

    .EXAMPLE
    PS> "error: foo", "error: bar", "error: foo" | Measure-Frequency | Format-Count
         2x: error: foo
         1x: error: bar

    .NOTES
    Pipeline-friendly: Processes each input object individually for streaming efficiency.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $InputObject,

        [Parameter()]
        [int]$Width = 6
    )

    process {
        # Check for Count property (from Measure-Frequency)
        if ($null -ne $InputObject.Count -and $null -ne $InputObject.Item) {
            "{0,$Width}x: {1}" -f $InputObject.Count, $InputObject.Item
        }
        # Check for Count and Name (from Group-Object)
        elseif ($null -ne $InputObject.Count -and $null -ne $InputObject.Name) {
            "{0,$Width}x: {1}" -f $InputObject.Count, $InputObject.Name
        }
        # Pass through other objects unchanged
        else {
            $InputObject
        }
    }
}

function Group-By {
    <#
    .SYNOPSIS
    Group objects by property value.

    .DESCRIPTION
    Groups input objects by a specified property, returning objects with Count and Item properties.
    Wrapper around Group-Object that returns a more pipeline-friendly format with sorted results.

    Results are sorted by count (descending) by default, making it easy to identify most frequent values.

    .PARAMETER Property
    Property name to group by. Can be a simple property name or nested property path.

    .PARAMETER InputObject
    Objects to group. Typically piped in from previous command.

    .PARAMETER NoSort
    Skip sorting by count. Returns groups in order encountered.

    .EXAMPLE
    PS> Get-ChildItem | Group-By Extension
         42x: .txt
         12x: .log
          3x: .md

    .EXAMPLE
    PS> Get-Content errors.log | Select-String "file: (\S+)" | ForEach-Object { $_.Matches.Groups[1].Value } | Group-By
         15x: app.js
          8x: utils.js
          2x: config.json

    .EXAMPLE
    PS> Import-Csv log.csv | Group-By Level | Format-Count
        245x: ERROR
         89x: WARN
         12x: INFO

    .NOTES
    Output format: PSCustomObject with Count and Item properties for easy consumption by Format-Count.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Property,

        [Parameter(ValueFromPipeline, Mandatory)]
        $InputObject,

        [Parameter()]
        [switch]$NoSort
    )

    begin {
        $items = @()
    }

    process {
        $items += $InputObject
    }

    end {
        if ($Property) {
            $grouped = $items | Group-Object -Property $Property
        } else {
            # Group by the item itself (for simple strings/values)
            $grouped = $items | Group-Object
        }

        if ($NoSort) {
            $result = $grouped
        } else {
            $result = $grouped | Sort-Object Count -Descending
        }

        # Convert to standard format with Count and Item
        $result | ForEach-Object {
            [PSCustomObject]@{
                Count = $_.Count
                Item = if ($Property) { $_.Name } else { $_.Name }
                Group = $_.Group
            }
        }
    }
}

function Measure-Frequency {
    <#
    .SYNOPSIS
    Count occurrences and sort by frequency.

    .DESCRIPTION
    Counts how many times each unique item appears in the input stream and returns
    results sorted by frequency (most common first). This is effectively Group-By with
    a more intuitive name for frequency analysis tasks.

    Particularly useful for analyzing error messages, log entries, or test failures
    to quickly identify the most common issues.

    .PARAMETER InputObject
    Items to count. Each unique item becomes one result row.

    .PARAMETER Property
    Optional property to group by. If omitted, groups by the entire object.

    .PARAMETER Ascending
    Sort by frequency ascending (least common first) instead of descending.

    .EXAMPLE
    PS> "error", "warning", "error", "info", "error" | Measure-Frequency
         3x: error
         1x: warning
         1x: info

    .EXAMPLE
    PS> Get-Content build.log | Select-String "error:" | Measure-Frequency
        42x: error: Cannot find module
        12x: error: Undefined variable
         3x: error: Type mismatch

    .EXAMPLE
    PS> Get-Process | Measure-Frequency -Property ProcessName | Select-Object -First 5
        15x: chrome
         8x: node
         5x: pwsh
         3x: code
         2x: explorer

    .EXAMPLE
    PS> Import-Csv errors.csv | Measure-Frequency -Property ErrorCode | Format-Count -Width 4
      245x: E001
       89x: E042
       12x: E404

    .NOTES
    This is an alias-style wrapper around Group-By for better discoverability.
    Use this when your intent is frequency analysis rather than general grouping.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $InputObject,

        [Parameter(Position = 0)]
        [string]$Property,

        [Parameter()]
        [switch]$Ascending
    )

    begin {
        $items = @()
    }

    process {
        $items += $InputObject
    }

    end {
        if ($Property) {
            $grouped = $items | Group-Object -Property $Property
        } else {
            $grouped = $items | Group-Object
        }

        if ($Ascending) {
            $result = $grouped | Sort-Object Count
        } else {
            $result = $grouped | Sort-Object Count -Descending
        }

        # Return in standard format
        $result | ForEach-Object {
            [PSCustomObject]@{
                Count = $_.Count
                Item = $_.Name
                Group = $_.Group
            }
        }
    }
}
