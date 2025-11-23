# Example: Basic Streaming Parser Usage
# Demonstrates: Single file processing with streaming parser

# Import module
Import-Module LoraxMod

# Create sample C file
$sampleFile = "C:\temp\sample.c"
$sampleCode = @'
#include <stdio.h>

int add(int a, int b) {
    return a + b;
}

int multiply(int x, int y) {
    return x * y;
}

int main() {
    int sum = add(5, 3);
    int product = multiply(4, 7);
    printf("Sum: %d, Product: %d\n", sum, product);
    return 0;
}
'@

# Ensure temp directory exists
if (-not (Test-Path C:\temp)) {
    New-Item -ItemType Directory -Path C:\temp | Out-Null
}

$sampleCode | Out-File -FilePath $sampleFile -Encoding utf8

Write-Host "`n=== Basic Streaming Parser Usage ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Start parser session
Write-Host "Step 1: Starting parser session..." -ForegroundColor Yellow
$sessionId = Start-LoraxStreamParser
Write-Host "  Session ID: $sessionId" -ForegroundColor Green

# Step 2: Parse the file
Write-Host "`nStep 2: Parsing file..." -ForegroundColor Yellow
$result = Invoke-LoraxStreamQuery -File $sampleFile -Command parse

if ($result.status -eq 'ok') {
    Write-Host "  Parse successful!" -ForegroundColor Green
    Write-Host "  Language: $($result.result.language)" -ForegroundColor Gray
    Write-Host "  Segments found: $($result.result.segmentCount)" -ForegroundColor Gray

    # Display segments
    Write-Host "`nCode segments:" -ForegroundColor Cyan
    $result.result.segments | ForEach-Object {
        Write-Host "  - $($_.type): $($_.name) (lines $($_.startLine)-$($_.endLine))" -ForegroundColor White
    }
} else {
    Write-Host "  Parse failed: $($result.error.message)" -ForegroundColor Red
}

# Step 3: Ping to check parser health
Write-Host "`nStep 3: Checking parser health..." -ForegroundColor Yellow
$pingResult = Invoke-LoraxStreamQuery -Command ping

if ($pingResult.status -eq 'pong') {
    Write-Host "  Parser healthy" -ForegroundColor Green
    Write-Host "  Files processed: $($pingResult.filesProcessed)" -ForegroundColor Gray
    Write-Host "  Uptime: $($pingResult.uptime)ms" -ForegroundColor Gray
}

# Step 4: Stop parser session
Write-Host "`nStep 4: Stopping parser session..." -ForegroundColor Yellow
$stats = Stop-LoraxStreamParser

Write-Host "  Session stopped" -ForegroundColor Green
Write-Host "  Files processed: $($stats.FilesProcessed)" -ForegroundColor Gray
Write-Host "  Duration: $($stats.DurationSeconds)s" -ForegroundColor Gray

Write-Host "`n=== Example Complete ===" -ForegroundColor Cyan
Write-Host ""

# Cleanup
Remove-Item $sampleFile -Force -ErrorAction SilentlyContinue
