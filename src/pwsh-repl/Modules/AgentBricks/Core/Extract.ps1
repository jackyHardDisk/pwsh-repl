function Extract-Regex
{
    <#
    .SYNOPSIS
    Extract data using regular expressions with named groups.

    .DESCRIPTION
    Applies a regex pattern to input text and extracts data into PSCustomObject properties
    based on named capture groups. This enables structured data extraction from unstructured
    text like log files, compiler output, or API responses.

    Named groups in the pattern become properties on the output object. For example,
    pattern '(?<file>\S+):(?<line>\d+)' creates objects with 'file' and 'line' properties.

    Supports both single-match and multi-match modes. By default, returns first match per
    input line. Use -All to extract all matches.

    .PARAMETER InputObject
    Text to search. Can be string or object with ToString() method.

    .PARAMETER Pattern
    Regular expression pattern with named groups. Example: '(?<key>\w+)=(?<value>\S+)'

    .PARAMETER Group
    Specific named group to extract as simple string (instead of full object).

    .PARAMETER All
    Extract all matches instead of just the first match per line.

    .EXAMPLE
    PS> "app.js:42:15: error: undefined variable" | Extract-Regex -Pattern '(?<file>[\w.]+):(?<line>\d+):(?<col>\d+): (?<msg>.+)'

    file   line col msg
    ----   ---- --- ---
    app.js 42   15  error: undefined variable

    .EXAMPLE
    PS> Get-Content errors.log | Extract-Regex -Pattern 'ERROR: (?<message>.+)' -Group message
    Database connection failed
    Invalid API key
    Timeout after 30 seconds

    .EXAMPLE
    PS> "key1=value1 key2=value2" | Extract-Regex -Pattern '(?<key>\w+)=(?<value>\S+)' -All

    key  value
    ---  -----
    key1 value1
    key2 value2

    .EXAMPLE
    PS> Get-Content build.log | Extract-Regex -Pattern '(?<file>[\w/\\.-]+)\((?<line>\d+),(?<col>\d+)\): error (?<code>\w+): (?<msg>.+)'
    # Extracts structured error data from MSBuild output

    .NOTES
    Returns PSCustomObject for easy pipeline processing and filtering.
    Unmatched lines are skipped (no output for non-matching input).
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $InputObject,

        [Parameter(Position = 0, Mandatory)]
        [string]$Pattern,

        [Parameter()]
        [string]$Group,

        [Parameter()]
        [switch]$All
    )

    process {
        $text = $InputObject.ToString()

        if ($All)
        {
            $matches = [regex]::Matches($text, $Pattern)
        }
        else
        {
            $match = [regex]::Match($text, $Pattern)
            $matches = if ($match.Success)
            {
                @($match)
            }
            else
            {
                @()
            }
        }

        foreach ($match in $matches)
        {
            if ($match.Success)
            {
                # If specific group requested, return just that value
                if ($Group)
                {
                    if ($match.Groups[$Group].Success)
                    {
                        $match.Groups[$Group].Value
                    }
                }
                # Otherwise, build object from all named groups
                else
                {
                    $result = [ordered]@{ }
                    foreach ($groupName in $match.Groups.Keys)
                    {
                        # Skip numeric groups (positional captures)
                        if ($groupName -match '^\d+$')
                        {
                            continue
                        }
                        $result[$groupName] = $match.Groups[$groupName].Value
                    }
                    if ($result.Count -gt 0)
                    {
                        [PSCustomObject]$result
                    }
                }
            }
        }
    }
}

