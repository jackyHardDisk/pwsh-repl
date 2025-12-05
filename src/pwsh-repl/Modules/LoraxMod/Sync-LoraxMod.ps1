<#
.SYNOPSIS
Sync loraxmod JS library from main development repo

.DESCRIPTION
Copies extractors, core, filters, and grammars from the loraxMod main repo
to the bundled copy in pwsh-repl. Preserves pwsh-repl-specific files:
- parsers/streaming_query_parser.js (different protocol)
- lib/index.js (no custom error classes, different extractor registration)

.PARAMETER SourceRepo
Path to loraxMod main development repo. Default: C:\Users\jacks\experiments\WebStormProjects\loraxMod

.PARAMETER DryRun
Show what would be synced without making changes

.EXAMPLE
.\Sync-LoraxMod.ps1
# Syncs from default source location

.EXAMPLE
.\Sync-LoraxMod.ps1 -DryRun
# Preview changes without applying

.NOTES
Run from: pwsh-repl/src/pwsh-repl/Modules/LoraxMod/
#>
[CmdletBinding()]
param(
    [string]$SourceRepo = "C:\Users\jacks\experiments\WebStormProjects\loraxMod",
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Paths
$destRoot = Join-Path $PSScriptRoot "loraxmod"
$sourceLib = Join-Path $SourceRepo "lib"
$sourceGrammars = Join-Path $SourceRepo "grammars"

# Validate source
if (-not (Test-Path $SourceRepo)) {
    throw "Source repo not found: $SourceRepo"
}

if (-not (Test-Path (Join-Path $SourceRepo "package.json"))) {
    throw "Not a valid loraxMod repo (no package.json): $SourceRepo"
}

Write-Host "=== LoraxMod Sync ===" -ForegroundColor Cyan
Write-Host "Source: $SourceRepo" -ForegroundColor Gray
Write-Host "Dest:   $destRoot" -ForegroundColor Gray
if ($DryRun) {
    Write-Host "[DRY RUN]" -ForegroundColor Yellow
}
Write-Host ""

# Track changes
$synced = @()
$skipped = @()

# Sync extractors (excluding __tests__)
Write-Host "Syncing extractors..." -ForegroundColor Green
$extractorSource = Join-Path $sourceLib "extractors"
$extractorDest = Join-Path $destRoot "lib\extractors"

Get-ChildItem $extractorSource -Filter "*.js" | ForEach-Object {
    $destFile = Join-Path $extractorDest $_.Name
    $sourceHash = (Get-FileHash $_.FullName -Algorithm MD5).Hash
    $destHash = if (Test-Path $destFile) { (Get-FileHash $destFile -Algorithm MD5).Hash } else { "" }

    if ($sourceHash -ne $destHash) {
        if (-not $DryRun) {
            Copy-Item $_.FullName $destFile -Force
        }
        $synced += "extractors/$($_.Name)"
        Write-Host "  + $($_.Name)" -ForegroundColor Green
    } else {
        $skipped += "extractors/$($_.Name)"
    }
}

# Sync core
Write-Host "Syncing core..." -ForegroundColor Green
$coreSource = Join-Path $sourceLib "core"
$coreDest = Join-Path $destRoot "lib\core"

if (Test-Path $coreSource) {
    Get-ChildItem $coreSource -Filter "*.js" | ForEach-Object {
        $destFile = Join-Path $coreDest $_.Name
        $sourceHash = (Get-FileHash $_.FullName -Algorithm MD5).Hash
        $destHash = if (Test-Path $destFile) { (Get-FileHash $destFile -Algorithm MD5).Hash } else { "" }

        if ($sourceHash -ne $destHash) {
            if (-not $DryRun) {
                Copy-Item $_.FullName $destFile -Force
            }
            $synced += "core/$($_.Name)"
            Write-Host "  + $($_.Name)" -ForegroundColor Green
        } else {
            $skipped += "core/$($_.Name)"
        }
    }
}

# Sync lib root files (errors.js, etc. - excluding index.js which needs manual merge)
Write-Host "Syncing lib root files..." -ForegroundColor Green
$libDest = Join-Path $destRoot "lib"

Get-ChildItem $sourceLib -Filter "*.js" | Where-Object { $_.Name -ne "index.js" } | ForEach-Object {
    $destFile = Join-Path $libDest $_.Name
    $sourceHash = (Get-FileHash $_.FullName -Algorithm MD5).Hash
    $destHash = if (Test-Path $destFile) { (Get-FileHash $destFile -Algorithm MD5).Hash } else { "" }

    if ($sourceHash -ne $destHash) {
        if (-not $DryRun) {
            Copy-Item $_.FullName $destFile -Force
        }
        $synced += "lib/$($_.Name)"
        Write-Host "  + $($_.Name)" -ForegroundColor Green
    } else {
        $skipped += "lib/$($_.Name)"
    }
}

# Sync filters
Write-Host "Syncing filters..." -ForegroundColor Green
$filtersSource = Join-Path $sourceLib "filters"
$filtersDest = Join-Path $destRoot "lib\filters"

if (Test-Path $filtersSource) {
    Get-ChildItem $filtersSource -Filter "*.js" | ForEach-Object {
        $destFile = Join-Path $filtersDest $_.Name
        $sourceHash = (Get-FileHash $_.FullName -Algorithm MD5).Hash
        $destHash = if (Test-Path $destFile) { (Get-FileHash $destFile -Algorithm MD5).Hash } else { "" }

        if ($sourceHash -ne $destHash) {
            if (-not $DryRun) {
                Copy-Item $_.FullName $destFile -Force
            }
            $synced += "filters/$($_.Name)"
            Write-Host "  + $($_.Name)" -ForegroundColor Green
        } else {
            $skipped += "filters/$($_.Name)"
        }
    }
}

# Sync grammars (WASM files and BUILD-INFO.txt)
Write-Host "Syncing grammars..." -ForegroundColor Green
$grammarsDest = Join-Path $destRoot "grammars"

Get-ChildItem $sourceGrammars -Include "*.wasm", "BUILD-INFO.txt" | ForEach-Object {
    $destFile = Join-Path $grammarsDest $_.Name
    $sourceHash = (Get-FileHash $_.FullName -Algorithm MD5).Hash
    $destHash = if (Test-Path $destFile) { (Get-FileHash $destFile -Algorithm MD5).Hash } else { "" }

    if ($sourceHash -ne $destHash) {
        if (-not $DryRun) {
            Copy-Item $_.FullName $destFile -Force
        }
        $synced += "grammars/$($_.Name)"
        Write-Host "  + $($_.Name)" -ForegroundColor Green
    } else {
        $skipped += "grammars/$($_.Name)"
    }
}

# Summary
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Synced:  $($synced.Count) files" -ForegroundColor $(if ($synced.Count -gt 0) { 'Green' } else { 'Gray' })
Write-Host "Skipped: $($skipped.Count) files (unchanged)" -ForegroundColor Gray

if ($synced.Count -gt 0) {
    Write-Host ""
    Write-Host "Files synced:" -ForegroundColor Yellow
    $synced | ForEach-Object { Write-Host "  $_" }
}

# Reminder about manual files
Write-Host ""
Write-Host "=== Manual Review Required ===" -ForegroundColor Yellow
Write-Host "These files have different protocols and need manual merge:" -ForegroundColor Gray
Write-Host "  - lib/index.js (error handling, extractor registration)" -ForegroundColor Gray
Write-Host "  - Compare: diff '$sourceLib\index.js' '$destRoot\lib\index.js'" -ForegroundColor DarkGray

# Return result object
[PSCustomObject]@{
    SyncedCount = $synced.Count
    SkippedCount = $skipped.Count
    SyncedFiles = $synced
    SkippedFiles = $skipped
    DryRun = $DryRun
}
