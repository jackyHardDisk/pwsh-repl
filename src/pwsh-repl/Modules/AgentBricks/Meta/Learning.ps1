function Set-Pattern
{
    <#
    .SYNOPSIS
    Define or update a named regex pattern for tool output parsing.

    .DESCRIPTION
    Stores a named regex pattern in the BrickStore for use with Extract-Regex and
    other analysis functions. Patterns should use named capture groups to extract
    structured data from tool output.

    This is the foundational meta-tool for teaching AgentBricks about new tools.
    Once a pattern is defined, it can be used across analysis pipelines.

    .PARAMETER Name
    Unique pattern name (e.g., 'ESLint', 'pytest', 'gcc-error').

    .PARAMETER Pattern
    Regular expression pattern with named groups. Example: '(?<file>\S+):(?<line>\d+)'

    .PARAMETER Description
    Human-readable description of what the pattern matches.

    .PARAMETER Category
    Optional category: 'error', 'warning', 'test', 'build'. Used for filtering.

    .EXAMPLE
    PS> Set-Pattern -Name "ESLint" -Pattern '(?<file>[\w/.-]+):(?<line>\d+):(?<col>\d+): (?<severity>error|warning): (?<message>.+)' -Description "ESLint output format"

    .EXAMPLE
    PS> Set-Pattern -Name "pytest-fail" -Pattern 'FAILED (?<test>[\w/:]+) - (?<reason>.+)' -Description "Pytest failure format" -Category "test"

    .NOTES
    Patterns are stored in $global:BrickStore.Patterns and persist within the session.
    Use Save-Project to persist patterns across sessions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Name,

        [Parameter(Position = 1, Mandatory)]
        [string]$Pattern,

        [Parameter(Position = 2, Mandatory)]
        [string]$Description,

        [Parameter()]
        [ValidateSet('error', 'warning', 'test', 'build', 'info', 'lint', 'format')]
        [string]$Category = 'info'
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

    # Validate pattern syntax
    try
    {
        [regex]::new($Pattern) | Out-Null
    }
    catch
    {
        Write-Error "Invalid regex pattern: $_"
        return
    }

    # Store pattern
    $global:BrickStore.Patterns[$Name] = [PSCustomObject]@{
        Name = $Name
        Pattern = $Pattern
        Description = $Description
        Category = $Category
        CreatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }

    Write-Verbose "Pattern '$Name' registered: $Description"
    $global:BrickStore.Patterns[$Name]
}

function Get-Patterns
{
    <#
    .SYNOPSIS
    List registered output patterns.

    .DESCRIPTION
    Retrieves stored regex patterns from BrickStore. Patterns can be filtered by
    category or name. Use this to discover available patterns before running
    analysis pipelines.

    .PARAMETER Name
    Filter by pattern name (supports wildcards).

    .PARAMETER Category
    Filter by category: 'error', 'warning', 'test', 'build'.

    .EXAMPLE
    PS> Get-Patterns

    Name       Category Pattern                                   Description
    ----       -------- -------                                   -----------
    ESLint     error    (?<file>[\w/.-]+):(?<line>\d+):...       ESLint output format
    pytest     test     FAILED (?<test>[\w/:]+)...               Pytest failure format

    .EXAMPLE
    PS> Get-Patterns -Category error
    # Show only error patterns

    .EXAMPLE
    PS> Get-Patterns -Name "*eslint*"
    # Find patterns matching 'eslint'

    .EXAMPLE
    PS> $pattern = Get-Patterns -Name "ESLint"
    PS> $env:lint_stderr | Extract-Regex -Pattern $pattern.Pattern
    # Use stored pattern in analysis

    .NOTES
    Returns PSCustomObject with Name, Pattern, Description, Category, CreatedAt.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [Parameter()]
        [ValidateSet('error', 'warning', 'test', 'build', 'info')]
        [string]$Category
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

    $patterns = $global:BrickStore.Patterns.Values

    # Filter by name (supports wildcards)
    if ($Name)
    {
        $patterns = $patterns | Where-Object { $_.Name -like $Name }
    }

    # Filter by category
    if ($Category)
    {
        $patterns = $patterns | Where-Object { $_.Category -eq $Category }
    }

    $patterns | Sort-Object Name
}

