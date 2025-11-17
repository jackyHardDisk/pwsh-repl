# PowerShell MCP - TODO Roadmap

Prioritized next steps for PowerShell MCP server development and testing.

## Immediate Priorities

### 1. JEA Integration (Just Enough Administration)

**Goal:** Add security constraints to PowerShell execution

**Tasks:**
- Create JEA session configuration file (.pssc)
- Define role capability files (.psrc) for allowed commands
- Limit cmdlet access (whitelist approach)
- Enable transcript logging for audit trail
- Test with restricted runspace

**Benefits:**
- Security: Prevent dangerous commands (Remove-Item, Stop-Process, etc.)
- Compliance: Audit log of all PowerShell execution
- Safety: Constrained environment for agents

**Complexity:** Medium
**Priority:** High (security concern)

**Reference:**
- [JEA Documentation](https://learn.microsoft.com/en-us/powershell/scripting/learn/remoting/jea/overview)

### 2. Test Common PowerShell Commands

**Goal:** Validate pwsh tool with standard PowerShell operations

**Test Coverage:**
- File system: Get-ChildItem, Test-Path, Get-Content
- Process management: Get-Process, Start-Process
- Variables: Set, Get, Remove, scope isolation
- Pipeline: Complex multi-stage pipelines
- Error handling: Try/catch, ErrorActionPreference
- Formatting: Format-Table, Format-List, Out-String
- Session persistence: Variables across calls

**Tasks:**
- Create test script: tests/pwsh-basic-commands.ps1
- Run test suite against dev build
- Document edge cases and limitations
- Fix issues discovered during testing

**Complexity:** Low
**Priority:** High (validates core functionality)

### 3. Test AgentBricks Module Functions

**Goal:** Validate all 20 AgentBricks functions with real inputs

**Test Categories:**

**Transform (3 functions):**
- Format-Count: Verify alignment, width parameter
- Group-By: Test with objects, strings, nested properties
- Measure-Frequency: Ascending/descending sort, large datasets

**Extract (3 functions):**
- Extract-Regex: Named groups, complex patterns, no matches
- Extract-Between: Nested delimiters, multiple occurrences
- Extract-Column: CSV, TSV, custom delimiters

**Analyze (3 functions):**
- Find-Errors: Real build logs (MSBuild, GCC, npm)
- Find-Warnings: Mixed error/warning output
- Parse-BuildOutput: Multiple build tools

**Present (2 functions):**
- Show: Top, Skip, Format options
- Export-ToFile: Text, CSV, JSON formats

**Meta-Discovery (1 function):**
- Find-ProjectTools: Test on real projects (JS, Python, .NET)

**Meta-Learning (4 functions):**
- Set-Pattern: Valid/invalid regex, categories
- Get-Patterns: Filter by name, category
- Test-Pattern: Matching/non-matching samples
- Learn-OutputPattern: Auto-detection, interactive mode

**State (4 functions):**
- Save-Project: File creation, overwrite
- Load-Project: Restore patterns
- Get-BrickStore: Detailed view
- Clear-Stored: Partial/full clear

**Tasks:**
- Create test script: tests/agentbricks-functions.ps1
- Generate test data (sample build logs, test output)
- Run all functions with edge cases
- Document behavior and limitations

**Complexity:** Medium
**Priority:** High (validates major feature)

### 4. Import/Export Environment Workflows

**Goal:** Test conda/venv environment activation in dev_run and pwsh

**Test Scenarios:**
- Conda activate: dev_run with environment parameter
- Venv activate: Windows venv activation script
- Environment isolation: Different packages available in different envs
- Error handling: Non-existent environment names
- Cross-tool usage: pwsh + dev_run with same environment

**Tasks:**
- Create test conda environment
- Create test Python venv
- Write workflow scripts for common scenarios
- Document environment activation patterns
- Test with real Python projects

**Complexity:** Medium
**Priority:** Medium (important for Python development)

**Note:** Current dev_run implementation has `environment` parameter but needs testing.

### 5. Integration Test Suite

**Goal:** End-to-end scenario testing with real projects

**Test Scenarios:**

**Scenario 1: .NET Build Workflow**
- Clone sample .NET project
- Run: dev_run("dotnet build", "build")
- Verify: Error count, top errors extracted
- Analyze: Extract-Regex with MSBuild pattern
- Fix: Modify code to resolve one error
- Re-run: Verify error count decreased

**Scenario 2: JavaScript/TypeScript Project**
- Clone sample npm project
- Discover: Find-ProjectTools
- Test: dev_run("npm test", "test")
- Lint: dev_run("npm run lint", "lint")
- Analyze: Extract failures with ESLint pattern

**Scenario 3: Python Project**
- Clone sample Python project
- Test: dev_run("pytest tests/", "test")
- Analyze: Extract-Regex with Pytest-Fail pattern
- Coverage: Parse coverage report
- Group: Measure-Frequency on failure types

**Scenario 4: Learn New Tool**
- Custom script with structured output
- Learn: Learn-OutputPattern (interactive mode)
- Validate: Test-Pattern with sample
- Save: Save-Project to .brickyard.json
- Load: New session, Load-Project
- Use: Extract data with learned pattern

**Tasks:**
- Set up test project repositories
- Write test orchestration script
- Run scenarios, capture results
- Document expected vs actual behavior
- Create regression test suite

**Complexity:** High
**Priority:** Medium (validates real-world usage)

### 6. User Acceptance Scenarios

**Goal:** Validate against user workflows from POC-COMPLETE.md

**Scenarios:**

**UAT-1: Iterative Build Debugging**
1. Run build with errors
2. Get condensed summary
3. Deep dive into specific error code
4. Fix code
5. Re-run, verify error gone

**UAT-2: Multi-Tool Project**
1. Discover available tools (build, test, lint)
2. Run each tool with dev_run
3. Compare error counts across tools
4. Prioritize fixes based on frequency

**UAT-3: Pattern Learning**
1. Encounter new tool with custom output format
2. Use Learn-OutputPattern to teach AgentBricks
3. Extract structured data from output
4. Save pattern for future use

**UAT-4: Cross-Session Persistence**
1. Session 1: Set variables, run dev_run
2. Session 2: Access stored env vars
3. Session 3: Load saved .brickyard.json patterns

**Tasks:**
- Execute each scenario manually
- Document steps, screenshots, results
- Identify pain points and friction
- Gather feedback from users
- Iterate based on findings

**Complexity:** Low
**Priority:** Medium (user-focused validation)

## Longer-Term Goals

### 7. Wrapper Server Implementation

**Goal:** Create MCP wrapper servers that expose filtered subsets of downstream MCP servers

**Use Cases:**
- JetBrains MCP: Expose 8/21 tools (60% token reduction)
- Python REPL MCP: Filter to specific functions
- Custom routing: Route requests to appropriate backend

**Tasks:**
- Design wrapper protocol (MCP client + MCP server hybrid)
- Implement stdio relay with filtering
- Create configuration schema for tool filtering
- Test with real downstream servers
- Document wrapper pattern

**Reference:** mcp-filter achieved 91% reduction (50k → 1.9k tokens)

**Complexity:** High
**Priority:** Low (nice-to-have optimization)

### 8. Filter Server Implementation

**Goal:** Schema filtering and transformation for token optimization

**Features:**
- Remove verbose descriptions
- Simplify parameter schemas
- Collapse nested objects
- Compress tool metadata

**Tasks:**
- Analyze token breakdown of tool schemas
- Implement schema filtering logic
- Preserve functionality while reducing tokens
- Create filter configuration DSL
- Benchmark token savings

**Complexity:** High
**Priority:** Low (optimization, not core feature)

### 9. Multi-Project MCP Collection

**Goal:** Expand homebrew-mcp into curated MCP server collection

**Planned Servers:**
- PowerShell MCP (current)
- Wrapper servers (JetBrains, Python REPL)
- Filter servers (schema optimization)
- Project-specific integrations

**Tasks:**
- Establish project structure conventions
- Create server template/scaffold
- Document server development guidelines
- Set up CI/CD for server builds
- Publish to package registry (NuGet, npm)

**Complexity:** Medium
**Priority:** Low (organizational, not technical)

### 10. Stream Handling Enhancement

**Goal:** Full support for PowerShell's 6 output streams

**Streams:**
1. Success (stdout)
2. Error (stderr)
3. Warning
4. Verbose
5. Debug
6. Information

**Current State:** pwsh captures stdout, errors, warnings. dev_run captures stdout/stderr.

**Tasks:**
- Extend SessionManager to capture all streams
- Add stream filtering parameters
- Return structured stream data
- Integrate with AgentBricks patterns

**Complexity:** Medium
**Priority:** Low (enhancement, not requirement)

### 11. Chain Command (Saved Pipelines)

**Goal:** Save and replay complex analysis pipelines

**Feature:**
```powershell
Save-Chain -Name "analyze-build" -Pipeline {
    Find-Errors |
    Extract-Regex -Pattern (Get-Patterns -Name "MSBuild").Pattern |
    Group-By Code |
    Format-Count |
    Show -Top 10
}

# Later:
Invoke-Chain -Name "analyze-build" -Input $env:build_stderr
```

**Tasks:**
- Design chain storage format (ScriptBlock serialization)
- Implement Save-Chain, Load-Chain, Invoke-Chain
- Add to BrickStore state
- Test with real pipelines
- Document use cases

**Complexity:** Medium
**Priority:** Low (power user feature)

### 12. Compare Command (Baseline vs Current)

**Goal:** Compare two test/build runs to identify regressions

**Feature:**
```powershell
Compare-Output -Baseline $env:build1_stderr -Current $env:build2_stderr -Pattern "MSBuild"

# Returns:
# New Errors:      5 (2 unique)
# Fixed Errors:    8 (3 unique)
# Persistent:     42 (remaining)
```

**Tasks:**
- Implement diff logic for parsed outputs
- Group by error code/message
- Highlight regressions and fixes
- Format as actionable report

**Complexity:** Medium
**Priority:** Low (QA workflow enhancement)

### 13. Watch Command (Monitor Changes)

**Goal:** Continuously monitor command output for changes

**Feature:**
```powershell
Watch-Command -Command "npm test" -Interval 30s -Alert "error"
# Re-runs every 30s, alerts on error pattern match
```

**Tasks:**
- Implement interval scheduling
- Diff output between runs
- Alert on pattern changes
- Integration with dev_run

**Complexity:** Medium
**Priority:** Low (development workflow tool)

### 14. Pattern Library Sharing

**Goal:** Community-contributed pattern library

**Features:**
- Central repository of tool patterns
- Import patterns from URL/file
- Version control for patterns
- Validation and testing

**Tasks:**
- Design pattern package format
- Create pattern registry
- Implement Import-Patterns cmdlet
- Set up community contribution process

**Complexity:** High
**Priority:** Low (community feature)

## Testing Status Matrix

| Category | Status | Priority | Complexity |
|----------|--------|----------|------------|
| JEA Integration | Not Started | High | Medium |
| Common PowerShell Commands | Not Started | High | Low |
| AgentBricks Functions | Not Started | High | Medium |
| Import/Export Environments | Not Started | Medium | Medium |
| Integration Test Suite | Not Started | Medium | High |
| User Acceptance Scenarios | Not Started | Medium | Low |
| Wrapper Servers | Not Started | Low | High |
| Filter Servers | Not Started | Low | High |
| Multi-Project Collection | Not Started | Low | Medium |
| Stream Handling | Not Started | Low | Medium |
| Chain Command | Not Started | Low | Medium |
| Compare Command | Not Started | Low | Medium |
| Watch Command | Not Started | Low | Medium |
| Pattern Library | Not Started | Low | High |

## Next Actions

**Week 1:**
1. Create test scripts for common PowerShell commands
2. Create test scripts for AgentBricks functions
3. Run tests, document results

**Week 2:**
4. Test import/export environment workflows
5. Begin JEA integration research
6. Design JEA session configuration

**Week 3:**
7. Implement JEA constraints
8. Test with restricted runspace
9. Run integration test suite (Scenario 1: .NET)

**Week 4:**
10. Run integration test suite (Scenarios 2-4)
11. Execute user acceptance scenarios
12. Document findings, prioritize fixes

**After Week 4:** Iterate based on test results, then proceed to longer-term goals as needed.
