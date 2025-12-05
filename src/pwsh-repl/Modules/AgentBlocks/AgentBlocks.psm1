#Requires -Version 5.1

<#
.SYNOPSIS
    AgentBlocks - PowerShell toolkit for AI agent development

.DESCRIPTION
    Complete toolkit for AI agent development with PowerShell MCP Server:

    - Execution: Invoke-DevRun workflow, output capture, timeout handling
    - Transform: Format-Count, Group-By, similarity grouping, error analysis
    - Extract: Regex matching, text extraction, column parsing
    - Patterns: Pre-configured patterns for build tools, 43+ included
    - Meta: Pattern learning, project tool discovery
    - State: Cache management, script registry, environment export

    All sessions cache executions by default in $global:DevRunCache (initialized by C#).

.NOTES
    Author: pwsh-repl
    Version: 1.0.0
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

# Meta functions (pattern learning, project discovery)
Get-ChildItem -Path "$PSScriptRoot/Meta/*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

# Pre-configured patterns (automatically register on import)
Get-ChildItem -Path "$PSScriptRoot/Patterns/*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

# Export controlled by manifest (.psd1 FunctionsToExport)
# No Export-ModuleMember needed when using manifest