function Test-Pattern
{
    <#
    .SYNOPSIS
    Test a pattern against sample input to verify it works.

    .DESCRIPTION
    Validates that a registered pattern correctly extracts data from sample input.
    Useful for debugging patterns and verifying they work before using them in
    production analysis.

    .PARAMETER Name
    Name of registered pattern to test.

    .PARAMETER Sample
    Sample text to test against. If omitted, uses stored sample from Learn-OutputPattern.

    .PARAMETER ShowMatches
    Display matched values instead of just count.

    .EXAMPLE
    PS> Test-Pattern -Name "ESLint" -Sample "app.js:42:15: error: undefined variable"

    Pattern: ESLint
    Matched: 1 line(s)

    Extracted fields:
    file     : app.js
    line     : 42
    col      : 15
    severity : error
    message  : undefined variable

    .EXAMPLE
    PS> Test-Pattern -Name "pytest" -Sample "FAILED tests/test_app.py::test_login - AssertionError"
    # Test pytest pattern

    .NOTES
    Returns $true if pattern matches, $false otherwise.
    Displays extracted fields for debugging.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Name,

        [Parameter(Position = 1)]
        [string]$Sample,

        [Parameter()]
        [switch]$ShowMatches
    )

    # Get pattern
    $patternObj = Get-Patterns -Name $Name

    if (-not $patternObj)
    {
        Write-Error "Pattern not found: $Name"
        return $false
    }

    # Use stored sample if not provided
    if (-not $Sample)
    {
        if ($global:BrickStore.Results[$Name])
        {
            $Sample = $global:BrickStore.Results[$Name].Sample
        }
        else
        {
            Write-Error "No sample provided and no stored sample for pattern '$Name'"
            return $false
        }
    }

    Write-Host "Pattern: $Name" -ForegroundColor Cyan
    Write-Host "Description: $( $patternObj.Description )" -ForegroundColor Gray
    Write-Host ""

    # Test pattern
    $match = [regex]::Match($Sample, $patternObj.Pattern)

    if ($match.Success)
    {
        Write-Host "Matched: YES" -ForegroundColor Green
        Write-Host ""

        if ($ShowMatches -or $true)
        {
            Write-Host "Extracted fields:" -ForegroundColor Cyan
            foreach ($groupName in $match.Groups.Keys)
            {
                if ($groupName -match '^\d+$')
                {
                    continue
                }
                Write-Host ("  {0,-12}: {1}" -f $groupName, $match.Groups[$groupName].Value) -ForegroundColor White
            }
        }

        return $true
    }
    else
    {
        Write-Host "Matched: NO" -ForegroundColor Red
        Write-Host ""
        Write-Host "Sample text:" -ForegroundColor Yellow
        Write-Host "  $Sample"
        return $false
    }
}

