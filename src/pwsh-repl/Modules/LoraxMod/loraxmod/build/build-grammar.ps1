# Build tree-sitter grammar WASM files
# Requires: tree-sitter CLI, emsdk activated
# PowerShell version of build-grammar.sh

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [string]$EmsdkPath
)

$ErrorActionPreference = "Stop"

# Set verbosity (Verbose comes from CmdletBinding)
if ($Quiet) {
    $VerbosePreference = "SilentlyContinue"
    $ProgressPreference = "SilentlyContinue"
}

$ScriptDir = Split-Path -Parent $PSCommandPath
$LoraxRoot = Split-Path -Parent $ScriptDir
$GrammarsDir = Join-Path $LoraxRoot "grammars"
$TempDir = Join-Path $LoraxRoot "build\temp"

if (-not $Quiet) {
    Write-Host "loraxMod Grammar Builder (PowerShell)" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
}

# Check for tree-sitter CLI
Write-Verbose "Checking for tree-sitter CLI..."
$TreeSitter = Get-Command tree-sitter -ErrorAction SilentlyContinue
if (-not $TreeSitter) {
    Write-Error "tree-sitter CLI not found. Install with: npm install -g tree-sitter-cli@0.25.9"
    exit 1
}
Write-Verbose "Found tree-sitter: $($TreeSitter.Source)"

# Find emsdk installation
Write-Verbose "Looking for emsdk installation..."
$EmsdkDir = $null
$EmsdkLocations = @(
    $EmsdkPath,
    "C:\tools\emsdk",
    "C:\emsdk",
    "$env:USERPROFILE\emsdk",
    "$env:EMSDK_ROOT"
)

foreach ($Location in $EmsdkLocations) {
    if ($Location -and (Test-Path $Location)) {
        $EmsdkDir = $Location
        Write-Verbose "Found emsdk at: $EmsdkDir"
        break
    }
}

if (-not $EmsdkDir) {
    Write-Error @"
emsdk not found. Searched: $($EmsdkLocations -join ', ')

Installation:
  git clone https://github.com/emscripten-core/emsdk.git C:\tools\emsdk
  cd C:\tools\emsdk
  .\emsdk install latest
  .\emsdk activate latest
"@
    exit 1
}

if (-not $Quiet) {
    Write-Host "Using emsdk from: $EmsdkDir" -ForegroundColor Gray
}

# Check if emcc is available (emsdk already activated)
Write-Verbose "Checking for emcc..."
$Emcc = Get-Command emcc -ErrorAction SilentlyContinue
if ($Emcc) {
    if (-not $Quiet) {
        Write-Host "✓ emcc found - emsdk already activated" -ForegroundColor Green
    }
    Write-Verbose "emcc location: $($Emcc.Source)"
} else {
    Write-Verbose "emcc not found - activating emsdk..."
    $ActivateScript = Join-Path $ScriptDir "activate-emsdk.ps1"

    if (Test-Path $ActivateScript) {
        # Use our custom activation script with proper stream handling
        $ActivateParams = @{
            EmsdkPath = $EmsdkDir
        }
        if ($Verbose) {
            $ActivateParams.Verbose = $true
        }

        & $ActivateScript @ActivateParams

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to activate emsdk"
            exit 1
        }
    } else {
        Write-Warning "activate-emsdk.ps1 not found, trying direct activation..."

        # Fallback to direct emsdk_env.ps1
        $EmsdkEnv = Join-Path $EmsdkDir "emsdk_env.ps1"
        if (-not (Test-Path $EmsdkEnv)) {
            Write-Error "emsdk_env.ps1 not found at $EmsdkEnv"
            exit 1
        }

        & $EmsdkEnv 2>&1 | ForEach-Object {
            Write-Verbose $_
        }
    }

    # Verify activation worked
    $Emcc = Get-Command emcc -ErrorAction SilentlyContinue
    if (-not $Emcc) {
        Write-Error @"
emcc not found after emsdk activation

Try activating manually:
  powershell.exe -ExecutionPolicy Bypass -File $EmsdkEnv
"@
        exit 1
    }

    if (-not $Quiet) {
        Write-Host "✓ emsdk activated successfully" -ForegroundColor Green
    }
}

# Create temp directory
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

