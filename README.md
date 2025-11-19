# PowerShell Persistent MCP Server

Model Context Protocol (MCP) server providing persistent PowerShell execution for Claude Code with auto-loading AgentBricks module.

**Status:** Implementation Complete | Testing In Progress

## Features

**Persistent Sessions**
- Named PowerShell sessions with variable persistence
- Session state survives across tool calls
- Multiple independent sessions per MCP server instance

**3 MCP Tools**
- `test` - Simple connectivity test
- `pwsh` - Execute PowerShell with session persistence
- `dev_run` - Iterative development workflow with output capture and summarization

**AgentBricks Module**
- 20 PowerShell functions (Transform, Extract, Analyze, Present, Meta-Learning, State)
- 40+ pre-configured patterns for common tools (JavaScript, Python, .NET, Build)
- Auto-loads on session creation
- Token-efficient (0 tokens upfront, discovered via Get-Help)

**Token Efficiency**
- Tool schemas: ~1,400 tokens (3 tools only)
- AgentBricks functions: 0 tokens upfront (discovered on-demand)
- dev_run summaries: 99% reduction vs raw output

## Quick Start

### Build

```bash
dotnet build
```

Output: `bin/Debug/net8.0-windows/win-x64/PowerShellMcpServer.exe`

### Configure

Add to `.mcp.json` (project-level) or `~/.claude/settings.json` (user-level):

```json
{
  "mcpServers": {
    "powershell-persistent": {
      "command": "C:\\Users\\yourname\\source\\repos\\pwsh-repl\\bin\\Debug\\net8.0-windows\\win-x64\\PowerShellMcpServer.exe"
    }
  }
}
```

Adjust path to your build output directory.

### Test

```powershell
# In Claude Code, call the test tool
test("Claude")
# Returns: Hello, Claude!
```

## Tools Reference

### test - Simple Test

**Purpose:** Verify MCP connection

**Parameters:**
- `name` (optional, default: "World") - Name to greet

**Example:**
```powershell
test("Agent")
# Returns: Hello, Agent!
```

### pwsh - PowerShell Execution

**Purpose:** Execute PowerShell scripts with persistent state

**Parameters:**
- `script` (required) - PowerShell script to execute
- `sessionId` (optional, default: "default") - Session ID for state isolation

**Features:**
- Variables persist within session
- Automatic Out-String formatting for tables
- Returns stdout + errors + warnings

**Example:**
```powershell
# Set variable
pwsh("$myVar = 42", "session1")

# Retrieve variable (same session)
pwsh("$myVar", "session1")
# Returns: 42

# Different session (isolated)
pwsh("$myVar", "session2")
# Returns: (nothing - different session)

# Complex operations
pwsh("Get-Process | Where-Object { $_.CPU -gt 100 } | Select-Object -First 5", "default")
```

### dev_run - Iterative Development Wrapper

**Purpose:** Execute scripts with output capture, store in session variables, return condensed summaries

**Parameters:**
- `script` (required for first run, optional for re-run) - PowerShell script to execute
- `name` (optional) - Name for stored results (generates timestamp-based name if omitted)
- `sessionId` (optional, default: "default") - Session ID
- `environment` (optional) - Conda/venv environment to activate

**Stores:**
- `$env:{name}_stdout` - Standard output
- `$env:{name}_stderr` - Error output
- `$env:{name}` - Original script (re-run capability)
- `$env:{name}_timestamp` - Execution timestamp

**Returns:** Condensed summary with error/warning counts, top issues, output line count

**Example:**
```powershell
# Run build
dev_run("dotnet build", "build")

# Output:
# Script: dotnet build
# Exit Code: 1
#
# Errors:   12  (5 unique)
# Warnings:  3  (2 unique)
# Output:   247 lines
#
# Top Errors:
#     8x: CS0103: The name 'foo' does not exist in the current context
#     3x: CS0246: The type or namespace name 'Bar' could not be found
#     1x: CS1002: ; expected
#
# Top Warnings:
#     2x: CS0168: The variable 'unused' is declared but never used
#     1x: CS0649: Field is never assigned to
#
# Stored: $env:build_stdout, $env:build_stderr
# Re-run: dev-run(name="build")

# Analyze errors with AgentBricks
pwsh('$env:build_stderr | Find-Errors | Measure-Frequency | Format-Count')

# Re-run saved script
dev_run(name="build")
```

## AgentBricks Module

**Auto-loads on session creation.** Functions available immediately without import.

**Quick reference:**
```powershell
Get-BrickStore        # View loaded patterns and state
Find-ProjectTools     # Discover available build/test/lint tools
Get-Patterns          # List learned regex patterns
Get-Help <function>   # Full documentation for any function
```

**Function categories:**
- Transform: Format-Count, Group-By, Measure-Frequency
- Extract: Extract-Regex, Extract-Between, Extract-Column
- Analyze: Find-Errors, Find-Warnings, Parse-BuildOutput
- Present: Show, Export-ToFile
- Meta-Discovery: Find-ProjectTools
- Meta-Learning: Set-Pattern, Get-Patterns, Test-Pattern, Learn-OutputPattern
- State: Save-Project, Load-Project, Get-BrickStore, Clear-Stored

**Pre-configured patterns:** ESLint, TypeScript, Pytest, Mypy, MSBuild, NuGet, GCC, Clang, CMake, and 30+ more.

