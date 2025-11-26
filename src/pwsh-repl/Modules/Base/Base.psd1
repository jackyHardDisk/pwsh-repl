@{
    RootModule = 'Base.psm1'
    ModuleVersion = '0.2.0'
    CompatiblePSEditions = @('Core', 'Desktop')
    GUID = 'b4563f21-98d7-4a2c-9f1e-8c7b3d5e6a9f'
    Author = 'pwsh-repl'
    CompanyName = 'pwsh-repl'
    Copyright = '(c) 2024 pwsh-repl. All rights reserved.'
    Description = 'Foundational functions for PowerShell MCP Server execution, transformation, and state management. Provides Invoke-DevRun workflow with automatic caching, stream capture, and output analysis. Cache initialized by C# SessionManager as ConcurrentDictionary.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        # Core execution
        'Invoke-DevRun',
        'Get-DevRunOutput',
        'Get-DevRunCacheList',
        'Invoke-WithTimeout',
        # Background process
        'Invoke-BackgroundProcess',
        'Stop-BackgroundProcess',
        'Get-BackgroundData',
        'Test-BackgroundProcess',
        # Transform
        'Format-Count',
        'Group-By',
        'Measure-Frequency',
        'Group-Similar',
        'Group-BuildErrors',
        'Get-JaroWinklerDistance',
        # Extract
        'Select-RegexMatch',
        'Select-TextBetween',
        'Select-Column',
        # Analyze
        'Find-Errors',
        'Find-Warnings',
        'Get-BuildError',
        # Present
        'Show',
        'Export-ToFile',
        'Get-StreamData',
        'Show-StreamSummary',
        # State management
        'Save-Project',
        'Import-Project',
        'Get-BrickStore',
        'Export-Environment',
        'Clear-Stored',
        'Set-EnvironmentTee',
        # DevRun cache
        'Get-CachedStreamData',
        'Clear-DevRunCache',
        'Get-DevRunCacheStats',
        # Script registry
        'Add-DevScript',
        'Get-DevScripts',
        'Remove-DevScript',
        'Update-DevScriptMetadata',
        'Invoke-DevScript',
        'Invoke-DevScriptChain'
    )
    CmdletsToExport = @()
    VariablesToExport = @('DevRunCache')
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Development', 'MCP', 'Cache', 'DevOps', 'Agent', 'AI')
            ReleaseNotes = @'
0.2.0 - Base Module Foundation (2025-11-23)
Complete migration of core functions from AgentBricks (40 functions).

Core Execution:
- Invoke-DevRun: Execute scripts with stream capture and caching
- Get-DevRunOutput: Retrieve cached execution results
- Get-DevRunCacheList: List all cached entries
- Invoke-WithTimeout: Timeout wrapper for long-running commands

Background Process (4 functions):
- Invoke-BackgroundProcess, Stop-BackgroundProcess
- Get-BackgroundData, Test-BackgroundProcess

Transform (6 functions):
- Format-Count, Group-By, Measure-Frequency
- Group-Similar (Jaro-Winkler fuzzy grouping)
- Group-BuildErrors (regex + fuzzy hybrid)
- Get-JaroWinklerDistance (similarity metric)

Extract (3 functions):
- Select-RegexMatch, Select-TextBetween, Select-Column

Analyze (3 functions):
- Find-Errors, Find-Warnings, Get-BuildError

Present (4 functions):
- Show, Export-ToFile, Get-StreamData, Show-StreamSummary

State Management (6 functions):
- Save-Project, Import-Project, Get-BrickStore
- Export-Environment, Clear-Stored, Set-EnvironmentTee

DevRun Cache (3 functions):
- Get-CachedStreamData, Clear-DevRunCache, Get-DevRunCacheStats

Script Registry (6 functions):
- Add-DevScript, Get-DevScripts, Remove-DevScript
- Update-DevScriptMetadata, Invoke-DevScript, Invoke-DevScriptChain

Architecture:
- Cache initialized by C# SessionManager.cs (ConcurrentDictionary)
- Auto-loads before AgentBricks (RequiredModules dependency)
- Organized structure: Core/, Transform/, State/
- Auto-discovery loader for subdirectory files

Mode Callback Integration:
- Use via pwsh tool mode parameter
- Example: pwsh(mode='Invoke-DevRun', script='...', name='build')
- Reduces tool count from 40+ to 1 (92% token reduction)

0.1.0 - Initial placeholder release
- Empty module structure for future hardcoded functions
'@
        }
    }
}
