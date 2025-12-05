<#
.SYNOPSIS
Interactive tree-sitter AST navigation via Node.js REPL

.DESCRIPTION
PowerShell wrappers for exploring tree-sitter AST nodes interactively.
Uses Node.js REPL with loraxmod for direct AST manipulation.

.NOTES
Requires Node.js (optional peer dependency)
loraxmod bundled in module directory
#>

# Store module root at load time (non-blocking MCP tool for claude that works in background sessions)
$script:ModuleRoot = $PSScriptRoot
$script:LoraxPath = "$script:ModuleRoot/loraxmod/lib/index.js" -replace '\\', '/'
function Invoke-StreamingParser {
    <#
    .SYNOPSIS
    Process files through a streaming Node.js parser using stdin/stdout JSON protocol

    .DESCRIPTION
    Manages lifecycle of a long-running Node.js process that accepts JSON commands via stdin
    and returns JSON responses via stdout. Optimized for processing large file sets by
    eliminating per-file process spawn overhead.

    .PARAMETER ParserScript
    Path to Node.js script that implements streaming protocol

    .PARAMETER Files
    Array of file paths to process, or pipeline input

    .PARAMETER RootPath
    Root directory to make file paths relative to (optional)

    .PARAMETER OutputJson
    Path to save JSON results (optional)

    .PARAMETER TimeoutSeconds
    Timeout for each file parse operation (default: 30)

    .PARAMETER ContinueOnError
    Continue processing if individual files fail

    .PARAMETER ProgressInterval
    Show progress every N files (default: 50)

    .PARAMETER CustomCommand
    Custom command name (default: 'parse')

    .PARAMETER CommandBuilder
    ScriptBlock to build custom command object. Receives $FilePath, $Index.
    Default: @{ command = 'parse'; file = $FilePath; request_id = $Index }

    .PARAMETER ResultProcessor
    ScriptBlock to transform parser response into result object. Receives $Response, $File.
    Default: returns response as-is

    .EXAMPLE
    # Basic usage
    Get-ChildItem *.c -Recurse | Invoke-StreamingParser -ParserScript ./parser.js

    .EXAMPLE
    # With custom command builder
    $files | Invoke-StreamingParser -ParserScript ./parser.js -CommandBuilder {
        param($FilePath, $Index)
        @{ cmd = 'analyze'; path = $FilePath; options = @{ complexity = $true } }
    }

    .EXAMPLE
    # With result transformation
    $files | Invoke-StreamingParser -ParserScript ./parser.js -ResultProcessor {
        param($Response, $File)
        [PSCustomObject]@{
            Name = $File.Name
            Functions = $Response.result.stats.functions
            Complexity = $Response.result.complexity.cyclomatic
        }
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ParserScript,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'Path', 'FilePath')]
        [object[]]$Files,

        [string]$RootPath,

        [string]$OutputJson,

        [int]$TimeoutSeconds = 30,

        [switch]$ContinueOnError,

        [int]$ProgressInterval = 50,

        [string]$CustomCommand = 'parse',

        [scriptblock]$CommandBuilder = {
        param($FilePath, $Index)
        @{ command = $CustomCommand; file = $FilePath; request_id = $Index }
    },

        [scriptblock]$ResultProcessor = {
        param($Response, $File)
        $Response
    }
    )

    begin {
        # Deprecation warning
        Write-Warning "Invoke-StreamingParser is deprecated and will be removed in a future version."
        Write-Warning "Use Start-LoraxStreamParser, Invoke-LoraxStreamQuery, and Stop-LoraxStreamParser instead."
        Write-Warning "See: Get-Help Start-LoraxStreamParser -Examples"

        $allFiles = @()
        $results = @()
        $errors = @()
        $processedCount = 0
        $errorCount = 0
        $startTime = Get-Date

        # Validate parser script
        if (-not (Test-Path $ParserScript)) {
            throw "Parser script not found: $ParserScript"
        }

        Write-Host "=== Streaming Parser ===" -ForegroundColor Cyan
        Write-Host "Parser: $ParserScript" -ForegroundColor Gray
        Write-Host ""
    }

    process {
        # Collect files from pipeline
        foreach ($file in $Files) {
            if ($file -is [string]) {
                $allFiles += Get-Item $file
            } elseif ($file -is [System.IO.FileInfo]) {
                $allFiles += $file
            } else {
                $allFiles += $file
            }
        }
    }

    end {
        if ($allFiles.Count -eq 0) {
            Write-Warning "No files to process"
            return
        }

        Write-Host "Files to process: $($allFiles.Count)" -ForegroundColor Green
        Write-Host ""

        # Start Node.js streaming parser
        Write-Host "Starting parser..." -ForegroundColor Yellow

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "node"
        $psi.Arguments = $ParserScript
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $process = [System.Diagnostics.Process]::Start($psi)

        if (-not $process) {
            throw "Failed to start Node.js process"
        }

        Write-Host "  Parser PID: $($process.Id)" -ForegroundColor Green
        Write-Host ""

        # Give parser time to initialize
        Start-Sleep -Milliseconds 500

        # Send ping to verify parser is ready
        try {
            $pingCmd = @{ command = 'ping' } | ConvertTo-Json -Compress
            $process.StandardInput.WriteLine($pingCmd)

            $pingResponse = $process.StandardOutput.ReadLine()
            $ping = $pingResponse | ConvertFrom-Json

            if ($ping.status -eq 'pong') {
                Write-Host "Parser ready" -ForegroundColor Green
            } else {
                throw "Parser ping failed: $pingResponse"
            }
        } catch {
            Write-Error "Parser initialization failed: $_"
            $process.Kill()
            throw
        }

        Write-Host ""
        Write-Host "Processing files..." -ForegroundColor Green
        Write-Host ""

        # Process each file
        foreach ($file in $allFiles) {
            $processedCount++
            $progress = [math]::Round(($processedCount / $allFiles.Count) * 100, 1)

            # Show progress
            if ($processedCount % $ProgressInterval -eq 0 -or $processedCount -eq 1) {
                $elapsed = (Get-Date) - $startTime
                $rate = $processedCount / $elapsed.TotalSeconds
                $eta = ($allFiles.Count - $processedCount) / $rate

                Write-Host "  [$processedCount/$($allFiles.Count)] $progress% | Rate: $([math]::Round($rate, 1)) files/sec | ETA: $([math]::Round($eta, 0)) sec" -ForegroundColor Gray
            }

            try {
                # Get file path
                $filePath = if ($file.FullName) { $file.FullName } else { $file.ToString() }

                # Make relative if RootPath specified
                if ($RootPath) {
                    $filePath = $filePath.Replace($RootPath, '').TrimStart('\', '/')
                }

                # Convert to forward slashes for Node.js
                $filePath = $filePath.Replace('\', '/')

                # Build command using custom builder
                $cmdObject = & $CommandBuilder $filePath $processedCount

                # Send command
                $cmdJson = $cmdObject | ConvertTo-Json -Compress
                $process.StandardInput.WriteLine($cmdJson)

                # Read response with timeout
                $responseTask = $process.StandardOutput.ReadLineAsync()
                $timeout = New-TimeSpan -Seconds $TimeoutSeconds

                if ($responseTask.Wait($timeout)) {
                    $responseLine = $responseTask.Result
                    $response = $responseLine | ConvertFrom-Json

                    if ($response.status -eq 'ok') {
                        # Success - process result
                        $result = & $ResultProcessor $response $file
                        $results += $result
                    } else {
                        # Error from parser
                        $errorCount++
                        $errors += [PSCustomObject]@{
                            FilePath = $filePath
                            ErrorType = $response.error.type
                            ErrorMessage = $response.error.message
                        }

                        Write-Host "  ERROR: $($file.Name) - $($response.error.message)" -ForegroundColor Red

                        if (-not $ContinueOnError) {
                            throw "Parser error encountered. Use -ContinueOnError to skip errors."
                        }
                    }
                } else {
                    # Timeout
                    $errorCount++
                    $errors += [PSCustomObject]@{
                        FilePath = $filePath
                        ErrorType = "Timeout"
                        ErrorMessage = "Parser did not respond within $TimeoutSeconds seconds"
                    }

                    Write-Host "  TIMEOUT: $($file.Name)" -ForegroundColor Red

                    if (-not $ContinueOnError) {
                        throw "Parser timeout. Use -ContinueOnError to skip timeouts."
                    }
                }

            } catch {
                $errorCount++
                Write-Host "  EXCEPTION: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red

                if (-not $ContinueOnError) {
                    throw
                }
            }
        }

        # Send shutdown command
        Write-Host ""
        Write-Host "Shutting down parser..." -ForegroundColor Yellow

        try {
            $shutdownCmd = @{ command = 'shutdown' } | ConvertTo-Json -Compress
            $process.StandardInput.WriteLine($shutdownCmd)

            $shutdownResponse = $process.StandardOutput.ReadLine()
            $shutdown = $shutdownResponse | ConvertFrom-Json

            Write-Host "  $($shutdown.message)" -ForegroundColor Green
        } catch {
            Write-Warning "Shutdown command failed: $_"
        }

        # Wait for process to exit
        $process.WaitForExit(5000) | Out-Null

        if (-not $process.HasExited) {
            Write-Warning "Parser did not exit gracefully, killing process..."
            $process.Kill()
        }

        # Calculate statistics
        $totalElapsed = (Get-Date) - $startTime

        Write-Host ""
        Write-Host "=== Processing Complete ===" -ForegroundColor Cyan
        Write-Host "  Files processed: $processedCount / $($allFiles.Count)" -ForegroundColor Green
        Write-Host "  Successful: $($results.Count)" -ForegroundColor Green
        Write-Host "  Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })
        Write-Host "  Total time: $([math]::Round($totalElapsed.TotalSeconds, 1)) seconds" -ForegroundColor Yellow
        Write-Host "  Average: $([math]::Round($totalElapsed.TotalSeconds / $processedCount, 3)) sec/file" -ForegroundColor Yellow
        Write-Host ""

        # Save results to JSON if requested
        if ($OutputJson -and $results.Count -gt 0) {
            Write-Host "Saving results to: $OutputJson" -ForegroundColor Yellow
            $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputJson -Encoding utf8
            Write-Host "  Results saved successfully" -ForegroundColor Green

            # Save errors if any
            if ($errors.Count -gt 0) {
                $errorPath = $OutputJson.Replace('.json', '_errors.json')
                $errors | ConvertTo-Json -Depth 5 | Out-File -FilePath $errorPath -Encoding utf8
                Write-Host "  Errors saved to: $errorPath" -ForegroundColor Red
            }
        }

        Write-Host ""

        # Return results
        [PSCustomObject]@{
            TotalFiles = $allFiles.Count
            Processed = $processedCount
            Successful = $results.Count
            Errors = $errorCount
            ElapsedSeconds = [math]::Round($totalElapsed.TotalSeconds, 1)
            AvgSecondsPerFile = [math]::Round($totalElapsed.TotalSeconds / $processedCount, 3)
            Results = $results
            ErrorDetails = $errors
        }
    }
}

# Module-level storage for streaming parser sessions
if (-not $script:StreamParsers) {
    $script:StreamParsers = @{}
}

function Start-LoraxStreamParser {
    <#
    .SYNOPSIS
    Initialize a long-running Node.js streaming parser process

    .DESCRIPTION
    Starts a Node.js streaming parser process that accepts JSON commands via stdin
    and returns JSON responses via stdout. Optimized for batch processing of large
    file sets by eliminating per-file process spawn overhead (40x+ speedup).

    The parser session is stored in memory and can be reused for multiple parse/query
    operations until explicitly stopped with Stop-LoraxStreamParser.

    .PARAMETER SessionId
    Unique identifier for this parser session. Use same ID with Invoke-LoraxStreamQuery
    and Stop-LoraxStreamParser. Default: 'default'

    .PARAMETER ParserScript
    Path to Node.js streaming parser script. Default: bundled streaming_query_parser.js

    .PARAMETER TimeoutSeconds
    Seconds to wait for parser initialization. Default: 5

    .EXAMPLE
    Start-LoraxStreamParser
    # Starts default parser session

    .EXAMPLE
    Start-LoraxStreamParser -SessionId 'batch1'
    # Starts named session for parallel processing

    .EXAMPLE
    $sessionId = Start-LoraxStreamParser -SessionId 'custom'
    Get-ChildItem *.c | Invoke-LoraxStreamQuery -SessionId $sessionId -Command parse
    Stop-LoraxStreamParser -SessionId $sessionId

    .NOTES
    Use REPL functions (Start-TreeSitterSession) for interactive exploration.
    Use streaming functions for high-performance batch processing.

    .LINK
    Invoke-LoraxStreamQuery
    Stop-LoraxStreamParser
    #>
    [CmdletBinding()]
    param(
        [string]$SessionId = 'default',

        [string]$ParserScript = "$script:ModuleRoot/parsers/streaming_query_parser.js",

        [int]$TimeoutSeconds = 5
    )

    # Check if session already exists
    if ($script:StreamParsers.ContainsKey($SessionId)) {
        Write-Warning "Parser session '$SessionId' already exists. Use Stop-LoraxStreamParser first or choose different SessionId."
        return $SessionId
    }

    # Validate parser script
    if (-not (Test-Path $ParserScript)) {
        throw "Parser script not found: $ParserScript"
    }

    # Start Node.js process
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "node"
        $psi.Arguments = $ParserScript
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $process = [System.Diagnostics.Process]::Start($psi)

        if (-not $process) {
            throw "Failed to start Node.js process"
        }

        # Give parser time to initialize
        Start-Sleep -Milliseconds 500

        # Send ping to verify parser is ready
        $pingCmd = @{ command = 'ping' } | ConvertTo-Json -Compress
        $process.StandardInput.WriteLine($pingCmd)

        $responseTask = $process.StandardOutput.ReadLineAsync()
        $timeout = New-TimeSpan -Seconds $TimeoutSeconds

        if ($responseTask.Wait($timeout)) {
            $responseLine = $responseTask.Result
            $response = $responseLine | ConvertFrom-Json

            if ($response.status -eq 'pong') {
                # Store session
                $script:StreamParsers[$SessionId] = @{
                    Process = $process
                    ParserScript = $ParserScript
                    StartTime = Get-Date
                    FilesProcessed = 0
                    Errors = 0
                }

                Write-Verbose "Parser session '$SessionId' started (PID: $($process.Id))"
                return $SessionId
            } else {
                throw "Parser ping failed: $($response.status)"
            }
        } else {
            throw "Parser initialization timeout after $TimeoutSeconds seconds"
        }
    } catch {
        if ($process -and -not $process.HasExited) {
            $process.Kill()
        }
        throw "Failed to start parser session: $_"
    }
}

