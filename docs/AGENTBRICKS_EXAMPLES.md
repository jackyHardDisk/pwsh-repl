# AgentBricks Usage Examples

Sophisticated workflows showing non-intuitive features and tool combinations.

## 1. Error Reporting with Fuzzy Grouping

**Problem:** Build produces hundreds of similar errors that are hard to summarize.

**Solution:** Use `Group-Similar` with Jaro-Winkler distance to cluster related errors.

```powershell
# Run build and capture output
dev_run 'npm run build' 'build'

# Group similar errors and count occurrences
Get-StreamData 'build' stderr |
    Find-Errors |
    Group-Similar -Threshold 0.85 |
    Format-Count

# Output: Top 5 error patterns with counts
# 15x: Cannot find module '@types/...'
#  8x: Property 'xyz' does not exist on type 'Foo'
#  3x: Argument of type 'string' is not assignable to ...
```

**Why this works:**
- `dev_run` stores all 6 PowerShell streams in JSON ($env:build_streams)
- `Get-StreamData` retrieves specific stream (stderr) from cache
- `Group-Similar` uses fuzzy matching to cluster "Cannot find module '@types/react'" and "Cannot find module '@types/node'"
- `Format-Count` aggregates and sorts by frequency

## 2. Cross-Tool Build Chain with Environments

**Problem:** Multi-stage build (lint → compile → test) across different tools, want single analysis.

**Solution:** Chain `dev_run` calls in named sessions with environment isolation.

```powershell
# Stage 1: Lint with Ruff (Python venv)
dev_run 'ruff check .' 'lint' -sessionId 'myproject' -environment 'C:\projects\myapp\venv'

# Stage 2: Build with MSBuild
dev_run 'dotnet build' 'build' -sessionId 'myproject'

# Stage 3: Test with Pytest (same venv)
dev_run 'pytest tests/' 'test' -sessionId 'myproject' -environment 'C:\projects\myapp\venv'

# Analyze all errors across stages
$allErrors = @()
$allErrors += Get-StreamData 'lint' stderr | Find-Errors
$allErrors += Get-StreamData 'build' stderr | Find-Errors
$allErrors += Get-StreamData 'test' stderr | Find-Errors

$allErrors | Group-By file | Format-Count
```

**Why this works:**
- Each `dev_run` stores output in separate $env variables (lint_streams, build_streams, test_streams)
- Same sessionId maintains variable persistence across calls
- Environment auto-detects venv (directory path) vs conda (name)
- All streams accessible via `Get-StreamData` for cross-stage analysis

## 3. Git Workflow Analysis

**Problem:** Review modified files and their conflict status before committing.

**Solution:** Parse Git output with pattern extraction and grouping.

```powershell
# Get modified files grouped by status
pwsh 'git status --short' -sessionId 'git' |
    Extract-Regex Git-Status |
    Group-By status

# Output:
# modified: 12 files
# new file: 3 files
# deleted: 1 file

# Check for conflict markers in modified files
$modified = pwsh 'git status --short' -sessionId 'git' |
    Extract-Regex Git-Status |
    Where-Object { $_.status -eq 'modified' }

foreach ($file in $modified) {
    $conflicts = Get-Content $file.file | Select-String '<<<<<<< HEAD'
    if ($conflicts) {
        Write-Host "Conflict in $($file.file): $($conflicts.Count) markers"
    }
}
```

**Why this works:**
- `pwsh` executes Git command and captures output
- `Extract-Regex` uses Git-Status pattern to parse status output
- Named groups (status, file) extracted into PSCustomObject properties
- Session persistence allows variable reuse across commands

## 4. Shared Sessions for Iterative Analysis

**Problem:** Incrementally analyze test results without re-running tests.

**Solution:** Use session persistence to build up analysis state.

```powershell
# Session 1: Run tests and store results
dev_run 'pytest tests/ -v' 'test' -sessionId 'analysis'

# Session 2: Get error summary (variables still available)
pwsh '$errors = Get-StreamData "test" stderr | Find-Errors; $errors.Count' -sessionId 'analysis'
# Output: 42

# Session 3: Group by file (still in same session)
pwsh '$errors | Group-By file | Format-Count' -sessionId 'analysis'

# Session 4: Focus on specific file
pwsh '$errors | Where-Object { $_.file -like "*auth*" } | Show' -sessionId 'analysis'
```

**Why this works:**
- All `pwsh` calls share sessionId='analysis'
- Variables ($errors, $test) persist across calls
- `dev_run` output stored in $env:test_streams (survives session)
- Iterative refinement without re-running expensive operations

## 5. Background Execution with Monitoring

**Problem:** Long build (5+ minutes) blocks terminal, want to monitor progress.

**Solution:** Run build in background, poll streams for updates.

