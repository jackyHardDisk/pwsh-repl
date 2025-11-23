# Example: Bulk File Processing with Streaming Parser
# Demonstrates: Pipeline batch processing with performance measurement

# Import module
Import-Module LoraxMod

# Create test directory with multiple C files
$testDir = "C:\temp\lorax_bulk_test"
if (-not (Test-Path $testDir)) {
    New-Item -ItemType Directory -Path $testDir | Out-Null
}

Write-Host "`n=== Bulk Processing with Streaming Parser ===" -ForegroundColor Cyan
Write-Host ""

# Generate 20 sample C files
Write-Host "Preparing test files..." -ForegroundColor Yellow
for ($i = 1; $i -le 20; $i++) {
    $fileName = "$testDir\file_$i.c"
    $code = @"
#include <stdio.h>

int function_$i(int x) {
    return x * $i;
}

int main() {
    return function_$i(42);
}
"@
    $code | Out-File -FilePath $fileName -Encoding utf8
}

Write-Host "  Created 20 test files" -ForegroundColor Green

# Start parser session
Write-Host "`nStarting parser session..." -ForegroundColor Yellow
$sessionId = Start-LoraxStreamParser -SessionId 'bulk_processing'
Write-Host "  Session started: $sessionId" -ForegroundColor Green

# Process all files with pipeline
Write-Host "`nProcessing files..." -ForegroundColor Yellow
$startTime = Get-Date

$results = Get-ChildItem $testDir\*.c |
           Invoke-LoraxStreamQuery -SessionId 'bulk_processing' -Command parse

$endTime = Get-Date
$elapsed = ($endTime - $startTime).TotalSeconds

# Analyze results
$successful = ($results | Where-Object { $_.status -eq 'ok' }).Count
$failed = ($results | Where-Object { $_.status -ne 'ok' }).Count

Write-Host "  Processing complete!" -ForegroundColor Green
Write-Host "  Successful: $successful" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Time: $([math]::Round($elapsed, 3))s" -ForegroundColor Gray
Write-Host "  Rate: $([math]::Round($successful / $elapsed, 1)) files/sec" -ForegroundColor Gray

# Aggregate statistics
$totalFunctions = 0
$totalLines = 0

foreach ($result in $results) {
    if ($result.status -eq 'ok') {
        $totalFunctions += $result.result.segmentCount
        $totalLines += ($result.result.segments | Measure-Object -Property lineCount -Sum).Sum
    }
}

Write-Host "`nAggregated Results:" -ForegroundColor Cyan
Write-Host "  Total functions found: $totalFunctions" -ForegroundColor White
Write-Host "  Total lines of code: $totalLines" -ForegroundColor White

# Stop session and get stats
Write-Host "`nStopping parser session..." -ForegroundColor Yellow
$sessionStats = Stop-LoraxStreamParser -SessionId 'bulk_processing'

Write-Host "  Session stopped" -ForegroundColor Green
Write-Host "  Session duration: $($sessionStats.DurationSeconds)s" -ForegroundColor Gray
Write-Host "  Files processed: $($sessionStats.FilesProcessed)" -ForegroundColor Gray
Write-Host "  Errors: $($sessionStats.Errors)" -ForegroundColor Gray

# Performance insight
$avgTimePerFile = $elapsed / $successful * 1000
Write-Host "`nPerformance:" -ForegroundColor Cyan
Write-Host "  Average time per file: $([math]::Round($avgTimePerFile, 1))ms" -ForegroundColor White
Write-Host "  Streaming is ideal for batch processing 100+ files" -ForegroundColor Gray
Write-Host "  Estimated speedup vs per-file spawn: 40x+" -ForegroundColor Gray

Write-Host "`n=== Example Complete ===" -ForegroundColor Cyan
Write-Host ""

# Cleanup
Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