function Invoke-LoraxStreamQuery {
    <#
    .SYNOPSIS
    Send parse or query commands to streaming parser session

    .DESCRIPTION
    Sends JSON commands to a running streaming parser process and returns parsed results.
    Supports pipeline input for batch processing multiple files efficiently.

    Available commands:
    - parse: Parse file and extract code segments using loraxmod
    - query: Parse file and run tree-sitter query
    - ping: Check parser health and get stats

    .PARAMETER SessionId
    Parser session ID from Start-LoraxStreamParser. Default: 'default'

    .PARAMETER Command
    Command type: parse, query, or ping. Default: 'parse'

    .PARAMETER FilePath
    File path to process. Accepts pipeline input. Aliases: File, FullName, Path

    .PARAMETER Query
    Tree-sitter query string (required for 'query' command)

    .PARAMETER Context
    Extraction context object for filtering results

    .PARAMETER TimeoutSeconds
    Seconds to wait for parser response. Default: 30

    .EXAMPLE
    Start-LoraxStreamParser
    Invoke-LoraxStreamQuery -FilePath "sample.c" -Command parse
    Stop-LoraxStreamParser

    .EXAMPLE
    Start-LoraxStreamParser -SessionId 'batch'
    Get-ChildItem *.c -Recurse | Invoke-LoraxStreamQuery -SessionId 'batch' -Command parse
    Stop-LoraxStreamParser -SessionId 'batch'

    .EXAMPLE
    # Find all integers in a Python file and extract line numbers
    Start-LoraxStreamParser -SessionId demo
    $q = Invoke-LoraxStreamQuery -SessionId demo -FilePath "app.py" -Command query -Query '(integer) @num'
    $q.result.queryResults | ForEach-Object {
        [PSCustomObject]@{
            Line = $_.startPosition.row + 1  # 0-indexed to 1-indexed
            Value = $_.text
        }
    }
    Stop-LoraxStreamParser -SessionId demo

    .EXAMPLE
    $query = '(function_definition name: (identifier) @func)'
    Invoke-LoraxStreamQuery -FilePath "app.c" -Command query -Query $query

    .OUTPUTS
    PSCustomObject with properties:
    - status: "ok" or "error"
    - result.queryResults: Array of matches (for 'query' command), each with:
        - text: The matched source text
        - name: Capture name from query (@num, @fn, etc.)
        - startPosition.row: 0-indexed line number (add 1 for display)
        - startPosition.column: Column offset
        - endPosition.row/column: End position
        - startIndex/endIndex: Byte offsets in source
    - result.captureCount: Total matches found
    - result.segments: Array of code segments (for 'parse' command)
    - result.file: File path processed
    - result.language: Detected/specified language

    .NOTES
    Parser session must be started with Start-LoraxStreamParser first.
    Use pipeline for efficient batch processing of multiple files.

    IMPORTANT: startPosition.row is 0-indexed. Add 1 for human-readable line numbers:
        $lineNumber = $match.startPosition.row + 1

    Performance: Single session eliminates per-file process spawn overhead.
    Achieves 40x+ speedup for batch processing vs spawning node per file.
    Best for processing 100+ files. For exploration, use REPL functions.

    .LINK
    Start-LoraxStreamParser
    Stop-LoraxStreamParser
    #>
    [CmdletBinding()]
    param(
        [string]$SessionId = 'default',

        [ValidateSet('parse', 'query', 'ping')]
        [string]$Command = 'parse',

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'Path', 'File')]
        [string]$FilePath,

        [string]$Query,

        [object]$Context,

        [int]$TimeoutSeconds = 30
    )

    begin {
        # Validate session exists
        if (-not $script:StreamParsers.ContainsKey($SessionId)) {
            throw "Parser session '$SessionId' not found. Use Start-LoraxStreamParser first."
        }

        $session = $script:StreamParsers[$SessionId]
        $process = $session.Process

        # Check process is still running
        if ($process.HasExited) {
            throw "Parser process has exited (exit code: $($process.ExitCode))"
        }

        $results = @()
    }

    process {
        try {
            # Build command object
            $cmdObject = @{ command = $Command }

            if ($FilePath) {
                # Convert to absolute path and forward slashes
                $absolutePath = (Resolve-Path $FilePath -ErrorAction Stop).Path
                $cmdObject.file = $absolutePath.Replace('\', '/')
            }

            if ($Query) {
                $cmdObject.query = $Query
            }

            if ($Context) {
                $cmdObject.context = $Context
            }

            # Validate query parameter for query command
            if ($Command -eq 'query' -and -not $Query) {
                throw "Query parameter required for 'query' command"
            }

            # Send command
            $cmdJson = $cmdObject | ConvertTo-Json -Compress
            $process.StandardInput.WriteLine($cmdJson)
            $process.StandardInput.BaseStream.Flush()

            # Read response with timeout using synchronous read wrapped in Task
            # This avoids stream collision issues with ReadLineAsync() in rapid loops
            $reader = $process.StandardOutput
            $readTask = [System.Threading.Tasks.Task]::Run([Func[string]]{
                $reader.ReadLine()
            })
            $timeout = New-TimeSpan -Seconds $TimeoutSeconds

            if ($readTask.Wait($timeout)) {
                $responseLine = $readTask.Result
                if ($null -eq $responseLine) {
                    throw "Parser returned null (process may have exited)"
                }
                $response = $responseLine | ConvertFrom-Json

                if ($response.status -eq 'ok' -or $response.status -eq 'pong') {
                    # Success
                    $session.FilesProcessed++
                    $results += $response
                } else {
                    # Error from parser
                    $session.Errors++
                    Write-Warning "Parser error for '$FilePath': $($response.error.message)"
                    $results += $response
                }
            } else {
                # Timeout
                $session.Errors++
                throw "Parser timeout after $TimeoutSeconds seconds for file: $FilePath"
            }

        } catch {
            $session.Errors++
            Write-Error "Failed to process '$FilePath': $_"
        }
    }

    end {
        # Return results
        $results
    }
}

