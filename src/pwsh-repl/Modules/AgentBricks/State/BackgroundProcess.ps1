# Background Process Management
# Integrates with dev_run cache system for output capture and analysis

function Invoke-BackgroundProcess
{
    <#
    .SYNOPSIS
    Start external process in background with output capture to dev_run cache.

    .DESCRIPTION
    Runs process in background, capturing stdout/stderr to temporary files.
    Compatible with dev_run cache - use Stop-BackgroundProcess to move output
    to cache for analysis with Get-StreamData, Get-BuildError, Group-BuildErrors, etc.

    After stopping, output is stored in environment variables ($env:{name}_stdout,
    $env:{name}_stderr, $env:{name}_streams) using the same format as dev_run,
    making background process output compatible with all AgentBricks analysis functions.

    .PARAMETER Name
    Unique name for this background process (used as dev_run cache key).

    .PARAMETER FilePath
    Executable to run (e.g., 'dotnet', 'python', 'node').

    .PARAMETER ArgumentList
    Arguments for the executable.

    .PARAMETER Script
    PowerShell script to run in background (alternative to FilePath).
    Use here-strings (@'...'@) for multi-line scripts.

    .PARAMETER WorkingDirectory
    Working directory for process (defaults to current location).

    .EXAMPLE
    # Start dev server
    $serverCode = @'
    dotnet run --project Server.csproj --urls http://localhost:5000
    '@
    Invoke-BackgroundProcess -Name 'devserver' -Script $serverCode

    # Do work...

    # Stop and analyze
    Stop-BackgroundProcess -Name 'devserver'
    Get-StreamData devserver Error | Find-Errors | Format-Count

    .EXAMPLE
    # Start build watcher
    Invoke-BackgroundProcess -Name 'watcher' -FilePath 'npm' -ArgumentList 'run', 'watch'

    # Later...
    Stop-BackgroundProcess -Name 'watcher'
    Get-StreamData watcher Output | Select-RegexMatch -Pattern 'compiled' | Measure-Frequency

    .EXAMPLE
    # Multiple background processes
    $buildCode = @'
    dotnet watch build
    '@
    Invoke-BackgroundProcess -Name 'build' -Script $buildCode

    $testCode = @'
    dotnet watch test
    '@
    Invoke-BackgroundProcess -Name 'test' -Script $testCode

    Test-BackgroundProcess -Name 'build'
    Test-BackgroundProcess -Name 'test'

    .NOTES
    Integrates with dev_run cache system. After Stop-BackgroundProcess,
    use Get-StreamData to retrieve output for analysis with all AgentBricks functions.

    Process output captured to temp files during execution, moved to environment
    variables on stop for compatibility with Get-StreamData, Get-BuildError, etc.
    #>
    [CmdletBinding(DefaultParameterSetName = 'FilePath')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'FilePath')]
        [string]$FilePath,

        [Parameter(ParameterSetName = 'FilePath')]
        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory, ParameterSetName = 'Script')]
        [string]$Script,

        [string]$WorkingDirectory = (Get-Location).Path
    )

    # Initialize cache if needed
    Initialize-DevRunCache

    # Create temp files for output
    $outFile = [System.IO.Path]::GetTempFileName()
    $errFile = [System.IO.Path]::GetTempFileName()

    $startArgs = @{
        PassThru = $true
        NoNewWindow = $true
        WorkingDirectory = $WorkingDirectory
        RedirectStandardOutput = $outFile
        RedirectStandardError = $errFile
    }

    if ($PSCmdlet.ParameterSetName -eq 'Script')
    {
        $startArgs['FilePath'] = 'pwsh'
        $startArgs['ArgumentList'] = @('-NoProfile', '-Command', $Script)
    }
    else
    {
        $startArgs['FilePath'] = $FilePath
        $startArgs['ArgumentList'] = $ArgumentList
    }

    try
    {
        $proc = Start-Process @startArgs
    }
    catch
    {
        Write-Error "Failed to start background process '$Name': $_"
        Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
        return
    }

    # Store metadata in global scope
    if (-not $global:BrickBackgroundJobs)
    {
        $global:BrickBackgroundJobs = @{ }
    }

    $global:BrickBackgroundJobs[$Name] = @{
        PID = $proc.Id
        Process = $proc
        OutFile = $outFile
        ErrFile = $errFile
        StartTime = Get-Date
        FilePath = if ($PSCmdlet.ParameterSetName -eq 'Script')
        {
            'pwsh'
        }
        else
        {
            $FilePath
        }
        Arguments = if ($PSCmdlet.ParameterSetName -eq 'Script')
        {
            $Script
        }
        else
        {
            $ArgumentList -join ' '
        }
    }

    [PSCustomObject]@{
        Name = $Name
        PID = $proc.Id
        StartTime = Get-Date
        OutFile = $outFile
        ErrFile = $errFile
    } | Add-Member -TypeName 'AgentBricks.BackgroundProcess' -PassThru
}