function Learn-OutputPattern
{
    <#
    .SYNOPSIS
    Interactively learn a tool's output pattern by running it and analyzing output.

    .DESCRIPTION
    Executes a command, captures output, and helps you define a regex pattern to
    extract structured data. This is the primary meta-learning tool for teaching
    AgentBricks about new tools.

    In interactive mode, presents auto-detected patterns and lets you choose or
    define a custom pattern. In non-interactive mode, auto-detects and stores
    the best-guess pattern.

    .PARAMETER Name
    Name to register pattern under (e.g., 'myapp-lint').

    .PARAMETER Command
    Command to execute to generate sample output.

    .PARAMETER Interactive
    Enable interactive mode to review and refine detected patterns.

    .PARAMETER Category
    Pattern category: 'error', 'warning', 'test', 'build'.

    .EXAMPLE
    PS> Learn-OutputPattern -Name "myapp-lint" -Command "myapp lint src/" -Interactive
    # Runs command, shows detected patterns, prompts for selection

    .EXAMPLE
    PS> Learn-OutputPattern -Name "custom-test" -Command "npm test" -Category test
    # Auto-learn test output pattern

    .NOTES
    Stores both the pattern and sample output for later testing.
    Use Get-Patterns to see learned patterns.
    Use Test-Pattern to verify patterns work.

    This function represents the "learning" capability - agents can teach themselves
    about new tools by observing output and extracting patterns.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Name,

        [Parameter(Position = 1, Mandatory)]
        [string]$Command,

        [Parameter()]
        [switch]$Interactive,

        [Parameter()]
        [ValidateSet('error', 'warning', 'test', 'build', 'info', 'lint', 'format')]
        [string]$Category = 'info'
    )

    Write-Host "Learning output pattern for: $Name" -ForegroundColor Cyan
    Write-Host "Command: $Command" -ForegroundColor Gray
    Write-Host ""

    # Execute command and capture output
    Write-Host "Executing command..." -ForegroundColor Yellow
    try
    {
        $output = Invoke-Expression $Command 2>&1 | Out-String
    }
    catch
    {
        $output = $_.Exception.Message
    }

    # Store sample
    $sample = $output

    Write-Host "Captured $( $output.Length ) bytes of output" -ForegroundColor Green
    Write-Host ""

    # Auto-detect common patterns
    $detectedPatterns = @()

    # Pattern 1: file:line:col: message (GCC-style)
    if ($output -match '[\w/\\.-]+:\d+:\d+:')
    {
        $detectedPatterns += [PSCustomObject]@{
            Name = "GCC-style"
            Pattern = '(?<file>[\w/\\.-]+):(?<line>\d+):(?<col>\d+):\s*(?<severity>\w+):\s*(?<message>.+)'
            Description = "GCC/Clang format: file:line:col: severity: message"
        }
    }

    # Pattern 2: file(line,col): message (MSBuild-style)
    if ($output -match '[\w/\\.-]+\(\d+,\d+\):')
    {
        $detectedPatterns += [PSCustomObject]@{
            Name = "MSBuild-style"
            Pattern = '(?<file>[\w/\\.-]+)\((?<line>\d+),(?<col>\d+)\):\s*(?<severity>\w+)\s*(?<code>\w+):\s*(?<message>.+)'
            Description = "MSBuild format: file(line,col): severity code: message"
        }
    }

    # Pattern 3: FAILED/PASSED test format
    if ($output -match '(FAILED|PASSED|ERROR)')
    {
        $detectedPatterns += [PSCustomObject]@{
            Name = "Test-style"
            Pattern = '(?<status>FAILED|PASSED|ERROR)\s+(?<test>[\w/:.-]+)\s*-?\s*(?<message>.*)'
            Description = "Test format: STATUS test - message"
        }
    }

    # Pattern 4: Generic error/warning lines
    if ($output -match '\b(error|warning)\b')
    {
        $detectedPatterns += [PSCustomObject]@{
            Name = "Generic"
            Pattern = '(?<severity>error|warning|info):\s*(?<message>.+)'
            Description = "Generic format: severity: message"
        }
    }

    if ($detectedPatterns.Count -eq 0)
    {
        Write-Host "No common patterns detected. Sample output:" -ForegroundColor Yellow
        Write-Host ($output -split "`n" | Select-Object -First 10 | Out-String)

        if ($Interactive)
        {
            $customPattern = Read-Host "Enter custom regex pattern (or press Enter to skip)"
            if ($customPattern)
            {
                $description = Read-Host "Enter description"
                Set-Pattern -Name $Name -Pattern $customPattern -Description $description -Category $Category
                Write-Host "Pattern registered: $Name" -ForegroundColor Green
            }
        }
        return
    }

    # Show detected patterns
    Write-Host "Detected patterns:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $detectedPatterns.Count; $i++) {
        $p = $detectedPatterns[$i]
        Write-Host "  $( $i + 1 ). $( $p.Name ): $( $p.Description )" -ForegroundColor White
    }
    Write-Host ""

    if ($Interactive)
    {
        $choice = Read-Host "Select pattern (1-$( $detectedPatterns.Count )) or 'c' for custom"

        if ($choice -eq 'c')
        {
            $customPattern = Read-Host "Enter custom regex pattern"
            $description = Read-Host "Enter description"
            Set-Pattern -Name $Name -Pattern $customPattern -Description $description -Category $Category
        }
        elseif ($choice -match '^\d+$' -and [int]$choice -le $detectedPatterns.Count)
        {
            $selected = $detectedPatterns[[int]$choice - 1]
            Set-Pattern -Name $Name -Pattern $selected.Pattern -Description $selected.Description -Category $Category
        }
        else
        {
            Write-Host "Invalid choice, skipping pattern registration" -ForegroundColor Yellow
            return
        }
    }
    else
    {
        # Auto-select first detected pattern
        $selected = $detectedPatterns[0]
        Set-Pattern -Name $Name -Pattern $selected.Pattern -Description $selected.Description -Category $Category
        Write-Host "Auto-registered pattern: $( $selected.Name )" -ForegroundColor Green
    }

    # Store sample for testing
    if (-not $global:BrickStore.Results[$Name])
    {
        $global:BrickStore.Results[$Name] = @{ }
    }
    $global:BrickStore.Results[$Name].Sample = $sample

    Write-Host ""
    Write-Host "Pattern learned successfully!" -ForegroundColor Green
    Write-Host "Use 'Test-Pattern -Name $Name' to verify" -ForegroundColor Gray
}