function Stop-LoraxStreamParser {
    <#
    .SYNOPSIS
    Gracefully shutdown streaming parser session

    .DESCRIPTION
    Sends shutdown command to parser process, retrieves final statistics,
    and cleans up session resources. Waits for graceful exit or forcibly
    terminates if timeout exceeded.

    .PARAMETER SessionId
    Parser session ID to stop. Default: 'default'

    .PARAMETER TimeoutSeconds
    Seconds to wait for graceful shutdown. Default: 5

    .EXAMPLE
    Stop-LoraxStreamParser
    # Stops default session

    .EXAMPLE
    Stop-LoraxStreamParser -SessionId 'batch1'
    # Stops named session

    .EXAMPLE
    $stats = Stop-LoraxStreamParser
    Write-Host "Processed $($stats.FilesProcessed) files in $($stats.DurationSeconds)s"
    # Capture and display statistics

    .NOTES
    Always call this function to properly cleanup parser sessions.
    Returns final statistics including files processed and error count.

    Performance: Streaming parser provides 40x+ speedup vs per-file spawning.
    Use streaming for batch processing (100+ files). Use REPL for exploration.

    .LINK
    Start-LoraxStreamParser
    Invoke-LoraxStreamQuery
    #>
    [CmdletBinding()]
    param(
        [string]$SessionId = 'default',

        [int]$TimeoutSeconds = 5
    )

    # Check session exists
    if (-not $script:StreamParsers.ContainsKey($SessionId)) {
        Write-Warning "Parser session '$SessionId' not found"
        return
    }

    $session = $script:StreamParsers[$SessionId]
    $process = $session.Process

    try {
        if (-not $process.HasExited) {
            # Send shutdown command
            $shutdownCmd = @{ command = 'shutdown' } | ConvertTo-Json -Compress
            $process.StandardInput.WriteLine($shutdownCmd)
            $process.StandardInput.BaseStream.Flush()

            # Try to read shutdown response using synchronous read wrapped in Task
            $reader = $process.StandardOutput
            $readTask = [System.Threading.Tasks.Task]::Run([Func[string]]{
                $reader.ReadLine()
            })
            $timeout = New-TimeSpan -Seconds $TimeoutSeconds

            $finalStats = $null

            if ($readTask.Wait($timeout)) {
                $responseLine = $readTask.Result
                if ($responseLine) {
                    $response = $responseLine | ConvertFrom-Json
                    $finalStats = $response.finalStats
                }
            }

            # Wait for process to exit
            if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
                Write-Warning "Parser did not exit gracefully, killing process..."
                $process.Kill()
            }

            # Return statistics
            $sessionDuration = (Get-Date) - $session.StartTime

            [PSCustomObject]@{
                SessionId = $SessionId
                DurationSeconds = [math]::Round($sessionDuration.TotalSeconds, 1)
                FilesProcessed = $session.FilesProcessed
                Errors = $session.Errors
                ParserStats = $finalStats
            }
        }
    } catch {
        Write-Warning "Error during parser shutdown: $_"
        if ($process -and -not $process.HasExited) {
            $process.Kill()
        }
    } finally {
        # Remove session from storage
        $script:StreamParsers.Remove($SessionId)
    }
}

