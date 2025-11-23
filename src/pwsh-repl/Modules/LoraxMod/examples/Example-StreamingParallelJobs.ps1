# Example: Parallel Processing with Multiple Sessions
# Demonstrates: Concurrent parser sessions for different file types

# Import module
Import-Module LoraxMod

# Create test directory with mixed file types
$testDir = "C:\temp\lorax_parallel_test"
if (-not (Test-Path $testDir)) {
    New-Item -ItemType Directory -Path $testDir | Out-Null
}

Write-Host "`n=== Parallel Processing with Multiple Sessions ===" -ForegroundColor Cyan
Write-Host ""

# Create C files
Write-Host "Creating test files..." -ForegroundColor Yellow
for ($i = 1; $i -le 5; $i++) {
    $fileName = "$testDir\module_$i.c"
    "int c_function_$i() { return $i; }" | Out-File -FilePath $fileName -Encoding utf8
}

# Create Python files
for ($i = 1; $i -le 5; $i++) {
    $fileName = "$testDir\script_$i.py"
    "def python_function_$i():`n    return $i" | Out-File -FilePath $fileName -Encoding utf8
}

Write-Host "  Created 5 C files and 5 Python files" -ForegroundColor Green

# Start separate parser sessions for each language
Write-Host "`nStarting parser sessions..." -ForegroundColor Yellow
Start-LoraxStreamParser -SessionId 'c_parser' | Out-Null
Start-LoraxStreamParser -SessionId 'python_parser' | Out-Null
Write-Host "  Started 2 concurrent sessions" -ForegroundColor Green

# Process C files in parallel (via session)
Write-Host "`nProcessing C files..." -ForegroundColor Yellow
$cStartTime = Get-Date
$cResults = Get-ChildItem $testDir\*.c |
            Invoke-LoraxStreamQuery -SessionId 'c_parser' -Command parse
$cElapsed = ((Get-Date) - $cStartTime).TotalSeconds

$cSuccess = ($cResults | Where-Object { $_.status -eq 'ok' }).Count
Write-Host "  Processed $cSuccess C files in $([math]::Round($cElapsed, 3))s" -ForegroundColor Green

# Process Python files in parallel (via session)
Write-Host "`nProcessing Python files..." -ForegroundColor Yellow
$pyStartTime = Get-Date
$pyResults = Get-ChildItem $testDir\*.py |
             Invoke-LoraxStreamQuery -SessionId 'python_parser' -Command parse
$pyElapsed = ((Get-Date) - $pyStartTime).TotalSeconds

$pySuccess = ($pyResults | Where-Object { $_.status -eq 'ok' }).Count
Write-Host "  Processed $pySuccess Python files in $([math]::Round($pyElapsed, 3))s" -ForegroundColor Green

# Compare results
Write-Host "`nResults by Language:" -ForegroundColor Cyan

# C results
$cFunctions = ($cResults | Where-Object { $_.status -eq 'ok' } |
               ForEach-Object { $_.result.segments }).Count
Write-Host "  C:" -ForegroundColor White
Write-Host "    Files: $cSuccess" -ForegroundColor Gray
Write-Host "    Functions: $cFunctions" -ForegroundColor Gray
Write-Host "    Language: $($cResults[0].result.language)" -ForegroundColor Gray

# Python results
$pyFunctions = ($pyResults | Where-Object { $_.status -eq 'ok' } |
                ForEach-Object { $_.result.segments }).Count
Write-Host "  Python:" -ForegroundColor White
Write-Host "    Files: $pySuccess" -ForegroundColor Gray
Write-Host "    Functions: $pyFunctions" -ForegroundColor Gray
Write-Host "    Language: $($pyResults[0].result.language)" -ForegroundColor Gray

# Stop both sessions
Write-Host "`nStopping parser sessions..." -ForegroundColor Yellow
$cStats = Stop-LoraxStreamParser -SessionId 'c_parser'
$pyStats = Stop-LoraxStreamParser -SessionId 'python_parser'

Write-Host "  Both sessions stopped" -ForegroundColor Green

# Session statistics
Write-Host "`nSession Statistics:" -ForegroundColor Cyan
Write-Host "  C Parser:" -ForegroundColor White
Write-Host "    Duration: $($cStats.DurationSeconds)s" -ForegroundColor Gray
Write-Host "    Files: $($cStats.FilesProcessed)" -ForegroundColor Gray
Write-Host "    Errors: $($cStats.Errors)" -ForegroundColor Gray

Write-Host "  Python Parser:" -ForegroundColor White
Write-Host "    Duration: $($pyStats.DurationSeconds)s" -ForegroundColor Gray
Write-Host "    Files: $($pyStats.FilesProcessed)" -ForegroundColor Gray
Write-Host "    Errors: $($pyStats.Errors)" -ForegroundColor Gray

# Use case guidance
Write-Host "`n=== Use Cases for Parallel Sessions ===" -ForegroundColor Cyan
Write-Host "  1. Process different languages concurrently" -ForegroundColor White
Write-Host "  2. Separate sessions for different analysis types" -ForegroundColor White
Write-Host "  3. Isolate error-prone files from main processing" -ForegroundColor White
Write-Host "  4. Run queries with different contexts simultaneously" -ForegroundColor White

Write-Host "`n=== Key Points ===" -ForegroundColor Cyan
Write-Host "  - Each session is independent (separate Node.js process)" -ForegroundColor White
Write-Host "  - No shared state between sessions" -ForegroundColor White
Write-Host "  - Sessions can run truly in parallel" -ForegroundColor White
Write-Host "  - Use unique SessionId for each parser instance" -ForegroundColor White

Write-Host "`n=== Example Complete ===" -ForegroundColor Cyan
Write-Host ""

# Cleanup
Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
