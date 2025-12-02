# Background Process Analysis Functions
# Background process creation/management now handled by C# SessionManager.
# Use stdio MCP tool to interact with background processes.
# This file provides Get-BackgroundData for analyzing stopped process output.

function Get-BackgroundData
{
    <#
    .SYNOPSIS
    Retrieve background process output from DevRun cache.

    .DESCRIPTION
    Convenience wrapper over Get-StreamData for background processes.
    Retrieves captured output for analysis with AgentBlocks functions.

    When a background process is stopped via the stdio MCP tool (or session cleanup),
    its output is automatically populated into the DevRun cache. This function
    retrieves that cached output for analysis.

    Functionally identical to Get-StreamData - use whichever feels more natural.
    This function exists for semantic clarity when working with background processes.

    .PARAMETER Name
    Name of background process (used when starting the process).

    .PARAMETER Stream
    Which stream to retrieve (Error, Warning, Output, etc.).

    .EXAMPLE
    Get-BackgroundData build Error | Find-Errors | Format-Count

    .EXAMPLE
    Get-BackgroundData server Output | Select-RegexMatch -Pattern 'Listening on (?<port>\d+)'

    .EXAMPLE
    # Equivalent to Get-StreamData
    Get-BackgroundData test Error | Group-BuildErrors
    Get-StreamData test Error | Group-BuildErrors

    .NOTES
    Alias for Get-StreamData - use whichever is clearer in context.
    Requires the background process to have been stopped first to populate cache.
    Background processes are managed by C# SessionManager, not PowerShell.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [ValidateSet('Error', 'Warning', 'Output', 'Verbose', 'Debug', 'Information')]
        [string]$Stream = 'Output'
    )

    Get-StreamData -Name $Name -Stream $Stream
}