function Start-TreeSitterSession {
    <#
    .SYNOPSIS
    Start interactive Node.js REPL with tree-sitter loaded

    .DESCRIPTION
    Initializes Node.js REPL session with loraxmod pre-loaded and parser initialized.
    Sets up global variables: parser, tree, root for immediate navigation.

    Two modes:
    - Terminal mode (default): Blocking interactive REPL for human use
    - Process mode (-AsProcess): Returns Process object for programmatic control via stdin

    .PARAMETER Language
    Programming language to parse (c, python, javascript, etc.)

    .PARAMETER Code
    Source code to parse initially

    .PARAMETER FilePath
    Path to source file to parse

    .PARAMETER AsProcess
    Return Process object with stdin/stdout access for programmatic control.
    Process must be manually stopped and disposed.

    .PARAMETER SessionId
    Session identifier for tracking (used with -AsProcess). Default: 'default'

    .EXAMPLE
    Start-TreeSitterSession -Language c -Code 'int main() { printf("hi"); }'
    Starts blocking REPL in terminal

    .EXAMPLE
    $repl = Start-TreeSitterSession -Language fortran -FilePath code.f90 -AsProcess
    $repl.Process.StandardInput.WriteLine('root.childCount')
    $output = $repl.Process.StandardOutput.ReadLine()
    $repl.Process.Kill()
    $repl.Process.Dispose()

    .EXAMPLE
    $repl = Start-TreeSitterSession -Language c -AsProcess -SessionId 'analysis1'
    Send-REPLCommand -SessionId 'analysis1' -Command 'root.type'
    Stop-TreeSitterSession -SessionId 'analysis1'

    .NOTES
    Terminal mode - type commands interactively:
    - root.type - Get node type
    - root.childCount - Count children
    - root.child(0) - Get first child
    - root.childForFieldName('function') - Get field
    - root.parent - Get parent node
    - root.startPosition - Get position {row, column}
    - root.text - Get source text

    Process mode - use Process.StandardInput/StandardOutput for automation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('c', 'cpp', 'csharp', 'python', 'javascript', 'typescript', 'bash', 'powershell', 'r', 'rust', 'css', 'fortran')]
        [string]$Language,

        [Parameter(ParameterSetName='Code')]
        [string]$Code,

        [Parameter(ParameterSetName='File')]
        [string]$FilePath,

        [switch]$AsProcess,

        [string]$SessionId = 'default'
    )

    # Initialize module-level session tracker if needed
    if (-not $script:REPLSessions) {
        $script:REPLSessions = @{}
    }

    # Check if session already exists (when using -AsProcess)
    if ($AsProcess -and $script:REPLSessions.ContainsKey($SessionId)) {
        Write-Warning "REPL session '$SessionId' already exists. Use Stop-TreeSitterSession first or choose different SessionId."
        return $script:REPLSessions[$SessionId]
    }

    # Get code from file if specified
    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path $FilePath)) {
            Write-Error "File not found: $FilePath"
            return
        }
        $Code = Get-Content $FilePath -Raw
    }

    # Escape code for JavaScript string
    $escapedCode = $Code -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r'

    # Get lorax path from module scope
    $loraxPath = $script:LoraxPath

    # Generate initialization script
    $initScript = @"
