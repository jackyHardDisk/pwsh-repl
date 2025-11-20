function Format-Count
{
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
        if ($null -ne $InputObject.Count -and $null -ne $InputObject.Item)
        {
            "{0,$Width}x: {1}" -f $InputObject.Count, $InputObject.Item
        }
        # Check for Count and Name (from Group-Object)
        elseif ($null -ne $InputObject.Count -and $null -ne $InputObject.Name)
        {
            "{0,$Width}x: {1}" -f $InputObject.Count, $InputObject.Name
        }
        # Pass through other objects unchanged
        else
        {
            $InputObject
        }
    }
}

function Group-By
{
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
        if ($Property)
        {
            $grouped = $items | Group-Object -Property $Property
        }
        else
        {
            # Group by the item itself (for simple strings/values)
            $grouped = $items | Group-Object
        }

        if ($NoSort)
        {
            $result = $grouped
        }
        else
        {
            $result = $grouped | Sort-Object Count -Descending
        }

        # Convert to standard format with Count and Item
        $result | ForEach-Object {
            [PSCustomObject]@{
                Count = $_.Count
                Item = if ($Property)
                {
                    $_.Name
                }
                else
                {
                    $_.Name
                }
                Group = $_.Group
            }
        }
    }
}

function Measure-Frequency
{
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
        if ($Property)
        {
            $grouped = $items | Group-Object -Property $Property
        }
        else
        {
            $grouped = $items | Group-Object
        }

        if ($Ascending)
        {
            $result = $grouped | Sort-Object Count
        }
        else
        {
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

function Get-JaroWinklerDistance
{
    <#
    .SYNOPSIS
    Calculate Jaro-Winkler similarity distance between two strings.

    .DESCRIPTION
    Computes Jaro-Winkler distance (0.0 to 1.0) measuring string similarity.
    Values closer to 1.0 indicate higher similarity. Useful for fuzzy matching
    of error messages, file names, or other text where exact matches aren't required.

    Jaro-Winkler gives higher scores to strings with matching prefixes, making it
    particularly effective for matching error messages with similar patterns.

    .PARAMETER String1
    First string to compare.

    .PARAMETER String2
    Second string to compare.

    .EXAMPLE
    PS> Get-JaroWinklerDistance "The name 'foo' does not exist" "The name 'bar' does not exist"
    0.924

    .EXAMPLE
    PS> Get-JaroWinklerDistance "error CS0103" "error CS0168"
    0.733

    .NOTES
    Returns 1.0 for identical strings, 0.0 for completely dissimilar strings.
    Threshold of 0.85 works well for grouping similar error messages.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$String1,

        [Parameter(Mandatory, Position = 1)]
        [string]$String2
    )

    if ($String1 -eq $String2)
    {
        return 1.0
    }
    if ($String1.Length -eq 0 -or $String2.Length -eq 0)
    {
        return 0.0
    }

    $matchDistance = [Math]::Floor([Math]::Max($String1.Length, $String2.Length) / 2) - 1
    $s1Matches = @($false) * $String1.Length
    $s2Matches = @($false) * $String2.Length
    $matches = 0
    $transpositions = 0

    for ($i = 0; $i -lt $String1.Length; $i++) {
        $start = [Math]::Max(0, $i - $matchDistance)
        $end = [Math]::Min($i + $matchDistance + 1, $String2.Length)

        for ($j = $start; $j -lt $end; $j++) {
            if ($s2Matches[$j] -or $String1[$i] -ne $String2[$j])
            {
                continue
            }
            $s1Matches[$i] = $true
            $s2Matches[$j] = $true
            $matches++
            break
        }
    }

    if ($matches -eq 0)
    {
        return 0.0
    }

    $k = 0
    for ($i = 0; $i -lt $String1.Length; $i++) {
        if (-not $s1Matches[$i])
        {
            continue
        }
        while (-not $s2Matches[$k])
        {
            $k++
        }
        if ($String1[$i] -ne $String2[$k])
        {
            $transpositions++
        }
        $k++
    }

    $jaro = ($matches / $String1.Length + $matches / $String2.Length + ($matches - $transpositions/2) / $matches) / 3

    $prefix = 0
    for ($i = 0; $i -lt [Math]::Min(4,[Math]::Min($String1.Length, $String2.Length)); $i++) {
        if ($String1[$i] -eq $String2[$i])
        {
            $prefix++
        }
        else
        {
            break
        }
    }

    return $jaro + ($prefix * 0.1 * (1 - $jaro))
}

function Group-Similar
{
    <#
    .SYNOPSIS
    Group similar items using fuzzy string matching.

    .DESCRIPTION
    Groups items by similarity using Jaro-Winkler distance. Items above the similarity
    threshold are grouped together, with the first item in each group becoming the exemplar.

    Particularly useful for grouping error messages that differ only in variable names,
    line numbers, or other minor variations.

    .PARAMETER InputObject
    Items to group. Can be strings or objects (use -Property for objects).

    .PARAMETER Threshold
    Similarity threshold (0.0-1.0). Items with similarity >= threshold are grouped together.
    Default: 0.85 (85% similar).

    .PARAMETER Property
    Property name to compare for object inputs. If omitted, compares entire object as string.

    .EXAMPLE
    PS> $errors = @(
        "file1.cs(10): error CS0103: The name 'foo' does not exist",
        "file2.cs(42): error CS0103: The name 'bar' does not exist",
        "file3.cs(55): error CS0168: Variable declared but not used"
    )
    PS> $errors | Group-Similar -Threshold 0.80
    Count Example                                                    Items
    ----- -------                                                    -----
        2 file1.cs(10): error CS0103: The name 'foo' does not exist {...}
        1 file3.cs(55): error CS0168: Variable declared but not used {...}

    .EXAMPLE
    PS> Get-StreamData -Name "build" -Stream Error | Group-Similar | Format-Count
         42x: error CS0103: The name 'X' does not exist
          8x: error CS0168: Variable declared but not used

    .NOTES
    Groups are sorted by count (descending). Each group includes:
    - Count: Number of items in group
    - Example: Exemplar item (first in group)
    - Items: All items in the group
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $InputObject,

        [Parameter()]
        [ValidateRange(0.0, 1.0)]
        [double]$Threshold = 0.85,

        [Parameter()]
        [string]$Property = $null
    )

    begin {
        $items = @()
    }

    process {
        $items += $InputObject
    }

    end {
        $groups = @()

        foreach ($item in $items)
        {
            $compareText = if ($Property)
            {
                $item.$Property
            }
            else
            {
                $item.ToString()
            }
            $foundGroup = $false

            foreach ($group in $groups)
            {
                $exemplar = if ($Property)
                {
                    $group.Exemplar.$Property
                }
                else
                {
                    $group.Exemplar.ToString()
                }
                $similarity = Get-JaroWinklerDistance $compareText $exemplar

                if ($similarity -ge $Threshold)
                {
                    $group.Items += $item
                    $group.Count++
                    $foundGroup = $true
                    break
                }
            }

            if (-not $foundGroup)
            {
                $groups += [PSCustomObject]@{
                    Exemplar = $item
                    Count = 1
                    Items = @($item)
                }
            }
        }

        $groups | Sort-Object Count -Descending | ForEach-Object {
            [PSCustomObject]@{
                Count = $_.Count
                Example = $_.Exemplar
                Items = $_.Items
            }
        }
    }
}

