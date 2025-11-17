function Find-Errors {
    <#
    .SYNOPSIS
    Extract and count errors from text output.

    .DESCRIPTION
    Searches input text for error patterns and returns frequency analysis of errors found.
    By default, uses common error keywords (error, exception, failed, failure) but supports
    custom patterns for project-specific error formats.

    Results are automatically grouped and sorted by frequency, making it easy to identify
    the most common errors in build logs, test output, or application logs.

    .PARAMETER InputObject
    Text to search. Can be array of strings, file content, or pipeline input.

    .PARAMETER Source
    Path to file to analyze. Alternative to piping content.

    .PARAMETER Pattern
    Custom regex pattern for matching errors. Default: \b(error|exception|failed|failure)\b

    .PARAMETER CaseSensitive
    Make pattern matching case-sensitive. Default is case-insensitive.

    .PARAMETER Top
    Return only top N most frequent errors. Default is all errors.

    .EXAMPLE
    PS> Find-Errors build.log
         42x: error: Cannot find module 'foo'
         12x: error: Undefined variable 'bar'
          3x: error: Type mismatch

    .EXAMPLE
    PS> Get-Content test-output.txt | Find-Errors -Top 5
    # Show only top 5 most common errors

    .EXAMPLE
    PS> Find-Errors app.log -Pattern "FATAL|ERROR|EXCEPTION"
    # Custom pattern for Java-style logging

    .EXAMPLE
    PS> $env:build_stderr | Find-Errors | Format-Count -Width 4
    # Analyze errors from dev-run stored output

    .NOTES
    Returns PSCustomObject with Count and Item properties for easy formatting.
    Blank lines and non-matching lines are ignored.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Pipeline')]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'Pipeline')]
        $InputObject,

        [Parameter(Position = 0, ParameterSetName = 'File')]
        [string]$Source,

        [Parameter()]
        [string]$Pattern = '\b(error|exception|failed|failure)\b',

        [Parameter()]
        [switch]$CaseSensitive,

        [Parameter()]
        [int]$Top
    )

    begin {
        $lines = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Pipeline') {
            if ($InputObject) {
                $lines += $InputObject.ToString()
            }
        }
    }

    end {
        # Read from file if Source parameter used
        if ($Source) {
            if (Test-Path $Source) {
                $lines = Get-Content $Source
            } else {
                Write-Error "File not found: $Source"
                return
            }
        }

        # Filter lines matching error pattern
        $options = if ($CaseSensitive) { 'None' } else { 'IgnoreCase' }
        $errors = $lines | Where-Object {
            $_ -match $Pattern
        } | Where-Object {
            # Filter out blank lines
            $_.Trim().Length -gt 0
        }

        # Group and count
        $result = $errors | Group-Object | Sort-Object Count -Descending

        # Convert to standard format
        $formatted = $result | ForEach-Object {
            [PSCustomObject]@{
                Count = $_.Count
                Item = $_.Name.Trim()
            }
        }

        # Apply Top filter if specified
        if ($Top) {
            $formatted | Select-Object -First $Top
        } else {
            $formatted
        }
    }
}

function Find-Warnings {
    <#
    .SYNOPSIS
    Extract and count warnings from text output.

    .DESCRIPTION
    Searches input text for warning patterns and returns frequency analysis of warnings found.
    Similar to Find-Errors but specifically targets warning-level messages.

    By default matches common warning keywords, but supports custom patterns for
    language-specific or tool-specific warning formats.

    .PARAMETER InputObject
    Text to search. Can be array of strings, file content, or pipeline input.

    .PARAMETER Source
    Path to file to analyze. Alternative to piping content.

    .PARAMETER Pattern
    Custom regex pattern for matching warnings. Default: \bwarning\b

    .PARAMETER CaseSensitive
    Make pattern matching case-sensitive. Default is case-insensitive.

    .PARAMETER Top
    Return only top N most frequent warnings. Default is all warnings.

    .EXAMPLE
    PS> Find-Warnings build.log
         15x: warning: Unused variable 'temp'
          8x: warning: Deprecated function usage
          3x: warning: Missing semicolon

    .EXAMPLE
    PS> Get-Content compiler.log | Find-Warnings -Pattern "warning (C\d+):" | Format-Count
    # Extract MSVC warning codes

    .EXAMPLE
    PS> Find-Warnings eslint-output.txt -Top 10
    # Show top 10 ESLint warnings

    .NOTES
    Returns PSCustomObject with Count and Item properties.
    Particularly useful for code quality analysis and identifying common code smells.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Pipeline')]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'Pipeline')]
        $InputObject,

        [Parameter(Position = 0, ParameterSetName = 'File')]
        [string]$Source,

        [Parameter()]
        [string]$Pattern = '\bwarning\b',

        [Parameter()]
        [switch]$CaseSensitive,

        [Parameter()]
        [int]$Top
    )

    begin {
        $lines = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Pipeline') {
            if ($InputObject) {
                $lines += $InputObject.ToString()
            }
        }
    }

    end {
        # Read from file if Source parameter used
        if ($Source) {
            if (Test-Path $Source) {
                $lines = Get-Content $Source
            } else {
                Write-Error "File not found: $Source"
                return
            }
        }

        # Filter lines matching warning pattern
        $options = if ($CaseSensitive) { 'None' } else { 'IgnoreCase' }
        $warnings = $lines | Where-Object {
            $_ -match $Pattern
        } | Where-Object {
            $_.Trim().Length -gt 0
        }

        # Group and count
        $result = $warnings | Group-Object | Sort-Object Count -Descending

        # Convert to standard format
        $formatted = $result | ForEach-Object {
            [PSCustomObject]@{
                Count = $_.Count
                Item = $_.Name.Trim()
            }
        }

        # Apply Top filter if specified
        if ($Top) {
            $formatted | Select-Object -First $Top
        } else {
            $formatted
        }
    }
}