const lorax = require('$loraxPath');

console.log('Initializing tree-sitter...');
(async () => {
    await lorax.initParser();
    const parser = lorax.getParser();
    const lang = await lorax.loadLanguage('$Language');

    if (!lang) {
        console.error('Failed to load language: $Language');
        process.exit(1);
    }

    parser.setLanguage(lang);

    const code = "$escapedCode";
    const tree = parser.parse(code);
    const root = tree.rootNode;

    // Make available globally
    global.lorax = lorax;
    global.parser = parser;
    global.tree = tree;
    global.root = root;
    global.code = code;

    console.log('');
    console.log('=== Tree-sitter REPL Ready ===');
    console.log('Language: $Language');
    console.log('Root type:', root.type);
    console.log('Child count:', root.childCount);
    console.log('');
    console.log('Available globals:');
    console.log('  lorax  - loraxmod API');
    console.log('  parser - Parser instance');
    console.log('  tree   - Parsed tree');
    console.log('  root   - Root node');
    console.log('  code   - Source code');
    console.log('');
    console.log('Common operations:');
    console.log('  root.type - Node type');
    console.log('  root.childCount - Number of children');
    console.log('  root.child(0) - Get first child');
    console.log('  root.childForFieldName(\"function\") - Get field');
    console.log('  root.parent - Get parent');
    console.log('  root.startPosition - Position {row, column}');
    console.log('  root.startIndex - Byte offset');
    console.log('  root.text - Source text');
    console.log('  root.namedChildCount - Named children only');
    console.log('  root.namedChild(0) - Get named child');
    console.log('');
    console.log('Type .exit to quit');
    console.log('');

    // Start REPL
    const repl = require('repl');
    const replServer = repl.start({
        prompt: 'ts> ',
        useGlobal: true
    });
})();
"@

    # Write init script to temp file
    $tempScript = Join-Path $env:TEMP "treesitter-init-$(Get-Random).js"
    $initScript | Out-File -FilePath $tempScript -Encoding utf8 -NoNewline

    if ($AsProcess) {
        # Process mode - return Process object with stdin/stdout access
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "node"
            $psi.Arguments = $tempScript
            $psi.UseShellExecute = $false
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true

            $process = [System.Diagnostics.Process]::Start($psi)

            if (-not $process) {
                throw "Failed to start Node.js process"
            }

            # Give REPL time to initialize
            Start-Sleep -Milliseconds 1500

            # Store session info
            $sessionInfo = @{
                Process = $process
                Language = $Language
                InitScript = $tempScript
                StartTime = Get-Date
            }

            $script:REPLSessions[$SessionId] = $sessionInfo

            # Return session object
            [PSCustomObject]@{
                SessionId = $SessionId
                Process = $process
                Language = $Language
                StartTime = $sessionInfo.StartTime
            }
        }
        catch {
            # Cleanup temp file on error
            if (Test-Path $tempScript) {
                Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
            }
            throw
        }
    }
    else {
        # Terminal mode - blocking interactive REPL
        try {
            & node $tempScript
        }
        finally {
            # Cleanup temp file
            if (Test-Path $tempScript) {
                Remove-Item $tempScript -Force
            }
        }
    }
}

