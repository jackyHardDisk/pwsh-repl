#Requires -Version 5.1

<#
.SYNOPSIS
    Base - Hardcoded foundational functions for PowerShell MCP Server

.DESCRIPTION
    Placeholder module for functions that must be hardcoded into the MCP server's module structure.
    Currently empty - functions will be added as needs arise.

    Use cases for Base module:
    - Core utilities needed before any user modules load
    - Functions that cannot depend on external modules
    - Critical debugging/diagnostic tools
    - Session management helpers

.NOTES
    Author: pwsh-repl
    Version: 0.1.0
    This module auto-loads with PowerShell MCP Server sessions.
#>

# Future: Add hardcoded functions here as needed

# Export module members (currently none)
Export-ModuleMember -Function @()