function Stop-BackgroundProcess
{
    <#
    .SYNOPSIS
    Stop background process and move output to dev_run cache.

    .DESCRIPTION
    Stops background process started with Invoke-BackgroundProcess and
    moves captured output to dev_run cache for analysis with Get-StreamData,
    Get-BuildError, Group-BuildErrors, and all other AgentBricks functions.

    Output is stored in the same environment variable format as dev_run:
    - $env:{name}_stdout - Raw stdout text
    - $env:{name}_stderr - Raw stderr text
    - $env:{name}_streams - JSON hashtable with Error/Warning/Output streams
    - $env:{name} - Command string for re-run capability

    This makes background process output fully compatible with dev_run workflows.

    .PARAMETER Name
    Name of background process to stop.

    .PARAMETER KeepFiles
    Keep temporary output files (don't clean up). Useful for debugging.

    .EXAMPLE
    Stop-BackgroundProcess -Name 'devserver'
    Get-StreamData devserver Error | Find-Errors | Group-BuildErrors | Format-Count

    .EXAMPLE
    # Stop and analyze build errors with regex + fuzzy hybrid
    Stop-BackgroundProcess -Name 'build'
    Get-StreamData build Error | Group-BuildErrors | Format-Count

    .EXAMPLE
    # Stop and analyze with custom pattern
    Stop-BackgroundProcess -Name 'server'
    Get-StreamData server Output |
        Select-RegexMatch -Pattern 'Listening on: (?<url>https?://[^\s]+)' |
        Select-Object -ExpandProperty url

    .EXAMPLE
    # Keep temp files for debugging
    Stop-BackgroundProcess -Name 'test' -KeepFiles

    .NOTES
    Output stored in dev_run cache under $env:{Name}_stdout, $env:{Name}_stderr, $env:{Name}_streams.
    Compatible with all AgentBricks analysis functions.

    Returns summary with error counts and top errors (like dev_run).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$KeepFiles
    )

    if (-not $global:BrickBackgroundJobs -or -not $global:BrickBackgroundJobs.ContainsKey($Name))
    {
        Write-Warning "No background process named '$Name' found"
        return
    }

    $jobInfo = $global:BrickBackgroundJobs[$Name]

    # Stop process
    Stop-Process -Id $jobInfo.PID -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500  # Let output flush

    # Read captured output
    $stdout = if (Test-Path $jobInfo.OutFile)
    {
        Get-Content $jobInfo.OutFile -Raw
    }
    else
    {
        ''
    }
    $stderr = if (Test-Path $jobInfo.ErrFile)
    {
        Get-Content $jobInfo.ErrFile -Raw
    }
    else
    {
        ''
    }

    # Store in dev_run cache (same format as dev_run tool)
    Set-Item -Path "env:${Name}_stdout" -Value $stdout
    Set-Item -Path "env:${Name}_stderr" -Value $stderr


    # Create streams JSON (Error stream from stderr, Output from stdout)
    # External processes can't capture Warning/Verbose/Debug/Information (PowerShell streams only)
    $streams = @{
        Error = if ($stderr)
        {
            $stderr -split "`n"
        }
        else
        {
            @()
        }
        Warning = @()
        Output = if ($stdout)
        {
            $stdout -split "`n"
        }
        else
        {
            @()
        }
        Verbose = @()
        Debug = @()
        Information = @()
    }
    Set-Item -Path "env:${Name}_streams" -Value ($streams | ConvertTo-Json -Compress)

    # Store original command for re-run capability
    Set-Item -Path "env:$Name" -Value "$($jobInfo.FilePath) $($jobInfo.Arguments)"

    # Invalidate cache to force reload on next Get-StreamData
    if ($global:DevRunCache.ContainsKey($Name))
    {
        $removed = $null
        $global:DevRunCache.TryRemove($Name, [ref]$removed) | Out-Null
    }

    # Cleanup temp files unless -KeepFiles
    if (-not $KeepFiles)
    {
        Remove-Item $jobInfo.OutFile -ErrorAction SilentlyContinue
        Remove-Item $jobInfo.ErrFile -ErrorAction SilentlyContinue
    }

    # Remove from tracking
    $global:BrickBackgroundJobs.Remove($Name)

    # Return summary (like dev_run)
    $errorCount = ($streams.Error | Where-Object { $_ }).Count
    $outputLines = ($streams.Output | Where-Object { $_ }).Count

    [PSCustomObject]@{
        Name = $Name
        Stopped = Get-Date
        Duration = (Get-Date) - $jobInfo.StartTime
        ErrorLines = $errorCount
        OutputLines = $outputLines
        TopErrors = $streams.Error | Where-Object { $_ } | Select-Object -First 3
    } | Add-Member -TypeName 'AgentBricks.BackgroundProcessResult' -PassThru
}

