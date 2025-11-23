# AgentBricks - Self-Teaching Development Toolkit
# Main module file

# Initialize BrickStore (global state)
$global:BrickStore = @{
    Results = @{ }     # Stored results from dev-run and analysis
    Patterns = @{ }    # Learned regex patterns for tool output
    Chains = @{ }      # Saved analysis pipelines (future enhancement)
}

# Dot-source all function files
# NOTE: Core functions (Transform, Extract, Analyze, Present, Timeout) migrated to Base module
# AgentBricks now focuses on meta-learning and pattern management

# Meta-tools (AgentBricks specialty)
. $PSScriptRoot/Meta/Discovery.ps1
. $PSScriptRoot/Meta/Learning.ps1

# Pre-configured patterns (automatically register on import)
. $PSScriptRoot/Patterns/JavaScript.ps1
. $PSScriptRoot/Patterns/Python.ps1
. $PSScriptRoot/Patterns/DotNet.ps1
. $PSScriptRoot/Patterns/Build.ps1

# Auto-load project knowledge if .brickyard.json exists in current directory
if (Test-Path ".brickyard.json")
{
    try
    {
        Import-Project -Path ".brickyard.json" -ErrorAction SilentlyContinue
        Write-Verbose "Loaded project patterns from .brickyard.json"
    }
    catch
    {
        # Silently continue if load fails
    }
}

# Export controlled by manifest (.psd1 FunctionsToExport and VariablesToExport)
# No Export-ModuleMember needed when using manifest
