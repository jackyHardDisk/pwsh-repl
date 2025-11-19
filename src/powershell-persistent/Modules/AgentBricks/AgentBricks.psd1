@{
    # Script module or binary module file associated with this manifest
    RootModule = 'AgentBricks.psm1'

    # Version number of this module
    ModuleVersion = '0.1.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core', 'Desktop')

    # ID used to uniquely identify this module
    GUID = 'a228fd8f-82d1-43c1-9143-555876e72e58'

    # Author of this module
    Author = 'homebrew-mcp'

    # Company or vendor of this module
    CompanyName = 'homebrew-mcp'

    # Copyright statement for this module
    Copyright = '(c) 2024 homebrew-mcp. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Self-teaching development toolkit for agent-driven PowerShell workflows. Provides composable functions for parsing build output, extracting errors, learning tool patterns, and analyzing development tool output. Designed for AI agents to discover and use via PowerShell help system.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Functions to export from this module
    FunctionsToExport = @(
        # Transform
        'Format-Count',
        'Group-By',
        'Measure-Frequency',
        'Group-Similar',
        'Group-BuildErrors',
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
        'Get-StreamData',
        'Show-StreamSummary',
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
        'Export-Environment',
        'Clear-Stored',
        'Set-EnvironmentTee',
        # DevRun Cache
        'Initialize-DevRunCache',
        'Get-CachedStreamData',
        'Clear-DevRunCache',
        'Get-DevRunCacheStats',
        # DevRun Script Registry
        'Add-DevScript',
        'Get-DevScripts',
        'Remove-DevScript',
        'Update-DevScriptMetadata',
        # DevRun Script Invocation
        'Invoke-DevScript',
        'Invoke-DevScriptChain',
        # Utility
        'Invoke-WithTimeout'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @('BrickStore')

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Development', 'Build', 'Testing', 'Linting', 'Analysis', 'Agent', 'AI')

            # A URL to the license for this module
            # LicenseUri = ''

            # A URL to the main website for this project
            # ProjectUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
0.1.0 - Initial POC Release
- Core transformation functions (Format-Count, Group-By, Measure-Frequency, Group-Similar, Group-BuildErrors)
- Fuzzy grouping with Jaro-Winkler distance for error clustering
- Data extraction (Extract-Regex, Extract-Between, Extract-Column)
- Analysis functions (Find-Errors, Find-Warnings, Parse-BuildOutput)
- Presentation functions (Show, Export-ToFile, Get-StreamData, Show-StreamSummary)
- dev_run stream integration (retrieve and format Error, Warning, Output, Verbose, Debug, Information)
- Meta-learning (Learn-OutputPattern, Test-Pattern, Set-Pattern, Get-Patterns)
- Project discovery (Find-ProjectTools)
- Pre-configured patterns for JS/TS, Python, .NET, and build tools (40+)
- State management (Save-Project, Load-Project, Get-BrickStore, Export-Environment, Clear-Stored, Set-EnvironmentTee)
- Pipeline tee functionality for capture-and-pass-through workflows
- Utility functions (Invoke-WithTimeout)
'@
        }
    }
}