function Find-FunctionCalls {
    <#
    .SYNOPSIS
    Find function calls with context (parent function, arguments, line numbers)

    .DESCRIPTION
    Extracts all function calls from source code with full context information.
    Similar to Chandra POSIX analysis pattern. Returns function name, location,
    parent function, arguments, and source line.

    .PARAMETER Language
    Programming language

    .PARAMETER Code
    Source code to analyze

    .PARAMETER FilePath
    Path to source file to analyze

    .PARAMETER FunctionNames
    Optional filter - only return calls to these functions

    .EXAMPLE
    Find-FunctionCalls -Language c -FilePath main.c
    Find all function calls in C file

    .EXAMPLE
    Find-FunctionCalls -Language c -FilePath main.c -FunctionNames @('printf', 'malloc', 'free')
    Find only POSIX memory/IO functions

    .EXAMPLE
    Find-FunctionCalls -Language python -Code 'import os; os.path.join("a", "b")'
    Find function calls in Python code

    .NOTES
    Returns objects with:
    - function: function name
    - line: line number (1-indexed)
    - column: column number
    - parentFunction: containing function name (or 'global')
    - arguments: array of argument text
    - codeLine: full source line
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('c', 'cpp', 'csharp', 'python', 'javascript', 'typescript', 'bash', 'powershell', 'r', 'rust', 'css', 'fortran')]
        [string]$Language,

        [Parameter(ParameterSetName='Code')]
        [string]$Code,

        [Parameter(ParameterSetName='File')]
        [string]$FilePath,

        [Parameter()]
        [string[]]$FunctionNames
    )

    # Get code from file
    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path $FilePath)) {
            Write-Error "File not found: $FilePath"
            return
        }
        $Code = Get-Content $FilePath -Raw
    }

    # Escape for JSON
    $escapedCode = $Code -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r'
    $filterJson = if ($FunctionNames) { ConvertTo-Json $FunctionNames -Compress } else { 'null' }

    # Get lorax path from module scope
    $loraxPath = $script:LoraxPath

    $analysisScript = @"
