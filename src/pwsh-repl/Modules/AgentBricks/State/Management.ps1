function Save-Project
{
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
    if (-not $global:BrickStore)
    {
        $global:BrickStore = @{
            Results = @{ }
            Patterns = @{ }
            Chains = @{ }
        }
    }

    # Prepare export data
    $exportData = @{
        Version = "1.0"
        CreatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        PatternCount = $global:BrickStore.Patterns.Count
        Patterns = @{ }
    }

    # Convert patterns to exportable format
    foreach ($patternName in $global:BrickStore.Patterns.Keys)
    {
        $pattern = $global:BrickStore.Patterns[$patternName]
        $exportData.Patterns[$patternName] = @{
            Pattern = $pattern.Pattern
            Description = $pattern.Description
            Category = $pattern.Category
        }
    }

    # Save to JSON
    try
    {
        $exportData | ConvertTo-Json -Depth 5 | Set-Content -Path $Path
        Write-Host "Saved $( $exportData.PatternCount ) patterns to $Path" -ForegroundColor Green
        Get-Item $Path
    }
    catch
    {
        Write-Error "Failed to save project: $_"
    }
}

function Import-Project
{
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
    PS> Import-Project
    Loaded 15 patterns from .brickyard.json

    .EXAMPLE
    PS> Import-Project -Path "~/shared-patterns.json" -Merge
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
    if (-not (Test-Path $Path))
    {
        Write-Warning "File not found: $Path"
        return
    }

    # Initialize BrickStore if not exists or if not merging
    if (-not $global:BrickStore -or -not $Merge)
    {
        $global:BrickStore = @{
            Results = @{ }
            Patterns = @{ }
            Chains = @{ }
        }
    }

    try
    {
        # Load JSON
        $importData = Get-Content $Path | ConvertFrom-Json

        # Import patterns
        $loadedCount = 0
        foreach ($patternName in $importData.Patterns.PSObject.Properties.Name)
        {
            $patternData = $importData.Patterns.$patternName

            # Validate pattern
            try
            {
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
            catch
            {
                Write-Warning "Skipping invalid pattern '$patternName': $_"
            }
        }

        Write-Host "Loaded $loadedCount patterns from $Path" -ForegroundColor Green
    }
    catch
    {
        Write-Error "Failed to load project: $_"
    }
}

function Get-BrickStore
{
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
    if (-not $global:BrickStore)
    {
        $global:BrickStore = @{
            Results = @{ }
            Patterns = @{ }
            Chains = @{ }
        }
    }

    Write-Host "`nBrickStore State" -ForegroundColor Cyan
    Write-Host "================" -ForegroundColor Cyan
    Write-Host "Patterns: $( $global:BrickStore.Patterns.Count )"
    Write-Host "Results:  $( $global:BrickStore.Results.Count )"
    Write-Host "Chains:   $( $global:BrickStore.Chains.Count )"
    Write-Host ""

    # Show patterns
    $patterns = $global:BrickStore.Patterns.Values

    if ($Category)
    {
        $patterns = $patterns | Where-Object { $_.Category -eq $Category }
    }

    if ($patterns.Count -gt 0)
    {
        Write-Host "Patterns:" -ForegroundColor Cyan

        foreach ($pattern in ($patterns | Sort-Object Category, Name))
        {
            if ($Detailed)
            {
                Write-Host "  [$( $pattern.Category )] $( $pattern.Name )" -ForegroundColor White
                Write-Host "    Description: $( $pattern.Description )" -ForegroundColor Gray
                Write-Host "    Pattern: $( $pattern.Pattern )" -ForegroundColor DarkGray
                Write-Host ""
            }
            else
            {
                Write-Host "  [$( $pattern.Category )] $( $pattern.Name ) - $( $pattern.Description )" -ForegroundColor White
            }
        }
    }

    # Show stored results
    if ($global:BrickStore.Results.Count -gt 0)
    {
        Write-Host "`nStored Results:" -ForegroundColor Cyan
        foreach ($key in $global:BrickStore.Results.Keys)
        {
            Write-Host "  $key" -ForegroundColor White
        }
    }

    Write-Host ""
}

function Export-Environment
{
    <#
    .SYNOPSIS
    Export current PowerShell session environment variables to JSON/script format.

    .DESCRIPTION
    Captures and exports the current PowerShell session's environment variables.
    Useful for debugging MCP server sessions, documenting build environments,
    or reproducing development environments.

    Can export to JSON (default), PowerShell script, or display to console.

    .PARAMETER Path
    Output file path. File extension determines format:
    - .json: JSON format (default)
    - .ps1: PowerShell script format (executable)
    - Omit for console output

    .PARAMETER Include
    Filter to include only matching variables (wildcard supported).
    Example: "PWSH_*", "PATH", "CONDA_*"

    .PARAMETER Exclude
    Filter to exclude matching variables (wildcard supported).
    Example: "*TOKEN*", "*SECRET*", "*PASSWORD*"

    .PARAMETER Format
    Output format: 'JSON', 'PowerShell', 'Console'. Auto-detected from file extension if Path provided.

    .EXAMPLE
    PS> Export-Environment
    Displays all environment variables to console

    .EXAMPLE
    PS> Export-Environment -Path "env-snapshot.json"
    Exports all environment variables to JSON file

    .EXAMPLE
    PS> Export-Environment -Path "restore-env.ps1"
    Creates executable PowerShell script to restore environment

    .EXAMPLE
    PS> Export-Environment -Include "PWSH_*","PYTHON*" -Path "mcp-env.json"
    Exports only MCP-related environment variables

    .EXAMPLE
    PS> Export-Environment -Exclude "*TOKEN*","*SECRET*" -Path "safe-env.json"
    Exports environment excluding sensitive variables

    .NOTES
    JSON format preserves exact values for machine parsing.
    PowerShell format creates executable script with $env: assignments.
    Always exclude sensitive data before sharing exports.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path,

        [Parameter()]
        [string[]]$Include,

        [Parameter()]
        [string[]]$Exclude,

        [Parameter()]
        [ValidateSet('JSON', 'PowerShell', 'Console')]
        [string]$Format
    )

    # Get all environment variables
    $envVars = Get-ChildItem Env:

    # Apply Include filter
    if ($Include)
    {
        $envVars = $envVars | Where-Object {
            $name = $_.Name
            $Include | Where-Object { $name -like $_ }
        }
    }

    # Apply Exclude filter
    if ($Exclude)
    {
        $envVars = $envVars | Where-Object {
            $name = $_.Name
            -not ($Exclude | Where-Object { $name -like $_ })
        }
    }

    # Auto-detect format from file extension
    if ($Path -and -not $Format)
    {
        if ($Path -match '\.ps1$')
        {
            $Format = 'PowerShell'
        }
        elseif ($Path -match '\.json$')
        {
            $Format = 'JSON'
        }
        else
        {
            $Format = 'JSON'  # Default
        }
    }
    elseif (-not $Format)
    {
        $Format = 'Console'
    }

    # Build output based on format
    switch ($Format)
    {
        'JSON' {
            $envHash = @{ }
            foreach ($var in $envVars)
            {
                $envHash[$var.Name] = $var.Value
            }

            $exportData = @{
                ExportedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                Machine = $env:COMPUTERNAME
                User = $env:USERNAME
                VariableCount = $envHash.Count
                Variables = $envHash
            }

            if ($Path)
            {
                $exportData | ConvertTo-Json -Depth 5 | Set-Content -Path $Path
                Write-Host "Exported $( $envHash.Count ) environment variables to $Path" -ForegroundColor Green
                Get-Item $Path
            }
            else
            {
                $exportData | ConvertTo-Json -Depth 5
            }
        }

        'PowerShell' {
            $scriptLines = @(
                "# Environment variable snapshot",
                "# Exported: $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' )",
                "# Machine: $env:COMPUTERNAME",
                "# User: $env:USERNAME",
                "# Variables: $( $envVars.Count )",
                ""
            )

            foreach ($var in ($envVars | Sort-Object Name))
            {
                $escapedValue = $var.Value -replace '"', '`"'
                $scriptLines += "`$env:$( $var.Name ) = `"$escapedValue`""
            }

            $script = $scriptLines -join "`n"

            if ($Path)
            {
                $script | Set-Content -Path $Path
                Write-Host "Exported $( $envVars.Count ) environment variables to $Path" -ForegroundColor Green
                Get-Item $Path
            }
            else
            {
                $script
            }
        }

        'Console' {
            Write-Host "`nEnvironment Variables ($( $envVars.Count ))" -ForegroundColor Cyan
            Write-Host "=" * 60 -ForegroundColor Cyan

            foreach ($var in ($envVars | Sort-Object Name))
            {
                $displayValue = if ($var.Value.Length -gt 60)
                {
                    $var.Value.Substring(0, 57) + "..."
                }
                else
                {
                    $var.Value
                }
                Write-Host "$( $var.Name ) = $displayValue" -ForegroundColor White
            }

            Write-Host ""
        }
    }
}

function Clear-Stored
{
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
    if (-not $global:BrickStore)
    {
        $global:BrickStore = @{
            Results = @{ }
            Patterns = @{ }
            Chains = @{ }
        }
        Write-Host "BrickStore is already empty" -ForegroundColor Yellow
        return
    }

    # Clear specific result
    if ($Name)
    {
        if ( $global:BrickStore.Results.ContainsKey($Name))
        {
            $global:BrickStore.Results.Remove($Name)
            Write-Host "Cleared stored result: $Name" -ForegroundColor Green
        }
        else
        {
            Write-Warning "Result not found: $Name"
        }
        return
    }

    # Clear all results
    $resultCount = $global:BrickStore.Results.Count
    $global:BrickStore.Results.Clear()
    Write-Host "Cleared all stored results ($resultCount items)" -ForegroundColor Green

    # Clear patterns if requested
    if ($Patterns)
    {
        $patternCount = $global:BrickStore.Patterns.Count
        $global:BrickStore.Patterns.Clear()
        Write-Host "Cleared all patterns ($patternCount items)" -ForegroundColor Yellow
        Write-Warning "All learned patterns removed! Use Import-Project to restore from .brickyard.json"
    }
}

function Set-EnvironmentTee
{
    <#
    .SYNOPSIS
    Capture pipeline input to environment variable while passing through.

    .DESCRIPTION
    Tee-style function that stores all pipeline input to an environment variable
    while simultaneously passing all items through to the next pipeline stage.

    Forces full enumeration to guarantee all items are captured, then returns
    all items for continued processing. Useful for non-destructive analysis where
    you want to capture full output while still allowing downstream filtering.

    .PARAMETER InputObject
    Pipeline input to capture and pass through.

    .PARAMETER Name
    Environment variable name (without $ env: prefix).

    .EXAMPLE
    PS> Get-Process | Set-EnvironmentTee -Name "procs" | Select-Object -First 5
    Captures all processes to $env:procs, displays first 5

    .EXAMPLE
    PS> dev_run("dotnet build", "build")
    PS> $env:build_stderr | Set-EnvironmentTee -Name "build_archive" | Find-Errors | Show -Top 10
    Archives full output, shows top 10 errors

    .EXAMPLE
    PS> "error","warning","error","info" | Set-EnvironmentTee -Name "test" -Verbose | Measure-Frequency
    VERBOSE: Tee: error
    VERBOSE: Tee: warning
    VERBOSE: Tee: error
    VERBOSE: Tee: info
    VERBOSE: Stored 4 items to $env:test

    .NOTES
    Use -Verbose to see items as they're captured.
    Stored as Out-String formatted text for easy retrieval and analysis.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $InputObject,

        [Parameter(Position = 0, Mandatory)]
        [string]$Name
    )

    begin {
        $items = @()
    }

    process {
        $items += $InputObject
        if ($VerbosePreference -eq 'Continue')
        {
            Write-Verbose "Tee: $_"
        }
    }

    end {
        Set-Item "env:$Name" -Value ($items | Out-String)
        Write-Verbose "Stored $( $items.Count ) items to `$env:$Name"
        $items
    }
}

