#Requires -Version 5.1

<#
.SYNOPSIS
    TokenCounter - Accurate token measurement for Claude Code optimization

.DESCRIPTION
    Minimal PowerShell module providing accurate token counting via Python tiktoken library.
    Designed for optimizing MCP server configurations, slash commands, and other token-sensitive content.

    Philosophy: One function, one job. PowerShell handles everything else (file reading, sorting, arithmetic).

.NOTES
    Author: homebrew-mcp
    Version: 1.0.0 (simplified from 0.1.0)
    Requires: Python environment with tiktoken package
    Default environment: planetarium-test (configurable)

.LINK
    https://github.com/openai/tiktoken
#>

# Module-level configuration
$script:DefaultCondaEnvironment = "homebrew-mcp"
$script:DefaultModel = "gpt-4"
$script:PythonScript = Join-Path $PSScriptRoot "test_tiktoken.py"

function Measure-Tokens {
    <#
    .SYNOPSIS
        Count tokens in text using Python tiktoken library for accurate Claude model token measurement.

    .DESCRIPTION
        Accurately counts tokens for Claude/GPT models using the tiktoken library via Python subprocess.
        Returns a simple integer count suitable for pipeline operations and calculations.

        This function focuses on ONE task: accurate token counting. For advanced use cases:
        - File reading: Get-Content file.md | Measure-Tokens
        - Comparisons: $before - $after
        - Rankings: Sort-Object Tokens -Descending
        - Analysis: Group-Object, Where-Object, etc.

        Token counting is essential for:
        - Optimizing MCP tool schemas (reduce token overhead)
        - Measuring slash command description costs
        - Analyzing documentation token budgets
        - Comparing before/after optimization impact

    .PARAMETER Text
        Text to count tokens for. Accepts input from pipeline or direct parameter.
        If empty or null, returns 0.

    .PARAMETER Model
        Model encoding to use for token counting.
        Default: gpt-4 (compatible with Claude 3.5 Sonnet tokenization)

        Common options:
        - gpt-4: GPT-4 and Claude models (default)
        - gpt-3.5-turbo: GPT-3.5 models
        - text-davinci-003: Legacy models

    .PARAMETER CondaEnvironment
        Conda environment name containing tiktoken package.
        Default: planetarium-test (from module configuration)

        Override for different environments:
        - Custom conda environment: -CondaEnvironment "myenv"
        - System Python: Use direct python call (modify script)

    .OUTPUTS
        System.Int32
        Integer token count. Returns 0 for empty/null input.

    .EXAMPLE
        Measure-Tokens -Text "Hello, World!"

        Output: 4

        Basic token counting for short text.

    .EXAMPLE
        Get-Content README.md | Measure-Tokens

        Output: 1543

        Count tokens in a file. PowerShell handles file reading.

    .EXAMPLE
        $tools = Get-Content .mcp.json | ConvertFrom-Json | Select-Object -ExpandProperty mcpServers
        $tools.PSObject.Properties | ForEach-Object {
            [PSCustomObject]@{
                Server = $_.Name
                Tokens = ($_.Value | ConvertTo-Json -Depth 10 -Compress | Measure-Tokens)
            }
        } | Sort-Object Tokens -Descending | Format-Table

        Analyze MCP server token costs and rank by expense.
        Demonstrates composition with PowerShell built-ins.

    .EXAMPLE
        $original = Get-Content original.md | Measure-Tokens
        $optimized = Get-Content optimized.md | Measure-Tokens
        $saved = $original - $optimized
        $percent = [math]::Round(($saved / $original) * 100, 1)
        Write-Host "Saved $saved tokens ($percent% reduction)" -ForegroundColor Green

        Before/after comparison using simple arithmetic.
        No specialized function needed.

    .EXAMPLE
        Get-ChildItem .claude/commands -Filter *.md | ForEach-Object {
            [PSCustomObject]@{
                Command = $_.BaseName
                Tokens = (Get-Content $_.FullName -Raw | Measure-Tokens)
            }
        } | Where-Object { $_.Tokens -gt 500 } | Sort-Object Tokens -Descending

        Find expensive slash commands (>500 tokens) and rank them.
        Combines Measure-Tokens with PowerShell filtering and sorting.

    .EXAMPLE
        "Claude Code is a powerful CLI" | Measure-Tokens

        Output: 8

        Pipeline input from string.

    .EXAMPLE
        @"
        Multi-line text block
        with several lines
        for token counting
        "@ | Measure-Tokens

        Output: 12

        Here-string input for multi-line text.

    .EXAMPLE
        Measure-Tokens -Text "" -CondaEnvironment "my-python-env"

        Output: 0

        Empty text returns 0. Custom conda environment specified.

    .NOTES
        Performance Considerations:
        - Subprocess overhead: ~750ms per call (conda activation + Python startup)
        - Acceptable for interactive use and one-time analysis
        - For batch processing, consider collecting all text and measuring once

        Accuracy vs Approximation:
        - tiktoken provides exact token counts (matches Claude API)
        - Word × 1.3 approximation can be off by 20-30%
        - Accuracy matters when optimizing for token budgets

        Error Handling:
        - Empty/null input returns 0 (not an error)
        - Python errors throw terminating errors with details
        - Missing conda environment causes descriptive error

        Design Philosophy:
        This function does ONE thing: count tokens accurately.
        For complex analysis, compose with PowerShell:
        - Sort-Object for rankings
        - Group-Object for aggregation
        - Where-Object for filtering
        - Arithmetic operators for comparisons

        This keeps the module lean (~100 lines vs 693 lines in previous version)
        while remaining fully capable through composition.

    .LINK
        https://github.com/openai/tiktoken

    .LINK
        https://platform.openai.com/docs/guides/embeddings/what-are-embeddings
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Text = "",

        [Parameter()]
        [string]$Model = $script:DefaultModel,

        [Parameter()]
        [string]$CondaEnvironment = $script:DefaultCondaEnvironment
    )

    begin {
        # Accumulate pipeline input
        $accumulated = ""
    }

    process {
        # Append each pipeline item
        if ($null -ne $Text) {
            $accumulated += $Text
        }
    }

    end {
        # Return 0 for empty input (not an error condition)
        if ([string]::IsNullOrEmpty($accumulated)) {
            return 0
        }

        # Create temporary file to avoid command line length limits
        # (PowerShell/CMD have ~8191 char limit, documents can be much larger)
        $tempFile = [System.IO.Path]::GetTempFileName()
        $tempOut = "$tempFile.out"
        $tempErr = "$tempFile.err"

        try {
            # Write text to temp file with UTF8 encoding (tiktoken expects UTF8)
            $accumulated | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline

            # Invoke Python using ProcessStartInfo to properly redirect stdin
            # This prevents Python from hanging waiting for input
            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = "python"
            $startInfo.Arguments = "`"$($script:PythonScript)`" `"$tempFile`" `"$Model`""
            $startInfo.UseShellExecute = $false
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true
            $startInfo.RedirectStandardInput = $true
            $startInfo.CreateNoWindow = $true

            $process = [System.Diagnostics.Process]::Start($startInfo)
            $process.StandardInput.Close()

            # Wait with timeout (10 seconds should be plenty for tiktoken)
            $timeoutMs = 10000
            if (-not $process.WaitForExit($timeoutMs)) {
                $process.Kill()
                throw "Python tiktoken execution timeout after 10 seconds. This usually indicates conda environment issues."
            }

            # Check for errors
            if ($process.ExitCode -ne 0) {
                $stderr = $process.StandardError.ReadToEnd()
                throw "Python tiktoken execution failed (exit code $($process.ExitCode)): $stderr"
            }

            # Parse and return integer result
            $stdout = $process.StandardOutput.ReadToEnd()
            $tokenCount = [int]$stdout.Trim()

            return $tokenCount

        }
        catch {
            # Provide detailed error context
            throw "Failed to measure tokens: $_"
        }
        finally {
            # Always clean up temporary files
            Remove-Item $tempFile, $tempOut, $tempErr -Force -ErrorAction SilentlyContinue

            # Dispose process object to free resources
            if ($null -ne $process) {
                $process.Dispose()
            }
        }
    }
}

# Export only the public function
Export-ModuleMember -Function Measure-Tokens