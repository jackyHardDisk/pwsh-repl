# Activate Emscripten SDK (emsdk)
# Proper PowerShell script with stream handling

[CmdletBinding()]
param(
    [Parameter()]
    [string]$EmsdkPath = "C:\tools\emsdk"
)

# Find emsdk installation
$EmsdkLocations = @(
    $EmsdkPath,
    "C:\tools\emsdk",
    "C:\emsdk",
    "$env:USERPROFILE\emsdk",
    "$env:EMSDK_ROOT"
)

$EmsdkDir = $null
foreach ($Location in $EmsdkLocations) {
    if ($Location -and (Test-Path $Location)) {
        $EmsdkDir = $Location
        break
    }
}

if (-not $EmsdkDir) {
    Write-Error "emsdk not found. Searched locations: $($EmsdkLocations -join ', ')"
    Write-Error "Install emsdk:"
    Write-Error "  git clone https://github.com/emscripten-core/emsdk.git C:\tools\emsdk"
    Write-Error "  cd C:\tools\emsdk"
    Write-Error "  .\emsdk install latest"
    Write-Error "  .\emsdk activate latest"
    exit 1
}

Write-Verbose "Found emsdk at: $EmsdkDir"

# Python locations to check
$PythonLocations = @(
    "python\3.13.3_64bit\python.exe",
    "python\3.9.2_64bit\python.exe",
    "python\3.9.2-nuget_64bit\python.exe"
)

# Find Python from emsdk location
$EmsdkPython = $null
foreach ($Location in $PythonLocations) {
    $FullLocation = Join-Path $EmsdkDir $Location
    if (Test-Path $FullLocation) {
        $EmsdkPython = $FullLocation
        break
    }
}

# Fallback to system Python
if (-not $EmsdkPython) {
    $EmsdkPython = "python"
}

Write-Verbose "Using Python: $EmsdkPython"

# Set up environment for emsdk to generate PowerShell script
$env:EMSDK_POWERSHELL = 1

# Run emsdk.py to generate environment
Push-Location $EmsdkDir
try {
    Write-Verbose "Running: & $EmsdkPython emsdk.py construct_env"
    & $EmsdkPython "emsdk.py" construct_env 2>&1 | ForEach-Object {
        if ($_ -match "^ERROR:") {
            Write-Error $_
        } elseif ($_ -match "^Warning:") {
            Write-Warning $_
        } else {
            Write-Verbose $_
        }
    }

    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0) {
        Write-Error "emsdk.py failed with exit code $ExitCode"
        exit $ExitCode
    }

    # Source the generated environment script
    $EnvScript = Join-Path $EmsdkDir "emsdk_set_env.ps1"
    if (Test-Path $EnvScript) {
        Write-Verbose "Sourcing environment from $EnvScript"
        & $EnvScript

        # Clean up
        Remove-Item $EnvScript -ErrorAction SilentlyContinue

        Write-Host "✓ emsdk activated successfully" -ForegroundColor Green
        Write-Host "  EMSDK: $env:EMSDK" -ForegroundColor Gray
        Write-Host "  PATH updated with emsdk tools" -ForegroundColor Gray
    } else {
        Write-Error "Expected environment script not found: $EnvScript"
        exit 1
    }
} finally {
    Pop-Location
    Remove-Item Env:\EMSDK_POWERSHELL -ErrorAction SilentlyContinue
}

# Verify emcc is available
$Emcc = Get-Command emcc -ErrorAction SilentlyContinue
if ($Emcc) {
    Write-Verbose "emcc version: $(emcc --version | Select-Object -First 1)"
} else {
    Write-Warning "emcc command not found in PATH after activation"
}
