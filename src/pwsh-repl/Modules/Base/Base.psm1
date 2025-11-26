#Requires -Version 5.1

<#
.SYNOPSIS
    Base - Foundational functions for PowerShell MCP Server

.DESCRIPTION
    Core execution, transformation, and state management functions that form the foundation
    for all PowerShell MCP Server operations. This module provides:

    - Execution: Invoke-DevRun workflow (mode callback pattern), output capture, timeout handling
    - Transform: Format-Count, Group-By, similarity grouping, error analysis
    - State: Cache management, script registry, environment export

    All sessions cache executions by default in $global:DevRunCache (initialized by C#).

.NOTES
    Author: pwsh-repl
    Version: 0.2.0
    This module auto-loads with PowerShell MCP Server sessions.
    Cache initialization handled by SessionManager.cs (ConcurrentDictionary).
#>

# Dot-source all function files
# Core execution functions
Get-ChildItem -Path "$PSScriptRoot/Core/*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

# Transform functions (analysis, formatting, extraction)
Get-ChildItem -Path "$PSScriptRoot/Transform/*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

# State management functions (cache, registry, export)
Get-ChildItem -Path "$PSScriptRoot/State/*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

# Export controlled by manifest (.psd1 FunctionsToExport)
# No Export-ModuleMember needed when using manifest
