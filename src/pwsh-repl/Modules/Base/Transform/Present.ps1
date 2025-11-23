function Show
{
    <#
    .SYNOPSIS
    Format and limit output with multiple format options.

    .DESCRIPTION
    Formats pipeline input in various ways (count, table, json, list) and optionally
    limits results. This is a convenience wrapper around PowerShell's built-in formatting
    cmdlets with sensible defaults for common analysis tasks.

    Particularly useful as the final step in analysis pipelines to present results
    in a readable format without overwhelming output.

    .PARAMETER InputObject
    Objects to format and display.

    .PARAMETER Format
    Output format: 'count', 'table', 'json', 'list'. Default is 'table'.
    - count: Use with Count/Item objects from Format-Count
    - table: Tabular format (Format-Table)
    - json: JSON format (ConvertTo-Json)
    - list: List format (Format-List)

    .PARAMETER Top
    Limit output to first N items. Useful for large result sets.

    .PARAMETER AutoSize
    Auto-size table columns. Only applies to 'table' format. Default is $true.

    .EXAMPLE
    PS> Find-Errors build.log | Show -Format count -Top 5
        42x: Cannot find module 'foo'
        12x: Undefined variable 'bar'
         3x: Type mismatch
         2x: Missing semicolon
         1x: Invalid syntax

    .EXAMPLE
    PS> Get-BuildError gcc.log | Show -Format table
    File          Line Col Message
    ----          ---- --- -------
    main.c        42   15  undefined reference to 'foo'
    utils.c       128  8   conflicting types for 'bar'

    .EXAMPLE
    PS> Get-Process | Select-Object Name, CPU | Show -Format json -Top 3
    [
        {"Name": "chrome", "CPU": 142.5},
        {"Name": "code", "CPU": 89.2},
        {"Name": "pwsh", "CPU": 12.1}
    ]

    .EXAMPLE
    PS> Find-Warnings app.log | Show -Top 10
    # Show top 10 warnings in table format (default)

    .NOTES
    The 'count' format expects objects with Count and Item properties (from Format-Count).
    For other formats, any PSObject is accepted.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $InputObject,

        [Parameter()]
        [ValidateSet('count', 'table', 'json', 'list')]
        [string]$Format = 'table',

        [Parameter()]
        [int]$Top,

        [Parameter()]
        [bool]$AutoSize = $true
    )

    begin {
        $items = @()
    }

    process {
        $items += $InputObject
    }

    end {
        # Apply Top limit if specified
        if ($Top)
        {
            $items = $items | Select-Object -First $Top
        }

        # Format based on requested format
        switch ($Format)
        {
            'count' {
                # Assume items have Count and Item properties
                $items | ForEach-Object {
                    if ($_.Count -and $_.Item)
                    {
                        "{0,6}x: {1}" -f $_.Count, $_.Item
                    }
                    else
                    {
                        $_
                    }
                }
            }

            'table' {
                if ($AutoSize)
                {
                    $items | Format-Table -AutoSize | Out-String
                }
                else
                {
                    $items | Format-Table | Out-String
                }
            }

            'json' {
                $items | ConvertTo-Json -Depth 5
            }

            'list' {
                $items | Format-List | Out-String
            }
        }
    }
}

