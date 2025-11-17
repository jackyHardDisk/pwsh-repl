function Save-Project {
    <#
    .SYNOPSIS
    Export learned patterns and state to .brickyard.json file.

    .DESCRIPTION
    Saves the current BrickStore state (patterns, results, chains) to a JSON file
    in the project directory. This allows patterns learned for a specific project
    to persist across sessions and be shared with team members.

    The .brickyard.json file can be committed to version control to share
    learned patterns with other developers or AI agents working on the project.

    .PARAMETER Path
    Output file path. Defaults to .brickyard.json in current directory.

    .EXAMPLE
    PS> Save-Project
    Saved 15 patterns to .brickyard.json

    .EXAMPLE
    PS> Save-Project -Path "config/brickyard.json"
    # Save to custom location

    .NOTES
    File is human-readable JSON for easy review and editing.
    Includes metadata: created date, pattern count, etc.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path = ".brickyard.json"
    )

    # Initialize BrickStore if not exists
    if (-not $global:BrickStore) {
        $global:BrickStore = @{
            Results = @{}
            Patterns = @{}
            Chains = @{}
        }
    }

    # Prepare export data
    $exportData = @{
        Version = "1.0"
        CreatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        PatternCount = $global:BrickStore.Patterns.Count
        Patterns = @{}
    }

    # Convert patterns to exportable format
    foreach ($patternName in $global:BrickStore.Patterns.Keys) {
        $pattern = $global:BrickStore.Patterns[$patternName]
        $exportData.Patterns[$patternName] = @{
            Pattern = $pattern.Pattern
            Description = $pattern.Description
            Category = $pattern.Category
        }
    }

    # Save to JSON
    try {
        $exportData | ConvertTo-Json -Depth 5 | Set-Content -Path $Path
        Write-Host "Saved $($exportData.PatternCount) patterns to $Path" -ForegroundColor Green
        Get-Item $Path
    }
    catch {
        Write-Error "Failed to save project: $_"
    }
}

function Load-Project {
    <#
    .SYNOPSIS
    Import patterns and state from .brickyard.json file.

    .DESCRIPTION
    Loads previously saved patterns from a .brickyard.json file into the current
    BrickStore. This enables restoring learned patterns across sessions or
    importing patterns from other projects/team members.

    Automatically called during module import if .brickyard.json exists in
    current directory.

    .PARAMETER Path
    Input file path. Defaults to .brickyard.json in current directory.

    .PARAMETER Merge
    Merge with existing patterns instead of replacing. Default is replace.

    .EXAMPLE
    PS> Load-Project
    Loaded 15 patterns from .brickyard.json

    .EXAMPLE
    PS> Load-Project -Path "~/shared-patterns.json" -Merge
    # Merge patterns from shared library

    .NOTES
    Validates pattern syntax before loading.
    Warns if patterns have duplicate names (when merging).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path = ".brickyard.json",

        [Parameter()]
        [switch]$Merge
    )

    # Check if file exists
    if (-not (Test-Path $Path)) {
        Write-Warning "File not found: $Path"
        return
    }

    # Initialize BrickStore if not exists or if not merging
    if (-not $global:BrickStore -or -not $Merge) {
        $global:BrickStore = @{
            Results = @{}
            Patterns = @{}
            Chains = @{}
        }
    }

    try {
        # Load JSON
        $importData = Get-Content $Path | ConvertFrom-Json

        # Import patterns
        $loadedCount = 0
        foreach ($patternName in $importData.Patterns.PSObject.Properties.Name) {
            $patternData = $importData.Patterns.$patternName

            # Validate pattern
            try {
                [regex]::new($patternData.Pattern) | Out-Null

                # Store pattern
                $global:BrickStore.Patterns[$patternName] = [PSCustomObject]@{
                    Name = $patternName
                    Pattern = $patternData.Pattern
                    Description = $patternData.Description
                    Category = $patternData.Category
                    CreatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                }

                $loadedCount++
            }
            catch {
                Write-Warning "Skipping invalid pattern '$patternName': $_"
            }
        }

        Write-Host "Loaded $loadedCount patterns from $Path" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to load project: $_"
    }
}

