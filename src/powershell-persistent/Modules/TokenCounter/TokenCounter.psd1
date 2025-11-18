@{
    # Script module or binary module file associated with this manifest
    RootModule = 'TokenCounter.psm1'

    # Version nu,mber of this module
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core', 'Desktop')

    # ID used to uniquely identify this module
    GUID = '8c3f4d2e-9a1b-4f5c-8d3e-1a2b3c4d5e6f'

    # Author of this module
    Author = 'homebrew-mcp'

    # Company or vendor of this module
    CompanyName = 'homebrew-mcp'

    # Copyright statement for this module
    Copyright = '(c) 2024 homebrew-mcp. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Accurate token counting for Claude Code optimization. Single-function module using Python tiktoken for precise token measurement. Designed for MCP server optimization, slash command analysis, and documentation token budgeting.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @('Measure-Tokens')

    # Cmdlets to export from this module (none)
    CmdletsToExport = @()

    # Variables to export from this module (none)
    VariablesToExport = @()

    # Aliases to export from this module (none)
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Tokens', 'Claude', 'GPT', 'OpenAI', 'tiktoken', 'Optimization', 'MCP', 'AI')

            # A URL to the license for this module
            # LicenseUri = ''

            # A URL to the main website for this project
            # ProjectUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
1.0.0 - Simplified Release (2024-11-17)
- Reduced from 693 lines to 272 lines (61% reduction)
- Single function: Measure-Tokens (accurate token counting via tiktoken)
- Removed Measure-McpTools (use PowerShell one-liners)
- Removed Compare-TokenUsage (use arithmetic: $before - $after)
- Removed Find-TokenHogs (use Sort-Object)
- Removed Show-TokenBreakdown (never implemented, not needed)
- Philosophy: One function, one job. Compose with PowerShell built-ins.
- Returns simple integer for pipeline operations
- Elaborate Get-Help documentation with 8 examples
- Design: Simplicity over complexity, accuracy over approximation

0.1.0 - Initial Release (Over-engineered)
- 4 exported functions (693 lines)
- Feature bloat: visual bars, color coding, baseline tracking
- Complexity for complexity sake
- Replaced by 1.0.0 simplified design
'@
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module
    # DefaultCommandPrefix = ''
}