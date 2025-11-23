# DevRun Cache Layer Implementation
# Provides performant $global cache on top of $env JSON persistence
# Cache initialization handled by C# SessionManager.cs

# Script registry cache (separate from execution cache)
if (-not $global:DevRunScripts)
{
    $global:DevRunScripts = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
}

# Initialize-DevRunCache deleted - C# SessionManager.cs handles cache initialization

function Get-CachedStreamData
{
    <#
    .SYNOPSIS
    Get stream data from cache, warming from $env JSON if needed.

    .DESCRIPTION
    Retrieves stream data with cache-first strategy:
    1. Check $global:DevRunCache for cached data
    2. If miss, load from $env:{name}_streams JSON
    3. Cache the parsed data for future access
    4. Return requested stream

    Significantly faster than parsing JSON on every Get-StreamData call.

    .PARAMETER Name
    Script name (e.g., "build" from dev_run with name="build").

    .PARAMETER Stream
    Stream to retrieve: Error, Warning, Verbose, Debug, Information, Output.

    .PARAMETER Force
    Force reload from $env (invalidate cache).

    .EXAMPLE
    PS> Get-CachedStreamData -Name "build" -Stream Error
    Returns cached Error stream for "build" script

    .EXAMPLE
    PS> Get-CachedStreamData -Name "build" -Stream Error -Force
    Invalidates cache and reloads from $env:build_streams

    .NOTES
    Cache automatically invalidated when dev_run executes with same name.
    Use -Force to manually invalidate (e.g., if $env was modified externally).
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

    # Force invalidation if requested
    if ($Force -and $global:DevRunCache.ContainsKey($Name))
    {
        $removed = $null
        $global:DevRunCache.TryRemove($Name, [ref]$removed) | Out-Null
        Write-Verbose "Cache invalidated for '$Name'"
    }

    # Try to get from cache
    $cached = $null
    if ( $global:DevRunCache.TryGetValue($Name, [ref]$cached))
    {
        Write-Verbose "Cache hit for '$Name'"
        if ($cached -and $cached.ContainsKey($Stream))
        {
            return $cached[$Stream]
        }
        else
        {
            Write-Warning "Stream '$Stream' not found in cached data for '$Name'"
            return
        }
    }

    # Cache miss - load from $env
    Write-Verbose "Cache miss for '$Name', loading from environment"

    $envVarName = "${Name}_streams"
    $json = Get-Item "env:$envVarName" -ErrorAction SilentlyContinue

    if (-not $json)
    {
        Write-Error "No stream data found for '$Name'. Run dev_run with name='$Name' first."
        return
    }

    try
    {
        # Parse JSON and cache it
        $data = $json.Value | ConvertFrom-Json -AsHashtable

        # Store in cache
        $global:DevRunCache.TryAdd($Name, $data) | Out-Null
        Write-Verbose "Cached stream data for '$Name'"

        # Return requested stream
        if ( $data.ContainsKey($Stream))
        {
            return $data[$Stream]
        }
        else
        {
            Write-Warning "Stream '$Stream' not found in data for '$Name'"
        }
    }
    catch
    {
        Write-Error "Failed to parse JSON from $envVarName : $_"
    }
}

function Clear-DevRunCache
{
    <#
    .SYNOPSIS
    Clear cached DevRun data.

    .DESCRIPTION
    Invalidates cache entries for DevRun stream data. Useful after running
    dev_run again with same name to ensure fresh data is loaded.

    Can clear specific script's cache or all cached data.

    .PARAMETER Name
    Script name to clear from cache. If omitted, clears all cache entries.

    .EXAMPLE
    PS> Clear-DevRunCache -Name "build"
    Clears cached data for "build" script only

    .EXAMPLE
    PS> Clear-DevRunCache
    Clears all cached DevRun data

    .NOTES
    Does not affect $env storage - only in-memory cache.
    Next Get-CachedStreamData call will reload from $env.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name
    )

    if ($Name)
    {
        # Clear specific cache entry
        $removed = $null
        if ( $global:DevRunCache.TryRemove($Name, [ref]$removed))
        {
            Write-Host "Cleared cache for '$Name'" -ForegroundColor Green
        }
        else
        {
            Write-Warning "No cache entry found for '$Name'"
        }
    }
    else
    {
        # Clear all cache
        $count = $global:DevRunCache.Count
        $global:DevRunCache.Clear()
        Write-Host "Cleared all DevRun cache ($count entries)" -ForegroundColor Green
    }
}

