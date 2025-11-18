function Invoke-PythonScript {
    <#
    .SYNOPSIS
        Execute Python script with proper stdin handling to prevent hangs.

    .DESCRIPTION
        Wrapper for Python subprocess execution that handles the common issue where
        Python hangs waiting for stdin when called from PowerShell with redirected streams.

        Key fix: Redirects and closes stdin to prevent Python interactive mode hang.

        Use this instead of Start-Process or direct python.exe calls when working
        with redirected output streams.

    .PARAMETER ScriptPath
        Path to Python script file to execute.

    .PARAMETER Arguments
        Optional arguments to pass to the Python script.

    .PARAMETER TimeoutSeconds
        Maximum execution time in seconds (default: 30).

    .OUTPUTS
        PSCustomObject with properties:
        - ExitCode: Process exit code
        - StandardOutput: Captured stdout
        - StandardError: Captured stderr
        - TimedOut: Boolean indicating if timeout occurred

    .EXAMPLE
        $result = Invoke-PythonScript -ScriptPath "test.py" -TimeoutSeconds 10
        if ($result.ExitCode -eq 0) {
            Write-Output $result.StandardOutput
        }

    .EXAMPLE
        Invoke-PythonScript "analyze.py" -Arguments "input.txt", "gpt-4" |
            Where-Object { $_.ExitCode -eq 0 } |
            Select-Object -ExpandProperty StandardOutput

    .NOTES
        Why this is needed:
        - Python hangs when stdin is redirected but not closed
        - ProcessStartInfo with RedirectStandardInput + Close() fixes this
        - Timeout protection prevents indefinite hangs

        Alternative approaches (NOT recommended):
        - Start-Process -Wait: Blocks forever, no timeout
        - python -c "...": Quote escaping issues in PowerShell
        - & python: Inherits console, can't capture output cleanly
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ScriptPath,

        [Parameter()]
        [string[]]$Arguments = @(),

        [Parameter()]
        [int]$TimeoutSeconds = 30
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "python"

    # Build argument list with proper quoting
    $argList = "`"$ScriptPath`""
    foreach ($arg in $Arguments) {
        $argList += " `"$arg`""
    }
    $startInfo.Arguments = $argList

    # Critical settings to prevent hangs
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardInput = $true  # Must redirect to close it
    $startInfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($startInfo)
    $process.StandardInput.Close()  # Close stdin immediately (prevents hang)

    $timeoutMs = $TimeoutSeconds * 1000
    $timedOut = -not $process.WaitForExit($timeoutMs)

    if ($timedOut) {
        $process.Kill()
        $process.WaitForExit(1000)  # Wait for kill to complete
    }

    # Read output (do this AFTER WaitForExit to avoid deadlocks)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $exitCode = if ($timedOut) { -1 } else { $process.ExitCode }

    $process.Dispose()

    [PSCustomObject]@{
        ExitCode = $exitCode
        StandardOutput = $stdout
        StandardError = $stderr
        TimedOut = $timedOut
    }
}