function Parse-BuildOutput {
    <#
    .SYNOPSIS
    Parse build errors from common build tools (MSBuild, GCC, CMake, etc.).

    .DESCRIPTION
    Analyzes build output from various compilers and build systems, extracting
    structured error information including file, line, column, error code, and message.

    Automatically detects output format from common build tools:
    - MSBuild/Visual Studio: file(line,col): error C####: message
    - GCC/Clang: file:line:col: error: message
    - CMake: CMake Error at file:line (function): message
    - Maven/Gradle: [ERROR] message

    Returns structured objects for easy filtering and analysis.

    .PARAMETER InputObject
    Build output text. Can be piped from Get-Content or stored dev-run output.

    .PARAMETER Source
    Path to build log file. Alternative to piping content.

    .PARAMETER ToolType
    Hint about build tool type: 'MSBuild', 'GCC', 'CMake', 'Maven'. Auto-detects if omitted.

    .EXAMPLE
    PS> Parse-BuildOutput build.log

    File          Line Col Code Message
    ----          ---- --- ---- -------
    Program.cs    42   15  CS0103 The name 'foo' does not exist
    Utils.cs      128  8   CS0029 Cannot convert type 'int' to 'string'

    .EXAMPLE
    PS> Get-Content cmake-output.txt | Parse-BuildOutput -ToolType CMake
    # Parse CMake configure errors

    .EXAMPLE
    PS> $env:build_stderr | Parse-BuildOutput | Where-Object { $_.Code -like "CS*" }
    # Filter C# compiler errors from dev-run output

    .EXAMPLE
    PS> Parse-BuildOutput gcc.log | Group-Object File | Sort-Object Count -Descending
    # Find files with most errors

    .NOTES
    Returns PSCustomObject with File, Line, Col, Code, Message properties.
    Not all fields available for all build tools (e.g., Maven errors lack file/line).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Pipeline')]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'Pipeline')]
        $InputObject,

        [Parameter(Position = 0, ParameterSetName = 'File')]
        [string]$Source,

        [Parameter()]
        [ValidateSet('MSBuild', 'GCC', 'CMake', 'Maven', 'Auto')]
        [string]$ToolType = 'Auto'
    )

    begin {
        $lines = @()

        # Define patterns for different build tools
        $patterns = @{
            MSBuild = '(?<file>[\w/\\.-]+)\((?<line>\d+),(?<col>\d+)\):\s*error\s*(?<code>\w+):\s*(?<message>.+)'
            GCC = '(?<file>[\w/\\.-]+):(?<line>\d+):(?<col>\d+):\s*error:\s*(?<message>.+)'
            CMake = 'CMake Error at (?<file>[\w/\\.-]+):(?<line>\d+)\s*\((?<function>\w+)\):\s*(?<message>.+)'
            Maven = '\[ERROR\]\s*(?<message>.+)'
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Pipeline') {
            if ($InputObject) {
                $lines += $InputObject.ToString()
            }
        }
    }

    end {
        # Read from file if Source parameter used
        if ($Source) {
            if (Test-Path $Source) {
                $lines = Get-Content $Source
            } else {
                Write-Error "File not found: $Source"
                return
            }
        }

        # Auto-detect tool type if needed
        if ($ToolType -eq 'Auto') {
            $sample = $lines | Select-Object -First 100 | Out-String

            if ($sample -match '\(\d+,\d+\):\s*error') {
                $ToolType = 'MSBuild'
            }
            elseif ($sample -match ':\d+:\d+:\s*error:') {
                $ToolType = 'GCC'
            }
            elseif ($sample -match 'CMake Error') {
                $ToolType = 'CMake'
            }
            elseif ($sample -match '\[ERROR\]') {
                $ToolType = 'Maven'
            }
            else {
                # Default to GCC-style as most common
                $ToolType = 'GCC'
            }
        }

        $pattern = $patterns[$ToolType]

        # Parse each line
        foreach ($line in $lines) {
            if ($line -match $pattern) {
                $result = [ordered]@{
                    ToolType = $ToolType
                }

                # Extract available fields based on named groups
                if ($Matches['file']) { $result['File'] = $Matches['file'] }
                if ($Matches['line']) { $result['Line'] = [int]$Matches['line'] }
                if ($Matches['col']) { $result['Col'] = [int]$Matches['col'] }
                if ($Matches['code']) { $result['Code'] = $Matches['code'] }
                if ($Matches['function']) { $result['Function'] = $Matches['function'] }
                if ($Matches['message']) { $result['Message'] = $Matches['message'].Trim() }

                [PSCustomObject]$result
            }
        }
    }
}