function Get-DevRunCacheStats
{
    <#
    .SYNOPSIS
    Display DevRun cache statistics.

    .DESCRIPTION
    Shows overview of current cache state including cached scripts count,
    script registry count, and lists of cached names.

    Useful for debugging cache behavior and understanding cache hit patterns.

    .EXAMPLE
    PS> Get-DevRunCacheStats

    DevRun Cache Statistics
    =======================
    Cached Streams: 3
    Script Registry: 2

    Cached Scripts:
      build
      test
      analyze

    Registered Scripts:
      build (2024-11-18 12:34:56)
      test (2024-11-18 12:40:12)

    .NOTES
    Does not show cache memory usage (future enhancement).
    #>
    [CmdletBinding()]
    param()

    Write-Host "`nDevRun Cache Statistics" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    Write-Host "Cached Streams: $( $global:DevRunCache.Count )"
    Write-Host "Script Registry: $( $global:DevRunScripts.Count )"
    Write-Host ""

    if ($global:DevRunCache.Count -gt 0)
    {
        Write-Host "Cached Scripts:" -ForegroundColor Cyan
        foreach ($key in ($global:DevRunCache.Keys | Sort-Object))
        {
            Write-Host "  $key" -ForegroundColor White
        }
        Write-Host ""
    }

    if ($global:DevRunScripts.Count -gt 0)
    {
        Write-Host "Registered Scripts:" -ForegroundColor Cyan
        foreach ($key in ($global:DevRunScripts.Keys | Sort-Object))
        {
            $metadata = $global:DevRunScripts[$key]
            $timestamp = if ($metadata.Timestamp)
            {
                $metadata.Timestamp
            }
            else
            {
                "unknown"
            }
            Write-Host "  $key ($timestamp)" -ForegroundColor White
        }
        Write-Host ""
    }
}

function Add-DevScript
{
    <#
    .SYNOPSIS
    Register script metadata in $global:DevRunScripts registry.

    .DESCRIPTION
    Stores script metadata (text, timestamp, exit code, dependencies) in the
    global script registry. This enables script invocation, chaining, and
    tracking of script execution history.

    Typically called automatically by dev_run, but can be used manually to
    register scripts for invocation.

    .PARAMETER Name
    Script name (used as registry key).

    .PARAMETER Script
    PowerShell script text to store.

    .PARAMETER ExitCode
    Exit code from last execution (default: 0).

    .PARAMETER Dependencies
    Optional array of script names this script depends on.

    .EXAMPLE
    PS> Add-DevScript -Name "build" -Script "dotnet build"
    Registered script 'build'

    .EXAMPLE
    PS> Add-DevScript -Name "test" -Script "dotnet test" -Dependencies @("build")
    Registered script 'test' with dependency on 'build'

    .NOTES
    Overwrites existing script with same name.
    Use Get-DevScripts to list registered scripts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [string]$Script,

        [Parameter()]
        [int]$ExitCode = 0,

        [Parameter()]
        [string[]]$Dependencies = @()
    )

    $metadata = @{
        Script = $Script
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        ExitCode = $ExitCode
        Dependencies = $Dependencies
    }

    $global:DevRunScripts[$Name] = $metadata
    Write-Verbose "Registered script '$Name'"
    Write-Host "Registered script '$Name'" -ForegroundColor Green
}

function Get-DevScripts
{
    <#
    .SYNOPSIS
    List all registered scripts with metadata.

    .DESCRIPTION
    Displays all scripts in $global:DevRunScripts registry with their metadata
    including timestamp, exit code, and dependencies.

    Useful for discovering available scripts for invocation and chaining.

    .PARAMETER Name
    Filter to specific script name. If omitted, shows all scripts.

    .PARAMETER Detailed
    Show full script text and all metadata.

    .EXAMPLE
    PS> Get-DevScripts

    Registered Scripts (3)
    ======================
    Name      Timestamp            ExitCode Dependencies
    ----      ---------            -------- ------------
    build     2024-11-18 12:34:56  0
    test      2024-11-18 12:40:12  0        build
    deploy    2024-11-18 13:15:30  1        build, test

    .EXAMPLE
    PS> Get-DevScripts -Name "build" -Detailed
    Name: build
    Script: dotnet build
    Timestamp: 2024-11-18 12:34:56
    ExitCode: 0
    Dependencies: (none)

    .NOTES
    Scripts registered automatically by dev_run or manually via Add-DevScript.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [Parameter()]
        [switch]$Detailed
    )

    if ($global:DevRunScripts.Count -eq 0)
    {
        Write-Host "No scripts registered" -ForegroundColor Yellow
        return
    }

    if ($Name)
    {
        # Show specific script
        $metadata = $null
        if ( $global:DevRunScripts.TryGetValue($Name, [ref]$metadata))
        {
            if ($Detailed)
            {
                Write-Host "`nName: $Name" -ForegroundColor Cyan
                Write-Host "Script: $( $metadata.Script )"
                Write-Host "Timestamp: $( $metadata.Timestamp )"
                Write-Host "ExitCode: $( $metadata.ExitCode )"
                $deps = if ($metadata.Dependencies.Count -gt 0)
                {
                    $metadata.Dependencies -join ", "
                }
                else
                {
                    "(none)"
                }
                Write-Host "Dependencies: $deps"
            }
            else
            {
                [PSCustomObject]@{
                    Name = $Name
                    Timestamp = $metadata.Timestamp
                    ExitCode = $metadata.ExitCode
                    Dependencies = $metadata.Dependencies -join ", "
                }
            }
        }
        else
        {
            Write-Warning "Script '$Name' not found in registry"
        }
        return
    }

    # Show all scripts
    Write-Host "`nRegistered Scripts ($( $global:DevRunScripts.Count ))" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan

    if ($Detailed)
    {
        foreach ($key in ($global:DevRunScripts.Keys | Sort-Object))
        {
            $metadata = $global:DevRunScripts[$key]
            Write-Host "`nName: $key" -ForegroundColor White
            Write-Host "  Script: $( $metadata.Script )" -ForegroundColor Gray
            Write-Host "  Timestamp: $( $metadata.Timestamp )" -ForegroundColor Gray
            Write-Host "  ExitCode: $( $metadata.ExitCode )" -ForegroundColor Gray
            $deps = if ($metadata.Dependencies.Count -gt 0)
            {
                $metadata.Dependencies -join ", "
            }
            else
            {
                "(none)"
            }
            Write-Host "  Dependencies: $deps" -ForegroundColor Gray
        }
        Write-Host ""
    }
    else
    {
        $scripts = foreach ($key in ($global:DevRunScripts.Keys | Sort-Object))
        {
            $metadata = $global:DevRunScripts[$key]
            [PSCustomObject]@{
                Name = $key
                Timestamp = $metadata.Timestamp
                ExitCode = $metadata.ExitCode
                Dependencies = $metadata.Dependencies -join ", "
            }
        }
        $scripts | Format-Table -AutoSize | Out-String
    }
}