const lorax = require('$loraxPath');

(async () => {
    await lorax.initParser();
    const parser = lorax.getParser();
    const lang = await lorax.loadLanguage('$Language');
    parser.setLanguage(lang);

    const code = "$escapedCode";
    const tree = parser.parse(code);
    const lines = code.split('\n');
    const filterFuncs = $filterJson;

    const results = [];

    function findFunctionName(node) {
        if (node.type === 'identifier') return node;
        for (let i = 0; i < node.childCount; i++) {
            const found = findFunctionName(node.child(i));
            if (found) return found;
        }
        return null;
    }

    function traverse(node) {
        if (node.type === 'call_expression' || node.type === 'call') {
            const funcNode = node.childForFieldName('function');
            if (funcNode) {
                const funcName = funcNode.text;

                // Apply filter if specified
                if (filterFuncs && !filterFuncs.includes(funcName)) {
                    // Skip this function
                } else {
                    // Get arguments
                    const argsNode = node.childForFieldName('arguments');
                    const args = [];
                    if (argsNode) {
                        for (let i = 0; i < argsNode.namedChildCount; i++) {
                            const argNode = argsNode.namedChild(i);
                            args.push(argNode.text.length > 60 ? argNode.text.substring(0, 57) + '...' : argNode.text);
                        }
                    }

                    // Find parent function
                    let parentFunc = 'global';
                    let current = node.parent;
                    while (current) {
                        if (current.type === 'function_definition' || current.type === 'function_declaration') {
                            const declarator = current.childForFieldName('declarator') || current.childForFieldName('name');
                            if (declarator) {
                                const nameNode = findFunctionName(declarator);
                                if (nameNode) parentFunc = nameNode.text;
                            }
                            break;
                        }
                        current = current.parent;
                    }

                    results.push({
                        function: funcName,
                        line: node.startPosition.row + 1,
                        column: node.startPosition.column + 1,
                        parentFunction: parentFunc,
                        arguments: args,
                        codeLine: lines[node.startPosition.row]?.trim() || ''
                    });
                }
            }
        }

        for (let i = 0; i < node.childCount; i++) {
            traverse(node.child(i));
        }
    }

    traverse(tree.rootNode);
    console.log(JSON.stringify(results, null, 2));
})();
"@

    $tempScript = Join-Path $env:TEMP "find-calls-$(Get-Random).js"
    $analysisScript | Out-File -FilePath $tempScript -Encoding utf8 -NoNewline

    try {
        # Use node directly - output goes to stdout naturally
        $output = & node $tempScript
        $output | ConvertFrom-Json
    } finally {
        if (Test-Path $tempScript) { Remove-Item $tempScript -Force }
    }
}

function Get-IncludeDependencies {
    <#
    .SYNOPSIS
    Parse include directives from C/C++ files

    .DESCRIPTION
    Extracts #include directives and categorizes them as system, local, or POSIX headers.
    Based on Chandra include dependency analysis pattern.

    .PARAMETER FilePath
    Path to C/C++ source or header file

    .PARAMETER Code
    Source code to analyze

    .EXAMPLE
    Get-IncludeDependencies -FilePath main.c
    Parse includes from C file

    .EXAMPLE
    Get-IncludeDependencies -FilePath header.h | Select-Object -ExpandProperty posix
    Get only POSIX headers

    .NOTES
    Returns object with:
    - system: array of system includes (from <header.h>)
    - local: array of local includes (from "header.h")
    - posix: array of POSIX headers
    #>
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName='File', Mandatory=$true)]
        [string]$FilePath,

        [Parameter(ParameterSetName='Code')]
        [string]$Code
    )

    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path $FilePath)) {
            Write-Error "File not found: $FilePath"
            return
        }
        $Code = Get-Content $FilePath -Raw
    }

    $escapedCode = $Code -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r'

    $includeScript = @"
const lorax = require('$loraxPath');

