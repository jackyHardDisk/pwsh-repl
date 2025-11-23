# Performance Benchmark: Streaming vs Per-File Spawn
# Validates 40x+ speedup claim for batch processing

param(
    [int]$FileCount = 50,
    [string]$TestDir = "C:\temp\lorax_benchmark"
)

Import-Module LoraxMod -Force

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "LORAX MOD PERFORMANCE BENCHMARK" -ForegroundColor Cyan
Write-Host "Streaming vs Per-File Process Spawning" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# Create test directory
if (-not (Test-Path $TestDir)) {
    New-Item -ItemType Directory -Path $TestDir | Out-Null
}

# Generate test files
Write-Host "Preparing benchmark..." -ForegroundColor Yellow
Write-Host "  Generating $FileCount test C files..." -ForegroundColor Gray

for ($i = 1; $i -le $FileCount; $i++) {
    $fileName = "$TestDir\test_$i.c"
    $code = @"
#include <stdio.h>

int function_$i(int x) {
    return x * $i;
}

int helper_${i}_a() { return $i * 2; }
int helper_${i}_b() { return $i * 3; }

int main() {
    return function_$i(42);
}
"@
    $code | Out-File -FilePath $fileName -Encoding utf8 -Force
}

$files = Get-ChildItem $TestDir\*.c
Write-Host "  Created $($files.Count) files" -ForegroundColor Green

# Benchmark 1: Per-File Process Spawning (simulate traditional approach)
Write-Host "`nBenchmark 1: Per-File Process Spawning" -ForegroundColor Yellow
Write-Host "  (Simulates calling 'node parse.js file.c' for each file)" -ForegroundColor Gray

$perFileStartTime = Get-Date
$perFileResults = @()

$parserScript = (Get-Module LoraxMod).ModuleBase + "/parsers/streaming_query_parser.js"

foreach ($file in $files) {
    try {
        # Spawn separate Node.js process for each file
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "node"
        $psi.Arguments = $parserScript
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $process = [System.Diagnostics.Process]::Start($psi)

        # Send parse command
        $cmd = @{ command = 'parse'; file = $file.FullName.Replace('\', '/') } | ConvertTo-Json -Compress
        $process.StandardInput.WriteLine($cmd)

        # Read response
        $responseLine = $process.StandardOutput.ReadLine()
        $response = $responseLine | ConvertFrom-Json

        # Send shutdown
        $shutdownCmd = @{ command = 'shutdown' } | ConvertTo-Json -Compress
        $process.StandardInput.WriteLine($shutdownCmd)
        $process.WaitForExit(2000) | Out-Null

        if ($response.status -eq 'ok') {
            $perFileResults += $response
        }

        if (-not $process.HasExited) {
            $process.Kill()
        }
    } catch {
        Write-Warning "Per-file failed for $($file.Name): $_"
    }
}

$perFileEndTime = Get-Date
$perFileElapsed = ($perFileEndTime - $perFileStartTime).TotalSeconds

Write-Host "  Completed: $($perFileResults.Count) files" -ForegroundColor Green
Write-Host "  Time: $([math]::Round($perFileElapsed, 2))s" -ForegroundColor White
Write-Host "  Rate: $([math]::Round($perFileResults.Count / $perFileElapsed, 1)) files/sec" -ForegroundColor White

# Benchmark 2: Streaming Parser (long-running process)
Write-Host "`nBenchmark 2: Streaming Parser" -ForegroundColor Yellow
Write-Host "  (Single long-running process, reused for all files)" -ForegroundColor Gray

$streamingStartTime = Get-Date

Start-LoraxStreamParser -SessionId 'benchmark' | Out-Null

$streamingResults = $files | Invoke-LoraxStreamQuery -SessionId 'benchmark' -Command parse

Stop-LoraxStreamParser -SessionId 'benchmark' | Out-Null

$streamingEndTime = Get-Date
$streamingElapsed = ($streamingEndTime - $streamingStartTime).TotalSeconds

$streamingSuccess = ($streamingResults | Where-Object { $_.status -eq 'ok' }).Count

Write-Host "  Completed: $streamingSuccess files" -ForegroundColor Green
Write-Host "  Time: $([math]::Round($streamingElapsed, 2))s" -ForegroundColor White
Write-Host "  Rate: $([math]::Round($streamingSuccess / $streamingElapsed, 1)) files/sec" -ForegroundColor White

# Calculate speedup
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "RESULTS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$speedup = $perFileElapsed / $streamingElapsed

Write-Host "`nPerformance Comparison:" -ForegroundColor White
Write-Host "  Per-File Spawning:  $([math]::Round($perFileElapsed, 2))s" -ForegroundColor Gray
Write-Host "  Streaming Parser:   $([math]::Round($streamingElapsed, 2))s" -ForegroundColor Gray
Write-Host "`n  SPEEDUP: $([math]::Round($speedup, 1))x" -ForegroundColor $(if ($speedup -ge 40) { 'Green' } elseif ($speedup -ge 20) { 'Yellow' } else { 'Red' })

if ($speedup -ge 40) {
    Write-Host "`n  SUCCESS: Achieved 40x+ speedup target!" -ForegroundColor Green
} elseif ($speedup -ge 20) {
    Write-Host "`n  PARTIAL: Speedup above 20x (acceptable)" -ForegroundColor Yellow
} else {
    Write-Host "`n  BELOW TARGET: Speedup below expectations" -ForegroundColor Red
}

Write-Host "`nBreakdown:" -ForegroundColor White
Write-Host "  Files processed: $FileCount" -ForegroundColor Gray
Write-Host "  Per-file overhead: $([math]::Round($perFileElapsed / $FileCount * 1000, 0))ms" -ForegroundColor Gray
Write-Host "  Streaming overhead: $([math]::Round($streamingElapsed / $FileCount * 1000, 0))ms" -ForegroundColor Gray

Write-Host "`nConclusion:" -ForegroundColor White
if ($speedup -ge 40) {
    Write-Host "  Streaming parser delivers significant performance advantage" -ForegroundColor Green
    Write-Host "  for batch processing workloads. Use for 100+ files." -ForegroundColor Green
} else {
    Write-Host "  Streaming parser provides performance benefit," -ForegroundColor Yellow
    Write-Host "  though speedup varies based on system and file characteristics." -ForegroundColor Yellow
}

# Export results
$benchmarkResults = [PSCustomObject]@{
    Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    FileCount = $FileCount
    PerFileTime = [math]::Round($perFileElapsed, 2)
    StreamingTime = [math]::Round($streamingElapsed, 2)
    Speedup = [math]::Round($speedup, 1)
    PerFileRate = [math]::Round($perFileResults.Count / $perFileElapsed, 1)
    StreamingRate = [math]::Round($streamingSuccess / $streamingElapsed, 1)
    TargetMet = $speedup -ge 40
}

$resultsPath = "$TestDir\benchmark_results.json"
$benchmarkResults | ConvertTo-Json | Out-File $resultsPath -Encoding utf8

Write-Host "`nBenchmark results saved to: $resultsPath" -ForegroundColor Gray

Write-Host "`n============================================================`n" -ForegroundColor Cyan

# Cleanup
Write-Host "Cleaning up test files..." -ForegroundColor Gray
Remove-Item $TestDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Benchmark complete!`n" -ForegroundColor Green