function Remove-DevScript
{
    <#
    .SYNOPSIS
    Remove script from $global:DevRunScripts registry.

    .DESCRIPTION
    Removes script metadata from global registry. Useful for cleanup or
    removing obsolete scripts.

    Does not affect cached stream data (use Clear-DevRunCache for that).

    .PARAMETER Name
    Script name to remove.

    .EXAMPLE
    PS> Remove-DevScript -Name "build"
    Removed script 'build' from registry

    .NOTES
    Does not check for dependencies - other scripts may reference removed script.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name
    )

    $removed = $null
    if ( $global:DevRunScripts.TryRemove($Name, [ref]$removed))
    {
        Write-Host "Removed script '$Name' from registry" -ForegroundColor Green
    }
    else
    {
        Write-Warning "Script '$Name' not found in registry"
    }
}

function Update-DevScriptMetadata
{
    <#
    .SYNOPSIS
    Update metadata for registered script.

    .DESCRIPTION
    Updates timestamp, exit code, or dependencies for an existing registered script.
    Script text is not modified.

    Useful for tracking re-runs or updating dependencies.

    .PARAMETER Name
    Script name to update.

    .PARAMETER ExitCode
    New exit code value.

    .PARAMETER UpdateTimestamp
    Update timestamp to current time.

    .PARAMETER Dependencies
    New dependencies array (replaces existing).

    .EXAMPLE
    PS> Update-DevScriptMetadata -Name "build" -ExitCode 0 -UpdateTimestamp
    Updated metadata for script 'build'

    .NOTES
    At least one update parameter must be specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter()]
        [int]$ExitCode,

        [Parameter()]
        [switch]$UpdateTimestamp,

        [Parameter()]
        [string[]]$Dependencies
    )

    $metadata = $null
    if (-not $global:DevRunScripts.TryGetValue($Name, [ref]$metadata))
    {
        Write-Error "Script '$Name' not found in registry"
        return
    }

    # Update fields
    if ( $PSBoundParameters.ContainsKey('ExitCode'))
    {
        $metadata.ExitCode = $ExitCode
    }

    if ($UpdateTimestamp)
    {
        $metadata.Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }

    if ( $PSBoundParameters.ContainsKey('Dependencies'))
    {
        $metadata.Dependencies = $Dependencies
    }

    # Update in registry
    $global:DevRunScripts[$Name] = $metadata
    Write-Host "Updated metadata for script '$Name'" -ForegroundColor Green
}

