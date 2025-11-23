@{
# Script module or binary module file associated with this manifest
    RootModule = 'AgentBricks.psm1'

    # Version number of this module
    ModuleVersion = '0.2.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core', 'Desktop')

    # ID used to uniquely identify this module
    GUID = 'a228fd8f-82d1-43c1-9143-555876e72e58'

    # Author of this module
    Author = 'pwsh-repl'

    # Company or vendor of this module
    CompanyName = 'pwsh-repl'

    # Copyright statement for this module
    Copyright = '(c) 2024 pwsh-repl. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Pattern learning and meta-discovery toolkit for agent-driven PowerShell workflows. Provides pre-configured patterns for 40+ development tools and meta-learning functions. Core functions migrated to Base module. Designed for AI agents to discover and use via PowerShell help system.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Required modules (must be loaded before this module)
    RequiredModules = @('Base')

    # Functions to export from this module
    FunctionsToExport = @(
        # Meta - Discovery
        'Find-ProjectTools',
        # Meta - Learning
        'Set-Pattern',
        'Get-Patterns',
        'Test-Pattern',
        'Register-OutputPattern'
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
0.2.0 - Base Module Migration (2025-11-23)
BREAKING CHANGES:
- Core functions (40 total) migrated to Base module
- AgentBricks now focused on pattern learning and meta-discovery (5 functions)
- RequiredModules: Base (auto-loads)

Retained in AgentBricks:
- Pattern learning: Get-Patterns, Set-Pattern, Test-Pattern, Register-OutputPattern
- Meta-discovery: Find-ProjectTools
- Pre-configured patterns: 43 patterns for JavaScript, Python, .NET, Build tools

Migration Guide:
- Old: Import-Module AgentBricks; Format-Count ...
- New: Import-Module AgentBricks; Format-Count ...  # Same! (Base auto-loads)
- Standalone Base: Import-Module Base; Format-Count ...

Migrated to Base:
- All Transform, Extract, Analyze, Present functions
- All DevRun cache and script registry functions
- All state management and background process functions
- See Base module v0.2.0 for complete list

0.1.1 - Background Process Management
- Background process execution, monitoring
- dev_run cache integration
- PowerShell scripts and external executables

0.1.0 - Initial POC Release
- 40+ functions for build analysis, error parsing, pattern learning
- Fuzzy grouping with Jaro-Winkler distance
- Pre-configured patterns for JS/TS, Python, .NET, build tools
'@
        }
    }
}
