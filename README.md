# PowerShell Persistent MCP Server

Model Context Protocol (MCP) server providing persistent PowerShell execution for Claude
Code with auto-loading AgentBlocks module.

**Status:** Production Ready

## Features

**Persistent Sessions**

- Named PowerShell sessions with variable persistence
- Session state survives across tool calls
- Multiple independent sessions per MCP server instance

**3 MCP Tools**

- `stdio` - Interact with background processes or session stdin
- `pwsh` - Execute PowerShell with session persistence and mode callbacks
- `list_sessions` - List active PowerShell session IDs

**AgentBlocks Module**

- 5 PowerShell functions for pattern learning and meta-discovery
- 43 pre-configured patterns for common tools (JavaScript, Python, .NET, Build)
- Auto-loads on session creation
- Token-efficient (0 tokens upfront, discovered via Get-Help)

**SessionLog Module**

- Session tracking with JSONL format and 4AM day boundary
- Todo management (Add-Todo, Update-TodoStatus)
- Session history (Show-Session, Read-SessionLog)

**TokenCounter Module**

- Accurate Claude token counting using tiktoken
- Measure-Tokens function for text/file analysis

**LoraxMod Module**

- Tree-sitter AST parsing and analysis via PowerShell
- 8 functions (Interactive REPL, Query, Find, Navigate, Export)
- 12 supported languages (C, C++, C#, Python, JavaScript, TypeScript, Bash, PowerShell, R, Rust, CSS, Fortran)
- Requires Node.js (optional peer dependency)
- Bundled with tree-sitter grammars

**Token Efficiency**

- Tool schemas: ~1,400 tokens (3 tools)
- Base module functions: 0 tokens upfront (discovered on-demand)
- AgentBlocks functions: 0 tokens upfront (discovered on-demand)
- LoraxMod functions: 0 tokens upfront (discovered on-demand)
- Invoke-DevRun: Summarized output vs verbose raw streams

## Quick Start

### Build

```bash
dotnet build
```

Output: `release/v0.1.0/PowerShellMcpServer.exe`

### Configure

Copy `.mcp.json.example` to `.mcp.json` and update paths, or add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "pwsh-repl": {
      "type": "stdio",
      "command": "C:\\path\\to\\PowerShellMcpServer.exe",
      "env": {
        "PWSH_MCP_TIMEOUT_DEFAULT": "60"
      }
    }
  }
}
```

### Test

```powershell
# Import AgentBlocks module to verify setup
Import-Module C:\Path\To\pwsh-repl\src\pwsh-repl\Modules\AgentBlocks\AgentBlocks.psd1
Get-Command -Module AgentBlocks | Measure-Object
# Should show 41 functions
```

## Tools Reference

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

### stdio - Background Process & Stdin Control

**Purpose:** Interact with C#-managed background processes or session stdin pipes

**Parameters:**

- `name` (optional) - Background process name (interacts with that process if provided)
- `data` (optional) - String to write to stdin
- `close` (optional, default: false) - Close stdin to signal EOF
- `stop` (optional, default: false) - Stop process and cache output for Get-BackgroundData
- `readOutput` (optional, default: true) - Read and return stdout/stderr
- `sessionId` (optional, default: "default") - Target session

**Example:**

```python
# Start background process
mcp__pwsh-repl__pwsh(script='python server.py', runInBackground=True, name='srv', sessionId='dev')

# Read output from background process
mcp__pwsh-repl__stdio(name='srv', sessionId='dev')

# Write to background process stdin
mcp__pwsh-repl__stdio(name='srv', data='command\n', sessionId='dev')

# Stop process and cache output
mcp__pwsh-repl__stdio(name='srv', stop=True, sessionId='dev')

# Legacy: Write to session stdin pipe (no name)
mcp__pwsh-repl__stdio(data='line1\nline2\n', sessionId='repl')
```

### list_sessions - List Active Sessions

**Purpose:** Show all active PowerShell session IDs

**Parameters:** None

**Example:**

```python
mcp__pwsh-repl__list_sessions()
# Returns: ['default', 'gary_pwsh_repl', 'build_session']
```

## AgentBlocks Module

**Auto-loads on session creation.** Functions available immediately without import.

**Quick reference:**

```powershell
Get-BrickStore        # View loaded patterns and state
Find-ProjectTools     # Discover available build/test/lint tools
Get-Patterns          # List learned regex patterns
Get-Help <function>   # Full documentation for any function
```

**Functions:**

- Get-Patterns, Set-Pattern, Test-Pattern - Pattern management
- Register-OutputPattern - Learn patterns from tool output
- Find-ProjectTools - Discover available build/test/lint tools

**Pre-configured patterns:** ESLint, TypeScript, Pytest, Mypy, MSBuild, NuGet, GCC,
Clang, CMake, and 30+ more.

**Usage example:**

```powershell
# Run tests with Invoke-DevRun (via pwsh mode callback)
mcp__pwsh-repl__pwsh(
    mode='Invoke-DevRun',
    script='pytest tests/',
    name='test',
    kwargs={'Streams': ['Error', 'Warning']}
)