function Invoke-CapturedProcess
{
    <#
    .SYNOPSIS
    Execute external process with full stdin/stdout/stderr capture.

    .DESCRIPTION
    Spawns external process (Python, Node, etc.) with bidirectional communication:
    - Write to child process stdin
    - Read child process stdout/stderr
    - Capture exit code
    - Store results in $global:DevRunCache or custom variable

    Uses .NET Process class with stream redirection. More reliable than
    per-session stdin pipes for direct process spawning scenarios.

    .PARAMETER Command
    Executable to run (python, node, dotnet, etc.).

    .PARAMETER Arguments
    Arguments passed to the executable. Can be string or array.

    .PARAMETER StdinData
    Data to write to process stdin. Supports multi-line strings.

    .PARAMETER WorkingDirectory
    Working directory for process execution. Defaults to current location.

    .PARAMETER TimeoutSeconds
    Maximum execution time in seconds. Process killed if exceeded.
    Default: 60 seconds.

    .PARAMETER StoreName
    Variable name to store results. Defaults to $global:DevRunCache.
    Creates hashtable with Stdout, Stderr, ExitCode keys.

    .EXAMPLE
    PS> Invoke-CapturedProcess -Command "python" -Arguments "-c","print('hello')"
    Runs Python script, captures output in $global:DevRunCache

    .EXAMPLE
    PS> Invoke-CapturedProcess python "-c `"import sys; print(sys.stdin.read())`"" -StdinData "test input"
    Sends stdin data to Python, captures echoed output

    .EXAMPLE
    PS> Invoke-CapturedProcess node script.js -WorkingDirectory "C:\project" -StoreName "node_output"
    Runs Node script in specific directory, stores in $global:node_output

    .EXAMPLE
    PS> Invoke-CapturedProcess python long_script.py -TimeoutSeconds 300
    Runs with 5 minute timeout instead of default 60 seconds

    .NOTES
    Returns hashtable: @{ Stdout = "..."; Stderr = "..."; ExitCode = 0 }
    Process inherits environment variables from PowerShell session
    Stdout/stderr captured separately for error analysis
    Timeout kills process tree to prevent orphaned children
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Command,

        [Parameter(Position = 1)]
        [object]$Arguments,

        [Parameter()]
        [string]$StdinData,

        [Parameter()]
        [string]$WorkingDirectory = (Get-Location).Path,

        [Parameter()]
        [int]$TimeoutSeconds = 60,

        [Parameter()]
        [string]$StoreName = "DevRunCache"
    )

    # Convert arguments to string if array
    $argString = if ($Arguments -is [array])
    {
        $Arguments -join ' '
    }
    elseif ($Arguments)
    {
        $Arguments.ToString()
    }
    else
    {
        ""
    }

    # Create ProcessStartInfo with stream redirection
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Command
    $psi.Arguments = $argString
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    Write-Verbose "Starting: $Command $argString"
    Write-Verbose "Working Directory: $WorkingDirectory"

    try
    {
        # Start process
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        $process.Start() | Out-Null

        # Write stdin if provided
        if ($StdinData)
        {
            Write-Verbose "Writing $( $StdinData.Length ) characters to stdin"
            $process.StandardInput.WriteLine($StdinData)
        }
        $process.StandardInput.Close()

        # Wait with timeout
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)

        if (-not $completed)
        {
            Write-Warning "Process exceeded timeout ($TimeoutSeconds seconds), killing..."
            $process.Kill($true)  # Kill process tree
            $timedOut = $true
        }
        else
        {
            $timedOut = $false
        }

        # Read output (must happen after WaitForExit)
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $exitCode = $process.ExitCode

        # Build result object
        $result = @{
            Stdout = $stdout
            Stderr = $stderr
            ExitCode = $exitCode
            Command = $Command
            Arguments = $argString
            TimedOut = $timedOut
            Duration = if ($process.ExitTime -and $process.StartTime)
            {
                ($process.ExitTime - $process.StartTime).TotalSeconds
            }
            else
            {
                $null
            }
        }

        # Store result
        Set-Variable -Name $StoreName -Value $result -Scope Global
        Write-Verbose "Stored result in `$global:$StoreName"

        # Display summary
        Write-Host "Exit Code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Red' })
        if ($timedOut)
        {
            Write-Host "Status: TIMEOUT (killed after $TimeoutSeconds seconds)" -ForegroundColor Red
        }
        if ($stdout)
        {
            Write-Host "`nStdout ($( $stdout.Length ) chars):"
            Write-Host $stdout
        }
        if ($stderr)
        {
            Write-Host "`nStderr ($( $stderr.Length ) chars):" -ForegroundColor Yellow
            Write-Host $stderr -ForegroundColor Yellow
        }

        # Return result
        $result
    }
    catch
    {
        Write-Error "Failed to execute process: $_"
        throw
    }
    finally
    {
        if ($process)
        {
            $process.Dispose()
        }
    }
}