function Invoke-DevScript
{
    <#
    .SYNOPSIS
    Execute a registered script from $global:DevRunScripts registry.

    .DESCRIPTION
    Retrieves and executes a script previously registered via Add-DevScript or dev_run.
    Useful for re-running saved scripts, chaining scripts, or building workflows.

    Script is executed in the current PowerShell session with access to all variables
    and modules.

    .PARAMETER Name
    Script name to execute (must exist in registry).

    .PARAMETER UpdateMetadata
    Update metadata (timestamp, exit code) after execution.

    .PARAMETER PassThru
    Return execution result objects.

    .EXAMPLE
    PS> Invoke-DevScript -Name "build"
    Executes the 'build' script from registry

    .EXAMPLE
    PS> Invoke-DevScript -Name "test" -UpdateMetadata
    Executes 'test' script and updates timestamp/exit code

    .EXAMPLE
    PS> $results = Invoke-DevScript -Name "analyze" -PassThru
    Executes script and captures output

    .NOTES
    Script must be registered via Add-DevScript or dev_run first.
    Updates $LASTEXITCODE based on script execution.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter()]
        [switch]$UpdateMetadata,

        [Parameter()]
        [switch]$PassThru
    )

    # Retrieve script from registry
    $metadata = $null
    if (-not $global:DevRunScripts.TryGetValue($Name, [ref]$metadata))
    {
        Write-Error "Script '$Name' not found in registry. Use Add-DevScript to register it first."
        return
    }

    Write-Verbose "Executing script '$Name': $( $metadata.Script )"

    # Execute script
    try
    {
        $result = Invoke-Expression $metadata.Script

        # Update metadata if requested
        if ($UpdateMetadata)
        {
            Update-DevScriptMetadata -Name $Name -ExitCode $LASTEXITCODE -UpdateTimestamp
        }

        # Return result if requested
        if ($PassThru)
        {
            return $result
        }
    }
    catch
    {
        Write-Error "Failed to execute script '$Name': $_"
        if ($UpdateMetadata)
        {
            Update-DevScriptMetadata -Name $Name -ExitCode 1 -UpdateTimestamp
        }
    }
}

function Invoke-DevScriptChain
{
    <#
    .SYNOPSIS
    Execute multiple registered scripts in sequence.

    .DESCRIPTION
    Executes a chain of registered scripts in order. Useful for multi-step workflows
    like build -> test -> deploy.

    Can optionally stop on first failure or continue through all scripts.

    .PARAMETER Names
    Array of script names to execute in order.

    .PARAMETER ContinueOnError
    Continue executing remaining scripts even if one fails. Default: stop on first failure.

    .PARAMETER UpdateMetadata
    Update metadata (timestamp, exit code) for each script after execution.

    .EXAMPLE
    PS> Invoke-DevScriptChain -Names @("build", "test", "deploy")
    Executes build, then test, then deploy. Stops if any fails.

    .EXAMPLE
    PS> Invoke-DevScriptChain -Names @("lint", "format", "build") -ContinueOnError
    Executes all three scripts even if one fails

    .EXAMPLE
    PS> Invoke-DevScriptChain -Names @("build", "test") -UpdateMetadata
    Executes scripts and updates their metadata

    .NOTES
    All scripts must be registered before chaining.
    Returns summary of executions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Names,

        [Parameter()]
        [switch]$ContinueOnError,

        [Parameter()]
        [switch]$UpdateMetadata
    )

    $results = @()
    $failedCount = 0

    foreach ($name in $Names)
    {
        Write-Host "`nExecuting: $name" -ForegroundColor Cyan

        try
        {
            Invoke-DevScript -Name $name -UpdateMetadata:$UpdateMetadata -ErrorAction Stop

            $results += [PSCustomObject]@{
                Script = $name
                Status = "Success"
                ExitCode = $LASTEXITCODE
            }

            # Stop if failed and not continuing on error
            if ($LASTEXITCODE -ne 0 -and -not $ContinueOnError)
            {
                Write-Warning "Script '$name' failed with exit code $LASTEXITCODE. Stopping chain."
                $failedCount++
                break
            }
            elseif ($LASTEXITCODE -ne 0)
            {
                Write-Warning "Script '$name' failed with exit code $LASTEXITCODE. Continuing..."
                $failedCount++
            }
        }
        catch
        {
            Write-Error "Error executing '$name': $_"

            $results += [PSCustomObject]@{
                Script = $name
                Status = "Failed"
                ExitCode = 1
            }

            $failedCount++

            if (-not $ContinueOnError)
            {
                Write-Warning "Stopping chain due to error."
                break
            }
        }
    }

    # Summary
    Write-Host "`nChain Summary:" -ForegroundColor Cyan
    Write-Host "Total scripts: $( $Names.Count )" -ForegroundColor White
    Write-Host "Executed: $( $results.Count )" -ForegroundColor White
    Write-Host "Successful: $( $results.Count - $failedCount )" -ForegroundColor Green
    Write-Host "Failed: $failedCount" -ForegroundColor $( if ($failedCount -gt 0)
    {
        "Red"
    }
    else
    {
        "Green"
    } )

    return $results
}

# Cache initialization handled by:
# - C# SessionManager.cs: $global:DevRunCache, $global:DevRunCacheCounter
# - PowerShell (lines 6-8 above): $global:DevRunScripts
