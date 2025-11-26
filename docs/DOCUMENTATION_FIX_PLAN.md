# Documentation Fix Plan - dev_run References and Inaccuracies

## Executive Summary

Found 27+ references to 'dev_run' terminology inconsistent with actual implementation.
'dev_run' used two conflicting ways:
1. As if standalone MCP tool (INCORRECT - no such tool exists)
2. As shorthand for Invoke-DevRun workflow (ACCEPTABLE but needs clarification)

## Current Reality

- **4 MCP Tools**: test, stdin, pwsh, list_sessions
- **NO dev_run tool** - it's PowerShell function (Invoke-DevRun) in Base module
- **Mode callback**: pwsh tool calls Invoke-DevRun via mode='Invoke-DevRun'
- **Base**: 39 functions (CORRECT)
- **AgentBricks**: 5 functions (CORRECT)
- **LoraxMod**: 9 functions (docs say 7 - OUTDATED)
- **TokenCounter**: 1 function (CORRECT)

## Issues Found

### Category 1: Incorrect Tool References (HIGH PRIORITY)

**File**: README.md:21
- **Current**: Lists "dev_run - Iterative development workflow..."
- **Problem**: dev_run is NOT an MCP tool
- **Fix**: Remove from tools list, explain as workflow pattern in new section

**File**: README.md:43
- **Current**: "dev_run summaries: 99% reduction"
- **Fix**: "Invoke-DevRun summaries: 99% reduction"

### Category 2: Python-Style Syntax (MEDIUM PRIORITY)

Python-style syntax in 10 help files:
- Syntax: `dev_run(..., name='build')`
- Should be: `Invoke-DevRun -Script '...' -Name 'build'`

**Affected Files**:
1. docs/help/Base/Get-StreamData.md (lines 67, 298)
2. docs/help/Base/Get-CachedStreamData.md (line 50)
3. docs/help/Base/Show-StreamSummary.md (line 58)
4. docs/help/Base/Set-EnvironmentTee.md (line 39)
5. Plus 6 others from grep results

**Fix Strategy**: Replace Python-style with PowerShell-style in parameter descriptions

### Category 3: Generic "dev_run" Workflow References (LOW PRIORITY)

Used as shorthand for "Invoke-DevRun workflow" - ACCEPTABLE but clarify in glossary.

**Examples** (15 files):
- "after running dev_run again" → "after running Invoke-DevRun again"
- "from dev_run cache" → "from DevRun cache" (acceptable - cache name)
- "dev_run JSON storage" → "DevRun cache JSON storage"

**Fix Strategy**: Optional - add glossary note explaining shorthand

### Category 4: Module Descriptions (MEDIUM PRIORITY)

**File**: src/pwsh-repl/Modules/Base/Base.psm1:11
- **Current**: "dev_run workflow, output capture"
- **Fix**: "Invoke-DevRun workflow (mode callback pattern), output capture"

**File**: CLAUDE.md:99
- **Current**: "Execute script with stream capture (dev_run workflow)"
- **Fix**: "Execute script with stream capture (Invoke-DevRun workflow)"

### Category 5: Outdated Module Counts (HIGH PRIORITY)

**File**: CLAUDE.md:37
- **Current**: "7 functions" for LoraxMod
- **Actual**: 9 functions
- **Fix**: Update to 9

**File**: README.md:25-26
- **Current**: "20 PowerShell functions" for AgentBricks
- **Actual**: 5 AgentBricks + 39 Base = 44 total (or just 5 in AgentBricks)
- **Fix**: Clarify - is this "20 in AgentBricks" or "20 analysis functions across modules"?

**File**: CLAUDE.md:36
- **Current**: Lists Base as 39 functions
- **Actual**: 39 functions
- **Status**: CORRECT

### Category 6: Source Code Docstrings (LOW PRIORITY)

7 PowerShell files have dev_run in function docstrings:
- src/pwsh-repl/Modules/Base/Transform/Present.ps1 (Get-StreamData, Show-StreamSummary)
- src/pwsh-repl/Modules/AgentBricks/State/DevRunCache.ps1 (6 functions)
- src/pwsh-repl/Modules/AgentBricks/State/BackgroundProcess.ps1 (2 functions)
- src/pwsh-repl/Modules/AgentBricks/State/Management.ps1 (Set-EnvironmentTee)

**Fix Strategy**: Match docstrings to updated help docs (regenerate with Update-MarkdownHelp)

## Recommended Fix Order

### Phase 1: Critical Corrections (30 min)
1. README.md - Remove dev_run from tools list, fix summary reference
2. CLAUDE.md - Update LoraxMod count to 9, clarify dev_run workflow refs
3. Clarify README AgentBricks function count

### Phase 2: Help Doc Syntax (60 min)
4. Find/replace Python syntax in 10 help markdown files
5. Regenerate MAML with New-ExternalHelp

### Phase 3: Source Docstrings (45 min)
6. Update docstrings in 7 PowerShell source files
7. Regenerate help markdown with New-MarkdownHelp -UpdateInputOutput
8. Regenerate MAML again

### Phase 4: Generic References (15 min - OPTIONAL)
9. Add glossary section to README explaining dev_run shorthand
10. Optionally replace generic dev_run refs with Invoke-DevRun

## Implementation Scripts

### Script 1: Find Python-Style Syntax
```powershell
Get-ChildItem docs/help/**/*.md -Recurse |
    Select-String 'dev_run\(' |
    Select-Object Path, LineNumber, Line
```

### Script 2: Bulk Replace in Help Docs
```powershell
$files = Get-ChildItem docs/help/**/*.md -Recurse
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw

    # Replace Python-style dev_run(..., name='X') syntax
    $content = $content -replace 'dev_run\([^,]+,\s*name=[''"](\w+)[''"]\)',
                                  'Invoke-DevRun -Script ''...'' -Name ''$1'''

    # Replace generic dev_run with Invoke-DevRun where appropriate
    $content = $content -replace 'running dev_run', 'running Invoke-DevRun'
    $content = $content -replace 'execute dev_run', 'execute Invoke-DevRun'

    Set-Content $file.FullName -Value $content -NoNewline
}
```

### Script 3: Update Source Docstrings
Run after help doc fixes:
```powershell
Import-Module PlatyPS
Update-MarkdownHelpModule -Path docs/help/Base -RefreshModulePage -UpdateInputOutput
Update-MarkdownHelpModule -Path docs/help/AgentBricks -RefreshModulePage -UpdateInputOutput
```

## Files Requiring Manual Review

1. README.md - AgentBricks function count (line 25-26)
2. Set-EnvironmentTee.md - Has Python example (line 39)
3. Base.psm1 - Module description (line 11)

## Post-Fix Validation

1. Grep for remaining 'dev_run' references
2. Test Get-Help on all functions
3. Verify MAML help files load correctly
4. Confirm no broken references in examples