**Usage example:**
```powershell
# Run tests with dev_run
dev_run("pytest tests/", "test")

# Analyze failures with AgentBricks
pwsh('$env:test_stderr | Extract-Regex -Pattern (Get-Patterns -Name "Pytest-Fail").Pattern | Format-Count')

# Output:
#   8x: tests/test_app.py::test_login
#   3x: tests/test_api.py::test_auth
#   1x: tests/test_db.py::test_query
```

**Full documentation:** See [docs/AGENTBRICKS.md](docs/AGENTBRICKS.md)

## Documentation

**Technical Details:**
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Implementation details, build process, session management
- [AGENTBRICKS.md](docs/AGENTBRICKS.md) - Complete AgentBricks function reference with examples
- [DESIGN_DECISIONS.md](docs/DESIGN_DECISIONS.md) - Why key architectural choices were made

**Roadmap:**
- [TODO.md](docs/TODO.md) - Prioritized next steps and future enhancements

## Current Status

**Completed:**
- Core MCP server with stdio protocol
- 3 tools: test, pwsh, dev_run
- SessionManager with named sessions
- PowerShellPool with channel-based pattern
- AgentBricks module (20 functions, 40+ patterns)
- Auto-loading module on session creation
- Build targets for module copying

**Testing In Progress:**
- Manual testing with real projects
- Integration test suite
- User acceptance scenarios
- Common PowerShell command validation
- AgentBricks function validation

## Next Steps

**Immediate priorities** (from [docs/TODO.md](docs/TODO.md)):

1. **JEA Integration** - Just Enough Administration for security constraints
2. **Test Common PowerShell Commands** - Validation suite for pwsh tool
3. **Test AgentBricks Module** - All 20 functions with real inputs
4. **Import/Export Environment Workflows** - Conda/venv integration patterns
5. **Integration Test Suite** - End-to-end scenarios
6. **User Acceptance Scenarios** - Real-world workflows

**Longer-term goals:**
- Wrapper servers (token optimization for downstream MCP servers)
- Filter servers (schema filtering, demonstrated in mcp-filter project)
- Multi-project MCP server collection

## Architecture Highlights

**Channel-Based Pool Pattern:**
- Async-friendly (no locks)
- Based on PowerAuger's BackgroundProcessor
- 5 PowerShell instances, unbound channel

**Named Session Management:**
- ConcurrentDictionary for thread-safe access
- Each session has dedicated Runspace
- Variables persist across calls within session

**Token Efficiency Strategy:**
- Module functions NOT in MCP tool schemas
- Agents discover via `Get-Command -Module AgentBricks`
- Full help via `Get-Help <function> -Full`
- 90% token reduction vs exposing 20+ tools

**Hybrid v1+v2+v3 Pattern:**
- v1: Concrete functions (immediate utility)
- v2: Pre-configured patterns (common tools)
- v3: Meta-learning (teach new tools)

See [docs/DESIGN_DECISIONS.md](docs/DESIGN_DECISIONS.md) for detailed rationale.

## Example Workflows

### Workflow 1: Build Error Analysis

```powershell
# Run build with capture
dev_run("dotnet build", "build")

# Summary shows top errors:
#   8x: CS0103: The name 'foo' does not exist

# Deep dive with AgentBricks
pwsh(@'
$env:build_stderr |
    Extract-Regex -Pattern (Get-Patterns -Name "MSBuild").Pattern |
    Where-Object { $_.Code -eq "CS0103" }
'@)

# Shows all CS0103 occurrences with file/line info
```

### Workflow 2: Test Suite Analysis

```powershell
# Discover test command
pwsh("Find-ProjectTools")
# Output: JavaScript | npm | npm run test | test

# Run tests
dev_run("npm run test", "test")

# Extract failures
pwsh('$env:test_stderr | Extract-Regex -Pattern (Get-Patterns -Name "Jest").Pattern | Format-Count')
```

### Workflow 3: Learn Custom Tool

```powershell
# Learn new tool interactively
pwsh("Learn-OutputPattern -Name 'myapp-lint' -Command 'myapp lint src/' -Interactive")

# Agent sees detected patterns, chooses one
# Pattern registered and ready

# Use learned pattern
pwsh('$env:lint_output | Extract-Regex -Pattern (Get-Patterns -Name "myapp-lint").Pattern')

# Save for future sessions
pwsh("Save-Project -Path '.brickyard.json'")
```

## Requirements

- .NET 8.0 SDK
- Windows x64 (PowerShell SDK dependency)
- Claude Code with MCP support

## Building from Source

```bash
git clone <repository-url>
cd pwsh-repl
dotnet restore
dotnet build
```

Build output includes:
- PowerShellMcpServer.exe
- PowerShell SDK runtime libraries (auto-copied)
- AgentBricks module (auto-copied to Modules/)

## Contributing

This is a custom MCP server for personal/organizational use. Contributions welcome for:
- Additional AgentBricks patterns
- Performance optimizations
- Bug fixes
- Documentation improvements

## License

MIT License - See LICENSE file for details

## References

- [MCP Protocol Specification](https://spec.modelcontextprotocol.io/)
- [Claude Code MCP Documentation](https://docs.claude.com/en/docs/claude-code/mcp)
- [MCP Server Examples](https://github.com/modelcontextprotocol/servers)
- [PowerShell SDK Documentation](https://learn.microsoft.com/en-us/powershell/scripting/developer/hosting/windows-powershell-host-quickstart)