```powershell
# Start long build in background (needs Task tool with run_in_background=true)
# This example shows the pattern, actual background requires Task tool

dev_run 'dotnet build /m:1 /v:detailed' 'longbuild'

# In separate session, monitor progress
while ($true) {
    $stats = pwsh 'Get-DevRunCacheStats' -sessionId 'monitor'
    Write-Host "Cached runs: $($stats.TotalRuns), Latest: $(Get-Date)"

    $errors = Get-StreamData 'longbuild' stderr | Find-Errors
    if ($errors.Count -gt 0) {
        Write-Host "Errors detected: $($errors.Count)"
        $errors | Format-Count | Select-Object -First 5
    }

    Start-Sleep -Seconds 10
}
```

**Why this works:**
- `dev_run` stores streams in $env immediately (accessible even during execution)
- `Get-DevRunCacheStats` shows all cached runs
- Polling loop can run in separate PowerShell session
- `Get-StreamData` retrieves partial results as build progresses

## 6. Sophisticated Output Formatting

**Problem:** Want detailed error report with file locations, grouped by severity.

**Solution:** Multi-stage pipeline with pattern parsing, grouping, and custom formatting.

```powershell
# Run TypeScript compiler
dev_run 'tsc --noEmit' 'tsc'

# Extract errors with pattern
$errors = Get-StreamData 'tsc' stderr |
    Extract-Regex TypeScript |
    Select-Object file, line, col, code, message

# Group by severity (TS#### code)
$grouped = $errors | Group-Object { $_.code.Substring(0,4) }

# Format output
foreach ($group in $grouped | Sort-Object Name) {
    Write-Host "`n$($group.Name): $($group.Count) errors" -ForegroundColor Red
    $group.Group |
        Group-By file |
        Format-Count |
        Select-Object -First 5 |
        ForEach-Object { Write-Host "  $($_.Count)x $($_.Value)" }
}
```

**Why this works:**
- `Extract-Regex` uses TypeScript pattern with named groups
- PowerShell Select-Object pulls named group values into properties
- Group-Object for aggregation, nested grouping for file-level stats
- `Format-Count` simplifies frequency analysis

## 7. Multi-Tool Docker Build Chain

**Problem:** Docker build with multi-stage Dockerfile, need to track errors across stages.

**Solution:** Parse Docker output, track stage-specific errors.

```powershell
# Run Docker build
dev_run 'docker build --no-cache -t myapp .' 'docker'

# Parse errors by stage
Get-StreamData 'docker' stderr |
    Extract-Regex Docker |
    Group-By stage |
    ForEach-Object {
        $stage = $_.Name
        $count = $_.Group.Count
        Write-Host "`nStage: $stage ($count errors)"
        $_.Group | Select-Object -First 3 | Show
    }

# Check for common Docker issues
$output = Get-StreamData 'docker' stdout
if ($output -match 'COPY failed') {
    Write-Host "File copy issue detected" -ForegroundColor Yellow
}
if ($output -match 'No space left') {
    Write-Host "Disk space issue" -ForegroundColor Red
}
```

**Why this works:**
- Docker pattern extracts stage name from `ERROR [stage X/Y]` format
- `Group-By stage` separates errors by build stage
- Both stdout and stderr accessible via `Get-StreamData`
- Pattern matching on raw output for common issues

## 8. Environment Tee for Capture-and-Pass-Through

**Problem:** Want to capture build output AND pass through to console in real-time.

**Solution:** Use `Set-EnvironmentTee` to store variables while displaying output.

```powershell
# Enable tee mode for 'result' variable
Set-EnvironmentTee -Names 'result'

# Run command - output displays AND stores in $env:result
pwsh 'npm run test 2>&1 | Tee-Object -Variable result'

# Later analysis without re-running
$env:result | Find-Errors | Measure-Frequency
```

**Why this works:**
- `Set-EnvironmentTee` marks variable for dual behavior
- Console output flows through in real-time
- $env:result persists for later analysis
- Session-scoped, doesn't pollute global environment

## Key Patterns

**Pattern 1: dev_run + Get-StreamData**
- Run tool with `dev_run` (stores all 6 streams)
- Retrieve specific stream with `Get-StreamData`
- Analyze with Find-Errors, Group-Similar, etc.

**Pattern 2: pwsh + sessionId**
- Use same sessionId for variable persistence
- Build up analysis state incrementally
- Avoid re-running expensive operations

**Pattern 3: Extract-Regex + Group-By**
- Parse tool output with pre-configured patterns
- Group by named group fields (file, severity, code)
- Aggregate with Format-Count or Measure-Frequency

**Pattern 4: Environment isolation**
- Pass -environment to dev_run for venv/conda activation
- Auto-detects path (venv) vs name (conda)
- Keeps dependencies isolated per tool

**Pattern 5: Multi-stage analysis**
- Store results in variables ($errors, $warnings)
- Combine across tools/stages
- Cross-reference by file, line, code
