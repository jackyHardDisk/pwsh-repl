# Quick script to build just C++ grammar
# Usage: .\build\build-cpp.ps1

$ErrorActionPreference = "Stop"

# Activate emsdk
$EMSDK_DIR = if ($env:EMSDK_ROOT) { $env:EMSDK_ROOT } else { "C:\tools\emsdk" }
Write-Host "Activating emsdk from: $EMSDK_DIR"
& "$EMSDK_DIR\emsdk_env.ps1"

# Check emcc available
if (-not (Get-Command emcc -ErrorAction SilentlyContinue)) {
    Write-Error "emcc not found - emsdk activation failed"
    exit 1
}

# Create temp directory
$TEMP_DIR = "temp_grammar_cpp"
if (Test-Path $TEMP_DIR) {
    Remove-Item -Recurse -Force $TEMP_DIR
}
New-Item -ItemType Directory -Path $TEMP_DIR | Out-Null

try {
    Set-Location $TEMP_DIR

    Write-Host "Cloning tree-sitter-cpp..."
    git clone --depth 1 https://github.com/tree-sitter/tree-sitter-cpp.git
    Set-Location tree-sitter-cpp

    Write-Host "Compiling C++ grammar to WASM..."
    npm install
    npx tree-sitter build --wasm

    Write-Host "Copying WASM file..."
    Copy-Item "tree-sitter-cpp.wasm" "..\..\grammars\" -Force

    Set-Location ..\..
    Write-Host "Success! C++ grammar compiled to grammars\tree-sitter-cpp.wasm"
}
finally {
    Set-Location $PSScriptRoot\..
    if (Test-Path $TEMP_DIR) {
        Write-Host "Cleaning up..."
        Remove-Item -Recurse -Force $TEMP_DIR
    }
}
