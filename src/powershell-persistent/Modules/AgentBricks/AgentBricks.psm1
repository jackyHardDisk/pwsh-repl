# AgentBricks - Self-Teaching Development Toolkit
# Main module file

# Initialize BrickStore (global state)
$global:BrickStore = @{
    Results = @{}     # Stored results from dev-run and analysis
    Patterns = @{}    # Learned regex patterns for tool output
    Chains = @{}      # Saved analysis pipelines (future enhancement)
}

# Dot-source all function files
# Core functions
. $PSScriptRoot/Core/Transform.ps1
. $PSScriptRoot/Core/Extract.ps1
. $PSScriptRoot/Core/Analyze.ps1
. $PSScriptRoot/Core/Present.ps1

# Meta-tools
. $PSScriptRoot/Meta/Discovery.ps1
. $PSScriptRoot/Meta/Learning.ps1

# State management
. $PSScriptRoot/State/Management.ps1

# Pre-configured patterns (automatically register on import)
. $PSScriptRoot/Patterns/JavaScript.ps1
. $PSScriptRoot/Patterns/Python.ps1
. $PSScriptRoot/Patterns/DotNet.ps1
. $PSScriptRoot/Patterns/Build.ps1

# Auto-load project knowledge if .brickyard.json exists in current directory
if (Test-Path ".brickyard.json") {
    try {
        Load-Project -Path ".brickyard.json" -ErrorAction SilentlyContinue
        Write-Host "Loaded project patterns from .brickyard.json" -ForegroundColor Green
    }
    catch {
        # Silently continue if load fails
    }
}

# Module banner
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          AgentBricks - Development Toolkit            ║" -ForegroundColor Cyan
Write-Host "║                     v0.1.0 POC                         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Quick Start:" -ForegroundColor White
Write-Host "  Get-BrickStore       - View loaded patterns and state" -ForegroundColor Gray
Write-Host "  Find-ProjectTools    - Discover available tools" -ForegroundColor Gray
Write-Host "  Get-Patterns         - List learned patterns" -ForegroundColor Gray
Write-Host "  Get-Help <function>  - Full documentation" -ForegroundColor Gray
Write-Host ""
Write-Host "Pre-loaded patterns: $($global:BrickStore.Patterns.Count)" -ForegroundColor Green
Write-Host ""

# Export module members (also defined in .psd1 manifest)
Export-ModuleMember -Function @(
    # Transform
    'Format-Count',
    'Group-By',
    'Measure-Frequency',
    # Extract
    'Extract-Regex',
    'Extract-Between',
    'Extract-Column',
    # Analyze
    'Find-Errors',
    'Find-Warnings',
    'Parse-BuildOutput',
    # Present
    'Show',
    'Export-ToFile',
    # Meta - Discovery
    'Find-ProjectTools',
    # Meta - Learning
    'Set-Pattern',
    'Get-Patterns',
    'Test-Pattern',
    'Learn-OutputPattern',
    # State
    'Save-Project',
    'Load-Project',
    'Get-BrickStore',
    'Clear-Stored'
) -Variable 'BrickStore'