function Export-ToFile
{
    <#
    .SYNOPSIS
    Save results to file in various formats.

    .DESCRIPTION
    Exports pipeline input to a file in specified format (text, csv, json, xml).
    Provides a consistent interface for saving analysis results with automatic
    format detection from file extension.

    Particularly useful for saving analysis results for later review, sharing
    with team members, or importing into other tools.

    .PARAMETER InputObject
    Objects to export.

    .PARAMETER Path
    Output file path. Format auto-detected from extension if not specified.

    .PARAMETER Format
    Output format: 'text', 'csv', 'json', 'xml'. Auto-detects from extension if omitted.

    .PARAMETER Append
    Append to file instead of overwriting. Only applies to text format.

    .PARAMETER NoClobber
    Fail if file already exists instead of overwriting.

    .EXAMPLE
    PS> Find-Errors build.log | Export-ToFile errors.csv
    # Auto-detects CSV format from extension

    .EXAMPLE
    PS> Get-BuildError gcc.log | Export-ToFile build-errors.json -Format json
    # Explicit JSON format

    .EXAMPLE
    PS> Find-Warnings app.log | Export-ToFile warnings.txt -Format text
    # Plain text output (one item per line)

    .EXAMPLE
    PS> Get-Process | Select-Object Name, CPU | Export-ToFile processes.xml
    # Export as XML

    .EXAMPLE
    PS> Find-Errors test1.log | Export-ToFile all-errors.txt -Append
    PS> Find-Errors test2.log | Export-ToFile all-errors.txt -Append
    # Accumulate errors from multiple sources

    .NOTES
    Creates parent directory if it doesn't exist.
    CSV format requires objects (not plain strings).
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $InputObject,

        [Parameter(Position = 0, Mandatory)]
        [string]$Path,

        [Parameter()]
        [ValidateSet('text', 'csv', 'json', 'xml', 'auto')]
        [string]$Format = 'auto',

        [Parameter()]
        [switch]$Append,

        [Parameter()]
        [switch]$NoClobber
    )

    begin {
        $items = @()

        # Auto-detect format from extension
        if ($Format -eq 'auto')
        {
            $extension = [System.IO.Path]::GetExtension($Path).ToLower()
            $Format = switch ($extension)
            {
                '.csv' {
                    'csv'
                }
                '.json' {
                    'json'
                }
                '.xml' {
                    'xml'
                }
                default {
                    'text'
                }
            }
        }

        # Ensure parent directory exists
        $parentDir = Split-Path $Path -Parent
        if ($parentDir -and -not (Test-Path $parentDir))
        {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        # Check NoClobber
        if ($NoClobber -and (Test-Path $Path))
        {
            Write-Error "File already exists and -NoClobber specified: $Path"
            return
        }
    }

    process {
        $items += $InputObject
    }

    end {
        # Export based on format
        switch ($Format)
        {
            'text' {
                if ($Append)
                {
                    $items | Out-String | Add-Content -Path $Path
                }
                else
                {
                    $items | Out-String | Set-Content -Path $Path
                }
            }

            'csv' {
                $items | Export-Csv -Path $Path -NoTypeInformation
            }

            'json' {
                $items | ConvertTo-Json -Depth 5 | Set-Content -Path $Path
            }

            'xml' {
                $items | Export-Clixml -Path $Path
            }
        }

        Write-Verbose "Exported $( $items.Count ) items to $Path as $Format"
        Get-Item $Path
    }
}