# Grammar repository URLs
$Grammars = @{
    "javascript" = "https://github.com/tree-sitter/tree-sitter-javascript"
    "python"     = "https://github.com/tree-sitter/tree-sitter-python"
    "bash"       = "https://github.com/tree-sitter/tree-sitter-bash"
    "powershell" = "https://github.com/Airbus-CERT/tree-sitter-powershell"
    "r"          = "https://github.com/r-lib/tree-sitter-r"
    "c-sharp"    = "https://github.com/tree-sitter/tree-sitter-c-sharp"
    "rust"       = "https://github.com/tree-sitter/tree-sitter-rust"
    "c"          = "https://github.com/tree-sitter/tree-sitter-c"
    "css"        = "https://github.com/tree-sitter/tree-sitter-css"
    "fortran"    = "https://github.com/stadelmanma/tree-sitter-fortran"
}

# Export function names
$Exports = @{
    "javascript" = "_tree_sitter_javascript"
    "python"     = "_tree_sitter_python"
    "bash"       = "_tree_sitter_bash"
    "powershell" = "_tree_sitter_powershell"
    "r"          = "_tree_sitter_r"
    "c-sharp"    = "_tree_sitter_c_sharp"
    "rust"       = "_tree_sitter_rust"
    "c"          = "_tree_sitter_c"
    "css"        = "_tree_sitter_css"
    "fortran"    = "_tree_sitter_fortran"
}

# Build each grammar
foreach ($Lang in $Grammars.Keys) {
    Write-Host "Building $Lang grammar..." -ForegroundColor Cyan

    $RepoUrl = $Grammars[$Lang]
    $ExportFunc = $Exports[$Lang]
    $OutputFile = "tree-sitter-$Lang.wasm"

    Set-Location $TempDir

    # Clone or update
    if (Test-Path "tree-sitter-$Lang") {
        Write-Host "  Updating existing clone..."
        Set-Location "tree-sitter-$Lang"
        git pull 2>&1 | Out-Null
    } else {
        Write-Host "  Cloning $RepoUrl..."
        git clone $RepoUrl "tree-sitter-$Lang" 2>&1 | Out-Null
        Set-Location "tree-sitter-$Lang"
    }

    # Generate parser
    if (-not $Quiet) {
        Write-Host "  Generating parser..." -ForegroundColor Gray
    }
    Write-Verbose "Running: tree-sitter generate"
    tree-sitter generate 2>&1 | ForEach-Object {
        Write-Verbose $_
    }

    # Compile to WASM
    if (-not $Quiet) {
        Write-Host "  Compiling to WASM..." -ForegroundColor Gray
    }

    $ScannerC = "src/scanner.c"
    $ScannerCC = "src/scanner.cc"

    if (Test-Path $ScannerC) {
        Write-Verbose "Compiling with scanner.c"
        emcc src/parser.c src/scanner.c -o $OutputFile `
            -I./src -Os -fPIC -s WASM=1 -s SIDE_MODULE=2 `
            -s EXPORTED_FUNCTIONS="['$ExportFunc']" 2>&1 | ForEach-Object {
            Write-Verbose $_
        }
    } elseif (Test-Path $ScannerCC) {
        Write-Verbose "Compiling with scanner.cc"
        emcc src/parser.c src/scanner.cc -o $OutputFile `
            -I./src -Os -fPIC -s WASM=1 -s SIDE_MODULE=2 `
            -s EXPORTED_FUNCTIONS="['$ExportFunc']" 2>&1 | ForEach-Object {
            Write-Verbose $_
        }
    } else {
        Write-Verbose "Compiling without scanner"
        emcc src/parser.c -o $OutputFile `
            -I./src -Os -fPIC -s WASM=1 -s SIDE_MODULE=2 `
            -s EXPORTED_FUNCTIONS="['$ExportFunc']" 2>&1 | ForEach-Object {
            Write-Verbose $_
        }
    }

    # Copy to grammars directory
    if (-not $Quiet) {
        Write-Host "  Copying to grammars directory..." -ForegroundColor Gray
    }
    Write-Verbose "Copying $OutputFile to $GrammarsDir"
    Copy-Item $OutputFile $GrammarsDir -Force

    # Get file size
    $WasmFile = Get-Item (Join-Path $GrammarsDir $OutputFile)
    $SizeMB = [math]::Round($WasmFile.Length / 1MB, 2)

    if (-not $Quiet) {
        Write-Host "  ✓ $Lang grammar built successfully! ($SizeMB MB)" -ForegroundColor Green
        Write-Host ""
    }
    Write-Verbose "${Lang}: $SizeMB MB"
}

Write-Host "All grammars built successfully!" -ForegroundColor Green
Write-Host "Output: $GrammarsDir"
Write-Host ""

# Return to original directory
Set-Location $LoraxRoot