function Extract-Between
{
    <#
    .SYNOPSIS
    Extract text between two marker strings.

    .DESCRIPTION
    Extracts substring between start and end markers. Useful for parsing structured
    text like XML-ish formats, quoted strings, or delimited sections in logs.

    Supports greedy (longest match) and non-greedy (shortest match) modes.
    Default is non-greedy to extract first occurrence.

    .PARAMETER InputObject
    Text to search.

    .PARAMETER Start
    Starting marker string. The marker itself is excluded from output.

    .PARAMETER End
    Ending marker string. The marker itself is excluded from output.

    .PARAMETER Greedy
    Use greedy matching (extract longest possible match). Default is non-greedy.

    .PARAMETER IncludeMarkers
    Include start and end markers in the output.

    .EXAMPLE
    PS> "The <b>quick</b> brown fox" | Extract-Between -Start "<b>" -End "</b>"
    quick

    .EXAMPLE
    PS> 'Error: "file not found" in module' | Extract-Between -Start '"' -End '"'
    file not found

    .EXAMPLE
    PS> Get-Content log.txt | Extract-Between -Start "[ERROR]" -End "[/ERROR]"
    # Extracts error details between markers

    .EXAMPLE
    PS> "start{outer{inner}outer}end" | Extract-Between -Start "{" -End "}" -Greedy
    outer{inner}outer

    .EXAMPLE
    PS> "start{outer{inner}outer}end" | Extract-Between -Start "{" -End "}"
    outer{inner

    .NOTES
    Returns $null for lines without both markers.
    For nested markers, use -Greedy carefully or process with regex instead.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [string]$InputObject,

        [Parameter(Position = 0, Mandatory)]
        [string]$Start,

        [Parameter(Position = 1, Mandatory)]
        [string]$End,

        [Parameter()]
        [switch]$Greedy,

        [Parameter()]
        [switch]$IncludeMarkers
    )

    process {
        # Escape special regex characters in markers
        $startEscaped = [regex]::Escape($Start)
        $endEscaped = [regex]::Escape($End)

        # Build pattern (non-greedy by default)
        if ($Greedy)
        {
            $pattern = "$startEscaped(.*)$endEscaped"
        }
        else
        {
            $pattern = "$startEscaped(.*?)$endEscaped"
        }

        $match = [regex]::Match($InputObject, $pattern)

        if ($match.Success)
        {
            if ($IncludeMarkers)
            {
                $match.Value
            }
            else
            {
                $match.Groups[1].Value
            }
        }
    }
}

function Extract-Column
{
    <#
    .SYNOPSIS
    Extract Nth column from delimited text.

    .DESCRIPTION
    Extracts a specific column from delimited text (whitespace, comma, tab, etc.).
    Useful for parsing structured log output, CSV-like data, or tabular command output.

    Column numbers are 1-indexed (first column is 1). Supports negative indexing
    (-1 for last column, -2 for second-to-last, etc.).

    .PARAMETER InputObject
    Text line to parse.

    .PARAMETER Column
    Column number to extract (1-indexed). Use negative numbers to count from end.

    .PARAMETER Delimiter
    Delimiter pattern. Default is whitespace (\s+). Use ',' for CSV, '\t' for TSV, etc.

    .PARAMETER Trim
    Trim whitespace from extracted value. Default is $true.

    .EXAMPLE
    PS> "ERROR 2024-11-15 Database connection failed" | Extract-Column 1
    ERROR

    .EXAMPLE
    PS> Get-Content access.log | Extract-Column -Column 4
    # Extract 4th column from each log line (e.g., HTTP status code)

    .EXAMPLE
    PS> "apple,banana,cherry,date" | Extract-Column -Column 3 -Delimiter ","
    cherry

    .EXAMPLE
    PS> "one    two    three    four" | Extract-Column -Column -1
    four

    .EXAMPLE
    PS> Get-Content errors.txt | Extract-Column 2 | Measure-Frequency
    # Count frequency of values in 2nd column

    .NOTES
    Returns $null if column doesn't exist.
    Use Select-Object -First N | Extract-Column for preview of large files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [string]$InputObject,

        [Parameter(Position = 0, Mandatory)]
        [int]$Column,

        [Parameter()]
        [string]$Delimiter = '\s+',

        [Parameter()]
        [bool]$Trim = $true
    )

    process {
        # Split by delimiter
        $columns = $InputObject -split $Delimiter

        # Handle negative indexing
        $index = if ($Column -lt 0)
        {
            $columns.Length + $Column
        }
        else
        {
            $Column - 1  # Convert 1-indexed to 0-indexed
        }

        # Check bounds
        if ($index -ge 0 -and $index -lt $columns.Length)
        {
            $value = $columns[$index]
            if ($Trim)
            {
                $value.Trim()
            }
            else
            {
                $value
            }
        }
    }
}