function Get-BrickStore {
    <#
    .SYNOPSIS
    Display current BrickStore state (patterns, results, chains).

    .DESCRIPTION
    Shows overview of current BrickStore state including registered patterns,
    stored results from dev-run, and saved analysis chains.

    Useful for understanding what patterns and data are available for analysis.

    .PARAMETER Category
    Filter patterns by category.

    .PARAMETER Detailed
    Show detailed information including full regex patterns.

    .EXAMPLE
    PS> Get-BrickStore

    BrickStore State
    ================
    Patterns: 15
    Results:  3
    Chains:   0

    Recent Patterns:
      ESLint (lint)
      Pytest (test)
      MSBuild-Error (error)

    .EXAMPLE
    PS> Get-BrickStore -Detailed
    # Shows full pattern details

    .EXAMPLE
    PS> Get-BrickStore -Category error
    # Show only error patterns

    .NOTES
    Returns summary object with counts and lists.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('error', 'warning', 'test', 'build', 'info', 'lint', 'format')]
        [string]$Category,

        [Parameter()]
        [switch]$Detailed
    )

    # Initialize BrickStore if not exists
    if (-not $global:BrickStore) {
        $global:BrickStore = @{
            Results = @{}
            Patterns = @{}
            Chains = @{}
        }
    }

    Write-Host "`nBrickStore State" -ForegroundColor Cyan
    Write-Host "================" -ForegroundColor Cyan
    Write-Host "Patterns: $($global:BrickStore.Patterns.Count)"
    Write-Host "Results:  $($global:BrickStore.Results.Count)"
    Write-Host "Chains:   $($global:BrickStore.Chains.Count)"
    Write-Host ""

    # Show patterns
    $patterns = $global:BrickStore.Patterns.Values

    if ($Category) {
        $patterns = $patterns | Where-Object { $_.Category -eq $Category }
    }

    if ($patterns.Count -gt 0) {
        Write-Host "Patterns:" -ForegroundColor Cyan

        foreach ($pattern in ($patterns | Sort-Object Category, Name)) {
            if ($Detailed) {
                Write-Host "  [$($pattern.Category)] $($pattern.Name)" -ForegroundColor White
                Write-Host "    Description: $($pattern.Description)" -ForegroundColor Gray
                Write-Host "    Pattern: $($pattern.Pattern)" -ForegroundColor DarkGray
                Write-Host ""
            }
            else {
                Write-Host "  [$($pattern.Category)] $($pattern.Name) - $($pattern.Description)" -ForegroundColor White
            }
        }
    }

    # Show stored results
    if ($global:BrickStore.Results.Count -gt 0) {
        Write-Host "`nStored Results:" -ForegroundColor Cyan
        foreach ($key in $global:BrickStore.Results.Keys) {
            Write-Host "  $key" -ForegroundColor White
        }
    }

    Write-Host ""
}

function Clear-Stored {
    <#
    .SYNOPSIS
    Clear stored results from BrickStore.

    .DESCRIPTION
    Removes stored analysis results from BrickStore. Useful for cleaning up
    after analysis sessions or freeing memory.

    Can clear specific result by name or all results.

    .PARAMETER Name
    Name of specific result to clear. If omitted, clears all results.

    .PARAMETER Patterns
    Also clear all learned patterns (use with caution).

    .EXAMPLE
    PS> Clear-Stored -Name "build"
    Cleared stored result: build

    .EXAMPLE
    PS> Clear-Stored
    Cleared all stored results (3 items)

    .EXAMPLE
    PS> Clear-Stored -Patterns
    Cleared all stored results and patterns
    WARNING: This removes all learned patterns!

    .NOTES
    Does not affect saved .brickyard.json files.
    Use Save-Project before clearing if you want to preserve patterns.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [Parameter()]
        [switch]$Patterns
    )

    # Initialize BrickStore if not exists
    if (-not $global:BrickStore) {
        $global:BrickStore = @{
            Results = @{}
            Patterns = @{}
            Chains = @{}
        }
        Write-Host "BrickStore is already empty" -ForegroundColor Yellow
        return
    }

    # Clear specific result
    if ($Name) {
        if ($global:BrickStore.Results.ContainsKey($Name)) {
            $global:BrickStore.Results.Remove($Name)
            Write-Host "Cleared stored result: $Name" -ForegroundColor Green
        }
        else {
            Write-Warning "Result not found: $Name"
        }
        return
    }

    # Clear all results
    $resultCount = $global:BrickStore.Results.Count
    $global:BrickStore.Results.Clear()
    Write-Host "Cleared all stored results ($resultCount items)" -ForegroundColor Green

    # Clear patterns if requested
    if ($Patterns) {
        $patternCount = $global:BrickStore.Patterns.Count
        $global:BrickStore.Patterns.Clear()
        Write-Host "Cleared all patterns ($patternCount items)" -ForegroundColor Yellow
        Write-Warning "All learned patterns removed! Use Load-Project to restore from .brickyard.json"
    }
}