(async () => {
    await lorax.initParser();
    const parser = lorax.getParser();
    const lang = await lorax.loadLanguage('c');
    parser.setLanguage(lang);

    const code = "$escapedCode";
    const tree = parser.parse(code);

    const posixHeaders = new Set(['unistd.h', 'pwd.h', 'grp.h', 'glob.h', 'strings.h', 'sys/socket.h', 'netinet/in.h', 'arpa/inet.h']);
    const includes = { system: [], local: [], posix: [] };

    function traverse(node) {
        if (node.type === 'preproc_include') {
            const pathNode = node.childForFieldName('path');
            if (pathNode) {
                const isSystem = pathNode.type === 'system_lib_string';
                const header = pathNode.text.slice(1, -1); // Remove <> or ""

                if (isSystem) {
                    includes.system.push(header);
                    if (posixHeaders.has(header)) {
                        includes.posix.push(header);
                    }
                } else {
                    includes.local.push(header);
                }
            }
        }

        for (let i = 0; i < node.childCount; i++) {
            traverse(node.child(i));
        }
    }

    traverse(tree.rootNode);
    console.log(JSON.stringify(includes, null, 2));
})();
"@

    $tempScript = Join-Path $env:TEMP "includes-$(Get-Random).js"
    $includeScript | Out-File -FilePath $tempScript -Encoding utf8 -NoNewline

    try {
        $output = & node $tempScript
        $output | ConvertFrom-Json
    } finally {
        if (Test-Path $tempScript) { Remove-Item $tempScript -Force }
    }
}

function Send-REPLCommand {
    <#
    .SYNOPSIS
    Send command to interactive REPL session and read response

    .DESCRIPTION
    Sends JavaScript command to REPL session started with Start-TreeSitterSession -AsProcess.
    Reads output from REPL stdout.

    .PARAMETER SessionId
    Session identifier from Start-TreeSitterSession. Default: 'default'

    .PARAMETER Command
    JavaScript command to execute in REPL context

    .PARAMETER TimeoutSeconds
    Seconds to wait for response. Default: 5

    .EXAMPLE
    $repl = Start-TreeSitterSession -Language c -AsProcess
    Send-REPLCommand -Command 'root.childCount'
    # Returns: 3

    .EXAMPLE
    Send-REPLCommand -SessionId 'analysis1' -Command 'root.type'
    #Returns node type

    .NOTES
    REPL must be started with -AsProcess switch.
    Commands execute in async context with lorax, parser, tree, root globals available.
    #>
    [CmdletBinding()]
    param(
        [string]$SessionId = 'default',

        [Parameter(Mandatory=$true)]
        [string]$Command,

        [int]$TimeoutSeconds = 5
    )

    if (-not $script:REPLSessions) {
        throw "No REPL sessions found. Start session with Start-TreeSitterSession -AsProcess first."
    }

    if (-not $script:REPLSessions.ContainsKey($SessionId)) {
        throw "REPL session '$SessionId' not found. Available sessions: $($script:REPLSessions.Keys -join ', ')"
    }

    $session = $script:REPLSessions[$SessionId]
    $process = $session.Process

    if ($process.HasExited) {
        throw "REPL session '$SessionId' has exited (exit code: $($process.ExitCode))"
    }

    try {
        # Send command
        $process.StandardInput.WriteLine($Command)
        $process.StandardInput.BaseStream.Flush()

        # Read response with timeout using synchronous read wrapped in Task
        $reader = $process.StandardOutput
        $readTask = [System.Threading.Tasks.Task]::Run([Func[string]]{
            $reader.ReadLine()
        })
        $timeout = New-TimeSpan -Seconds $TimeoutSeconds

        if ($readTask.Wait($timeout)) {
            $readTask.Result
        }
        else {
            Write-Warning "REPL command timed out after $TimeoutSeconds seconds"
            $null
        }
    }
    catch {
        Write-Error "Failed to send command to REPL session '$SessionId': $_"
    }
}

function Stop-TreeSitterSession {
    <#
    .SYNOPSIS
    Stop REPL session and cleanup resources

    .DESCRIPTION
    Stops REPL process started with Start-TreeSitterSession -AsProcess.
    Kills process, disposes resources, and removes session from tracker.

    .PARAMETER SessionId
    Session identifier to stop. Default: 'default'

    .EXAMPLE
    Stop-TreeSitterSession
    # Stops default session

    .EXAMPLE
    Stop-TreeSitterSession -SessionId 'analysis1'
    # Stops named session

    .NOTES
    Always stop sessions when done to free resources and cleanup temp files.
    #>
    [CmdletBinding()]
    param(
        [string]$SessionId = 'default'
    )

    if (-not $script:REPLSessions) {
        Write-Warning "No REPL sessions found"
        return
    }

    if (-not $script:REPLSessions.ContainsKey($SessionId)) {
        Write-Warning "REPL session '$SessionId' not found. Available sessions: $($script:REPLSessions.Keys -join ', ')"
        return
    }

    $session = $script:REPLSessions[$SessionId]
    $process = $session.Process

    try {
        if (-not $process.HasExited) {
            # Try graceful exit first
            try {
                $process.StandardInput.WriteLine('.exit')
                $process.WaitForExit(2000)  # Wait 2 seconds
            }
            catch {
                # Ignore errors from graceful exit attempt
            }

            # Force kill if still running
            if (-not $process.HasExited) {
                $process.Kill()
                $process.WaitForExit(1000)
            }
        }

        # Cleanup temp script
        if ($session.InitScript -and (Test-Path $session.InitScript)) {
            Remove-Item $session.InitScript -Force -ErrorAction SilentlyContinue
        }

        # Dispose process
        $process.Dispose()

        # Remove from tracker
        $script:REPLSessions.Remove($SessionId)

        Write-Verbose "REPL session '$SessionId' stopped"
    }
    catch {
        Write-Error "Failed to stop REPL session '$SessionId': $_"
    }
}

# Functions exported via manifest (LoraxMod.psd1)
# No Export-ModuleMember needed when using FunctionsToExport in manifest
