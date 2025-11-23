# Example: Custom Result Transformation
# Demonstrates: Processing results with custom transformations and filtering

# Import module
Import-Module LoraxMod

# Create test files with different patterns
$testDir = "C:\temp\lorax_custom_test"
if (-not (Test-Path $testDir)) {
    New-Item -ItemType Directory -Path $testDir | Out-Null
}

Write-Host "`n=== Custom Result Transformation ===" -ForegroundColor Cyan
Write-Host ""

# Create sample files with varying complexity
$files = @(
    @{ Name = "simple.c"; Code = "int add(int a, int b) { return a + b; }" },
    @{ Name = "moderate.c"; Code = @"
int func1() { return 1; }
int func2() { return 2; }
int func3() { return 3; }
"@ },
    @{ Name = "complex.c"; Code = @"
void function_with_long_name() {
    int x = 0;
    for (int i = 0; i < 10; i++) {
        x += i;
    }
}
int another_function() { return 42; }
int yet_another() { return 99; }
"@ }
)

Write-Host "Creating test files..." -ForegroundColor Yellow
foreach ($file in $files) {
    $path = Join-Path $testDir $file.Name
    $file.Code | Out-File -FilePath $path -Encoding utf8
}
Write-Host "  Created $($files.Count) test files" -ForegroundColor Green

# Start parser session
Write-Host "`nStarting parser session..." -ForegroundColor Yellow
Start-LoraxStreamParser -SessionId 'custom' | Out-Null

# Parse all files
Write-Host "`nParsing files..." -ForegroundColor Yellow
$rawResults = Get-ChildItem $testDir\*.c |
              Invoke-LoraxStreamQuery -SessionId 'custom' -Command parse

Write-Host "  Parsed $($rawResults.Count) files" -ForegroundColor Green

# Custom transformation 1: Extract function metadata
Write-Host "`nTransformation 1: Function Metadata" -ForegroundColor Cyan
$functionMetadata = $rawResults | Where-Object { $_.status -eq 'ok' } | ForEach-Object {
    $fileName = Split-Path $_.result.file -Leaf
    foreach ($segment in $_.result.segments) {
        [PSCustomObject]@{
            File = $fileName
            Function = $segment.name
            Lines = $segment.lineCount
            Complexity = if ($segment.lineCount -gt 5) { 'Complex' } elseif ($segment.lineCount -gt 2) { 'Moderate' } else { 'Simple' }
        }
    }
}

$functionMetadata | Format-Table -AutoSize

# Custom transformation 2: Aggregate by complexity
Write-Host "Transformation 2: Complexity Distribution" -ForegroundColor Cyan
$complexityStats = $functionMetadata |
                   Group-Object Complexity |
                   Select-Object Name, Count |
                   Sort-Object Count -Descending

$complexityStats | Format-Table -AutoSize

# Custom transformation 3: Filter for long function names
Write-Host "Transformation 3: Functions with Long Names (>15 chars)" -ForegroundColor Cyan
$longNames = $functionMetadata |
             Where-Object { $_.Function.Length -gt 15 } |
             Select-Object File, Function, @{Name='Length';Expression={$_.Function.Length}}

if ($longNames) {
    $longNames | Format-Table -AutoSize
} else {
    Write-Host "  (No functions with long names found)" -ForegroundColor Gray
}

# Custom transformation 4: Generate summary report
Write-Host "Transformation 4: Summary Report" -ForegroundColor Cyan
$report = [PSCustomObject]@{
    TotalFiles = $rawResults.Count
    TotalFunctions = $functionMetadata.Count
    AverageComplexity = [math]::Round(($functionMetadata.Lines | Measure-Object -Average).Average, 1)
    ComplexFunctions = ($functionMetadata | Where-Object { $_.Complexity -eq 'Complex' }).Count
    ModerateFunctions = ($functionMetadata | Where-Object { $_.Complexity -eq 'Moderate' }).Count
    SimpleFunctions = ($functionMetadata | Where-Object { $_.Complexity -eq 'Simple' }).Count
}

$report | Format-List

# Export to JSON for further processing
$exportPath = "$testDir\analysis_results.json"
$functionMetadata | ConvertTo-Json | Out-File $exportPath -Encoding utf8
Write-Host "  Exported detailed results to: $exportPath" -ForegroundColor Gray

# Stop session
Write-Host "`nStopping parser session..." -ForegroundColor Yellow
$stats = Stop-LoraxStreamParser -SessionId 'custom'
Write-Host "  Session stopped (processed $($stats.FilesProcessed) files)" -ForegroundColor Green

Write-Host "`n=== Key Takeaways ===" -ForegroundColor Cyan
Write-Host "  - Parse results are PowerShell objects (easy to transform)" -ForegroundColor White
Write-Host "  - Use Where-Object, Select-Object, ForEach-Object for filtering" -ForegroundColor White
Write-Host "  - Group-Object for aggregation and statistics" -ForegroundColor White
Write-Host "  - Export to JSON/CSV for external tools" -ForegroundColor White

Write-Host "`n=== Example Complete ===" -ForegroundColor Cyan
Write-Host ""

# Cleanup
Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