function Group-BuildErrors
{
    <#
    .SYNOPSIS
    Group build errors by code and similar messages using pattern extraction.

    .DESCRIPTION
    Extracts structured error information using regex patterns, groups by error code,
    then fuzzy-matches error messages within each code group. Produces a clean summary
    showing error frequency, codes, and representative messages.

    More powerful than Group-Similar alone because it first extracts semantic structure
    (file, line, code, message) before grouping.

    .PARAMETER InputObject
    Error text lines (e.g., from build logs).

    .PARAMETER Pattern
    Pattern name from Get-Patterns. Default: "MSBuild-Error".
    Supports: MSBuild-Error, GCC, Clang, etc.

    .PARAMETER Threshold
    Similarity threshold for message fuzzy matching. Default: 0.85.

    .EXAMPLE
    PS> Get-StreamData -Name "build" -Stream Error | Group-BuildErrors
    Count Code   Files Message
    ----- ----   ----- -------
        3 CS0103     3 The name 'foo' does not exist
        2 CS0168     2 Variable declared but not used

    .EXAMPLE
    PS> Get-Content gcc.log | Group-BuildErrors -Pattern "GCC"
    Count Code    Files Message
    ----- ----    ----- -------
       12 error       5 undefined reference to 'foo'
        3 warning     2 unused variable 'bar'

    .NOTES
    Requires AgentBricks patterns to be loaded (Get-Patterns).
    Pattern must have named groups: file, line, code, message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $InputObject,

        [Parameter()]
        [string]$Pattern = "MSBuild-Error",

        [Parameter()]
        [ValidateRange(0.0, 1.0)]
        [double]$Threshold = 0.85
    )

    begin {
        $items = @()
    }

    process {
        $items += $InputObject
    }

    end {
        $patternObj = Get-Patterns -Name $Pattern
        if (-not $patternObj)
        {
            Write-Error "Pattern '$Pattern' not found. Use Get-Patterns to see available patterns."
            return
        }

        $extracted = $items | Extract-Regex -Pattern $patternObj.Pattern
        if (-not $extracted)
        {
            Write-Warning "No matches found for pattern '$Pattern'"
            return
        }

        $codeGroups = $extracted | Group-Object code

        foreach ($codeGroup in $codeGroups)
        {
            $messageGroups = $codeGroup.Group | Group-Similar -Property message -Threshold $Threshold

            foreach ($msgGroup in $messageGroups)
            {
                $files = ($msgGroup.Items.file | Select-Object -Unique).Count

                [PSCustomObject]@{
                    Count = $msgGroup.Count
                    Code = $codeGroup.Name
                    Message = $msgGroup.Example.message
                    Files = $files
                }
            }
        }
    }
}