# Analyze failures with AgentBlocks
mcp__pwsh-repl__pwsh(script='Get-StreamData test Error | Select-RegexMatch -Pattern (Get-Patterns -Name "Pytest-Fail").Pattern | Format-Count')

# Output:
#   8x: tests/test_app.py::test_login
#   3x: tests/test_api.py::test_auth
#   1x: tests/test_db.py::test_query
```

**Full documentation:** See [docs/AgentBlocks.md](docs/AgentBlocks.md)

## Documentation

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Implementation details, build process, session management
- [AgentBlocks.md](docs/AgentBlocks.md) - Complete AgentBlocks function reference with examples
- [DESIGN_DECISIONS.md](docs/DESIGN_DECISIONS.md) - Why key architectural choices were made

## Current Status

**Completed:**

- Core MCP server with stdio protocol
- 3 tools: pwsh (with mode callback), stdin, list_sessions
- SessionManager with named sessions and stdin pipe architecture
- Base module (39 functions), AgentBlocks (5 functions + 43 patterns)
- LoraxMod (tree-sitter AST parsing), SessionLog, TokenCounter modules
- Auto-loading modules on session creation
- Build-time Quick Reference generation in tool description
- Environment activation (conda/venv) support

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
- Agents discover via `Get-Command -Module AgentBlocks`
- Full help via `Get-Help <function> -Full`
- Functions hidden in modules, not exposed as individual MCP tools

**Hybrid v1+v2+v3 Pattern:**

- v1: Concrete functions (immediate utility)
- v2: Pre-configured patterns (common tools)
- v3: Meta-learning (teach new tools)

See [docs/DESIGN_DECISIONS.md](docs/DESIGN_DECISIONS.md) for detailed rationale.

## Example Workflows

### Workflow 1: Build Error Analysis

```powershell
# Run build with Invoke-DevRun (mode callback)
mcp__pwsh-repl__pwsh(
    mode='Invoke-DevRun',
    script='dotnet build',
    name='build',
    kwargs={'Streams': ['Error', 'Warning']}
)

# Summary shows top errors:
#   8x: CS0103: The name 'foo' does not exist

# Deep dive with AgentBlocks
mcp__pwsh-repl__pwsh(script='''
Get-StreamData build Error |
    Select-RegexMatch -Pattern (Get-Patterns -Name "MSBuild").Pattern |
    Where-Object { $_.Code -eq "CS0103" }
''')

# Shows all CS0103 occurrences with file/line info
```

### Workflow 2: Test Suite Analysis

```powershell
# Discover test command
mcp__pwsh-repl__pwsh(script='Find-ProjectTools')
# Output: JavaScript | npm | npm run test | test

# Run tests with Invoke-DevRun
mcp__pwsh-repl__pwsh(
    mode='Invoke-DevRun',
    script='npm run test',
    name='test'
)

# Extract failures
mcp__pwsh-repl__pwsh(script='Get-StreamData test Error | Select-RegexMatch -Pattern (Get-Patterns -Name "Jest").Pattern | Format-Count')
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

## Security

**Execution Model:** The MCP server runs with your user privileges - same as any terminal.

**Audit Logging:** Enable command logging via environment variable:

```json
{
  "env": {
    "PWSH_MCP_AUDIT_LOG": "C:\\logs\\pwsh-mcp-audit.log"
  }
}
```

Log format:
```
[2024-01-15 14:32:01.123] EXECUTE session=default content="Get-Process | Select -First 5"
```

## Requirements

- .NET 8.0 SDK (for building only - not needed to run pre-built releases)
- Windows x64 (PowerShell SDK dependency)
- Claude Code with MCP support

## Building from Source

```bash
git clone https://github.com/jacksonhunter/PowerShell-REPL-MCP-Server.git
cd PowerShell-REPL-MCP-Server
dotnet restore
dotnet build
```

Build output: `release/v0.1.0/`
- PowerShellMcpServer.exe
- PowerShell SDK runtime libraries (auto-copied)
- All modules (AgentBlocks, LoraxMod, TokenCounter) auto-copied to Modules/

## Contributing

This is a custom MCP server for personal/organizational use. Contributions welcome for:

- Additional AgentBlocks patterns
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