function Get-StreamData
{
    <#
    .SYNOPSIS
    Retrieve specific stream data from dev_run JSON storage with caching.

    .DESCRIPTION
    Extracts a specific PowerShell stream (Error, Warning, Verbose, Debug, Information, Output)
    from dev_run's JSON hashtable storage. Returns raw array of stream items for pipeline processing.

    Uses $global:DevRunCache for performance - first access loads and caches JSON from $env,
    subsequent accesses retrieve from cache (much faster for repeated queries).

    Used to access individual streams from dev_run results for post-hoc analysis.
    Complements Show-StreamSummary which displays formatted summaries.

    .PARAMETER Name
    Name used in dev_run (e.g., "build" for dev_run(..., name="build")).

    .PARAMETER Stream
    Stream to retrieve: Error, Warning, Verbose, Debug, Information, or Output.

    .PARAMETER Force
    Force reload from $env (invalidate cache). Use if $env was modified externally.

    .EXAMPLE
    PS> Get-StreamData -Name "build" -Stream Error
    file.cs(10): error CS0103: The name 'foo' does not exist
    file.cs(42): error CS0168: Variable declared but not used

    .EXAMPLE
    PS> Get-StreamData -Name "build" -Stream Error | Group-Similar
    Count Example                                        Items
    ----- -------                                        -----
        2 error CS0103: The name 'foo' does not exist  {...}
        1 error CS0168: Variable declared but not used  {...}

    .EXAMPLE
    PS> Get-StreamData -Name "build" -Stream Error | Group-BuildErrors | Format-Table
    Count Code   Files Message
    ----- ----   ----- -------
        2 CS0103     2 The name 'foo' does not exist
        1 CS0168     1 Variable declared but not used

    .EXAMPLE
    PS> Get-StreamData -Name "build" -Stream Error -Force
    # Forces reload from $env:build_streams (cache bypassed)

    .NOTES
    Requires dev_run to have been executed with stream storage enabled (default behavior).
    Returns $null if name or stream not found.
    Cache automatically invalidated when dev_run executes with same name.
    Performance: ~10-100x faster for repeated access (no JSON parsing).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [ValidateSet("Error", "Warning", "Verbose", "Debug", "Information", "Output")]
        [string]$Stream,

        [Parameter()]
        [switch]$Force
    )

    # Use cached implementation if available (provides ~10-100x performance boost)
    if (Get-Command Get-CachedStreamData -ErrorAction SilentlyContinue)
    {
        return Get-CachedStreamData -Name $Name -Stream $Stream -Force:$Force
    }

    # Fallback to direct $env parsing (backwards compatibility if cache not loaded)
    $envVarName = "${Name}_streams"
    $json = Get-Item "env:$envVarName" -ErrorAction SilentlyContinue

    if (-not $json)
    {
        Write-Error "No stream data found for '$Name'. Run dev_run with name='$Name' first."
        return
    }

    try
    {
        $data = $json.Value | ConvertFrom-Json -AsHashtable
        if ( $data.ContainsKey($Stream))
        {
            $data[$Stream]
        }
        else
        {
            Write-Warning "Stream '$Stream' not found in $envVarName"
        }
    }
    catch
    {
        Write-Error "Failed to parse JSON from $envVarName : $_"
    }
}

function Show-StreamSummary
{
    <#
    .SYNOPSIS
    Display formatted summary of dev_run stream data.

    .DESCRIPTION
    Shows frequency analysis summary for selected PowerShell streams from dev_run results.
    Displays count, unique count, and top items for each requested stream.

    Mimics dev_run's built-in summary but allows custom stream selection and post-hoc analysis.

    .PARAMETER Name
    Name used in dev_run (e.g., "build" for dev_run(..., name="build")).

    .PARAMETER Streams
    Streams to include in summary. Default: Error, Warning (matches dev_run default).

    .PARAMETER TopCount
    Number of top items to show per stream. Default: 5.

    .EXAMPLE
    PS> Show-StreamSummary -Name "build"
    Errors: 3 (2 unique)

    Top Errors:
         2x: file.cs(10): error CS0103
         1x: file.cs(42): error CS0168

    Warnings: 1 (1 unique)

    Top Warnings:
         1x: file.cs(55): warning CS0169

    .EXAMPLE
    PS> Show-StreamSummary -Name "build" -Streams Error,Warning,Verbose

    .EXAMPLE
    PS> Show-StreamSummary -Name "test" -Streams Error -TopCount 10

    .NOTES
    Requires dev_run to have been executed with stream storage enabled (default behavior).
    Use Get-StreamData for raw stream access and custom analysis pipelines.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter()]
        [ValidateSet("Error", "Warning", "Verbose", "Debug", "Information", "Output")]
        [string[]]$Streams = @("Error", "Warning"),

        [Parameter()]
        [int]$TopCount = 5
    )

    foreach ($stream in $Streams)
    {
        $items = Get-StreamData -Name $Name -Stream $stream
        if (-not $items -or $items.Count -eq 0)
        {
            continue
        }

        $unique = ($items | Select-Object -Unique).Count
        Write-Host "`n${stream}s: $( $items.Count ) ($unique unique)" -ForegroundColor Cyan

        # Frequency analysis
        $freq = $items | Measure-Frequency | Select-Object -First $TopCount
        if ($freq)
        {
            Write-Host "`nTop ${stream}s:" -ForegroundColor Cyan
            $freq | Format-Count
        }
    }
}