function Get-BackgroundData
{
    <#
    .SYNOPSIS
    Retrieve background process output from dev_run cache.

    .DESCRIPTION
    Convenience wrapper over Get-StreamData for background processes.
    Retrieves captured output for analysis with AgentBricks functions.

    Functionally identical to Get-StreamData - use whichever feels more natural.
    This function exists for semantic clarity when working with background processes.

    .PARAMETER Name
    Name of background process (from Invoke-BackgroundProcess).

    .PARAMETER Stream
    Which stream to retrieve (Error, Warning, Output, etc.).

    .EXAMPLE
    Get-BackgroundData build Error | Find-Errors | Format-Count

    .EXAMPLE
    Get-BackgroundData server Output | Select-RegexMatch -Pattern 'Listening on (?<port>\d+)'

    .EXAMPLE
    # Equivalent to Get-StreamData
    Get-BackgroundData test Error | Group-BuildErrors
    Get-StreamData test Error | Group-BuildErrors

    .NOTES
    Alias for Get-StreamData - use whichever is clearer in context.
    Requires Stop-BackgroundProcess to have been called first to populate cache.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [ValidateSet('Error', 'Warning', 'Output', 'Verbose', 'Debug', 'Information')]
        [string]$Stream = 'Output'
    )

    Get-StreamData -Name $Name -Stream $Stream
}

function Test-BackgroundProcess
{
    <#
    .SYNOPSIS
    Check status of background process.

    .DESCRIPTION
    Returns process information if running, or stopped status if completed.
    Useful for monitoring multiple background processes or checking if process
    is still active before stopping.

    .PARAMETER Name
    Name of background process to check.

    .EXAMPLE
    Test-BackgroundProcess -Name 'devserver'

    Name      Running PID   CPU MemoryMB Runtime          Command
    ----      ------- ---   --- -------- -------          -------
    devserver True    12345 2.5 125.34   00:05:23.4567890 dotnet run --project Server.csproj

    .EXAMPLE
    # Monitor multiple processes
    'server','worker','watcher' | ForEach-Object { Test-BackgroundProcess -Name $_ }

    .EXAMPLE
    # Check before stopping
    $status = Test-BackgroundProcess -Name 'build'
    if ($status.Running) {
        Stop-BackgroundProcess -Name 'build'
    }

    .NOTES
    Returns PSCustomObject with Running, PID, CPU, Memory, Runtime, Command properties.
    If process not found or has ended, Running is $false.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Name
    )

    process {
        if (-not $global:BrickBackgroundJobs -or -not $global:BrickBackgroundJobs.ContainsKey($Name))
        {
            [PSCustomObject]@{
                Name = $Name
                Running = $false
                Status = 'Not Found'
            }
            return
        }

        $jobInfo = $global:BrickBackgroundJobs[$Name]
        $proc = Get-Process -Id $jobInfo.PID -ErrorAction SilentlyContinue

        if ($proc)
        {
            [PSCustomObject]@{
                Name = $Name
                Running = $true
                PID = $proc.Id
                CPU = $proc.CPU
                MemoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
                Runtime = (Get-Date) - $jobInfo.StartTime
                Command = "$( $jobInfo.FilePath ) $( $jobInfo.Arguments )"
            } | Add-Member -TypeName 'AgentBricks.BackgroundProcessStatus' -PassThru
        }
        else
        {
            [PSCustomObject]@{
                Name = $Name
                Running = $false
                Status = 'Process Ended'
                StartTime = $jobInfo.StartTime
            }
        }
    }
}
