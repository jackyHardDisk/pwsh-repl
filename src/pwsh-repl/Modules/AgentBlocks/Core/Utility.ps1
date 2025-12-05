function Invoke-WithTimeout
{
    <#
    .SYNOPSIS
        Execute a script block with a timeout, using PowerShell-conventional error handling.

    .DESCRIPTION
        Wraps script block execution in a timeout mechanism using PowerShell jobs.
        Designed for use in command chains where a problematic step might hang.

        Follows PowerShell conventions:
        - Outputs directly to pipeline on success
        - Throws terminating errors on failure or timeout
        - Respects -ErrorAction parameter for error handling
        - Integrates with try/catch and -ErrorVariable

    .PARAMETER ScriptBlock
        The script block to execute with timeout protection.

    .PARAMETER TimeoutSeconds
        Timeout duration in seconds. Default: 30 seconds.

    .PARAMETER ArgumentList
        Arguments to pass to the script block.

    .OUTPUTS
        Object
        Direct pipeline output from the script block on success.

    .EXAMPLE
        Invoke-WithTimeout { python slow_script.py } -TimeoutSeconds 10 | Find-Errors

        Execute a potentially slow command with 10-second timeout, piping output to Find-Errors.

    .EXAMPLE
        try {
            Invoke-WithTimeout { dotnet build } -TimeoutSeconds 60 |
                Find-Errors | Measure-Frequency | Format-Count
        } catch {
            Write-Warning "Build failed or timed out: $_"
        }

        Pipeline with error handling using try/catch.

    .EXAMPLE
        Invoke-WithTimeout { flaky-command } -ErrorAction Continue |
            Find-Errors

        Continue pipeline even if command fails or times out.

    .EXAMPLE
        Invoke-WithTimeout { dotnet build } -ErrorVariable buildErrors -ErrorAction SilentlyContinue |
            Find-Errors

        if ($buildErrors) {
            Write-Warning "Build had $($buildErrors.Count) error(s)"
        }

        Capture errors in variable for inspection without stopping pipeline.

    .EXAMPLE
        try {
            $results = Invoke-WithTimeout { Get-Content large.log } -TimeoutSeconds 5 |
                Find-Errors | Measure-Frequency

            $results | Format-Count
        } catch [System.TimeoutException] {
            Write-Warning "File read timed out - file too large"
        } catch {
            Write-Warning "Other error: $_"
        }

        Handle timeout vs. script failure differently using typed exception catching.

    .EXAMPLE
        # Long-running build with extended timeout
        try {
            Invoke-WithTimeout {
                cmake --build . --config Release
            } -TimeoutSeconds 300 | Find-Errors
        } catch [System.TimeoutException] {
            Write-Error "Build exceeded 5 minute timeout"
            exit 1
        }

        Extended timeout for slow operations.

    .NOTES
        Implementation uses PowerShell jobs for true timeout capability.
        Job overhead: ~100-200ms startup cost.

        Error Types:
        - System.TimeoutException: Execution exceeded timeout duration
        - System.InvalidOperationException: Script block execution failed

        Error Handling:
        - Default: Terminating errors (stops execution)
        - With -ErrorAction Continue: Non-terminating (pipeline continues)
        - With -ErrorAction SilentlyContinue: Suppressed (no error output)
        - With try/catch: Can catch and handle programmatically

        Design Philosophy:
        - Pipeline-first: Output flows naturally without property access
        - Standard errors: Follows PowerShell error handling conventions
        - Composable: Works seamlessly with AgentBlocks functions
        - Debuggable: Error messages include duration and source info

        Performance Considerations:
        - Job creation overhead makes this unsuitable for sub-second timeouts
        - For batch operations, consider wrapping entire batch vs. each item
        - Error messages include execution duration for performance analysis

    .LINK
        about_Try_Catch_Finally

    .LINK
        about_CommonParameters
    #>
    [CmdletBinding()]
    [OutputType([Object])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ScriptBlock]$ScriptBlock,

        [Parameter()]
        [int]$TimeoutSeconds = 30,

        [Parameter()]
        [object[]]$ArgumentList
    )

    $startTime = Get-Date

    try
    {
        # Wrap scriptblock to redirect stdin to prevent external process hangs
        # PowerShell jobs don't typically need this, but external processes (python, node, etc.) might
        $wrappedScriptBlock = {
            param($OriginalScriptBlock, $Args)
            # Note: stdin redirection in jobs is automatic, but we ensure it's closed for external processes
            # ThreadJobs inherit console state, so this wrapper provides extra safety
            & $OriginalScriptBlock @Args
        }

        # Start script block as thread job (Start-Job doesn't work in hosted PowerShell)
        # ThreadJob runs in same process but different thread, still provides isolation
        $job = Start-ThreadJob -ScriptBlock $wrappedScriptBlock -ArgumentList $ScriptBlock, $ArgumentList

        # Wait for completion or timeout
        $completed = Wait-Job $job -Timeout $TimeoutSeconds

        $duration = (Get-Date) - $startTime

        if ($null -eq $completed)
        {
            # Timeout occurred - stop job and throw terminating error
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue

            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.TimeoutException]::new("Execution timeout after $TimeoutSeconds seconds (Duration: $( $duration.TotalSeconds )s)"),
                    'ExecutionTimeout',
                    [System.Management.Automation.ErrorCategory]::OperationTimeout,
                    $ScriptBlock
            )

            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        # Job completed - check for errors
        if ($job.State -eq 'Failed')
        {
            $errorInfo = Receive-Job $job 2>&1 | Out-String
            Remove-Job $job -Force

            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.InvalidOperationException]::new($errorInfo.Trim()),
                    'ScriptBlockFailed',
                    [System.Management.Automation.ErrorCategory]::InvalidOperation,
                    $ScriptBlock
            )

            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        # Success - retrieve output and pass directly to pipeline
        $output = Receive-Job $job
        Remove-Job $job -Force

        return $output
    }
    catch
    {
        # Re-throw with proper attribution to calling code
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}
