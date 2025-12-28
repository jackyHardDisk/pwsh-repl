# PowerShell Persistent MCP Server

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![.NET 8.0](https://img.shields.io/badge/.NET-8.0-blue.svg)](https://dotnet.microsoft.com/)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows)

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

**LoraxMod Module (Bundled)**

- Tree-sitter AST parsing for 28 languages
- 10 cmdlets: `ConvertTo-LoraxAST`, `Compare-LoraxAST`, `Find-LoraxFunction`, etc.
- Semantic diff, function extraction, dependency analysis
- Native C# via [TreeSitter.DotNet](https://www.nuget.org/packages/TreeSitter.DotNet)
- Source: [jackyHardDisk/loraxMod](https://github.com/jackyHardDisk/loraxMod)

**Token Efficiency**

- Tool schemas: ~1,400 tokens (3 tools)
- Base module functions: 0 tokens upfront (discovered on-demand)
- AgentBlocks functions: 0 tokens upfront (discovered on-demand)
- Invoke-DevRun: Summarized output vs verbose raw streams

## Installation

### Option 1: Download Release

Download the latest `pwsh-repl-vX.X.X-win-x64.zip` from [GitHub Releases](https://github.com/jackyHardDisk/pwsh-repl/releases).

### Option 2: Build from Source

```bash
git clone https://github.com/jackyHardDisk/pwsh-repl.git
cd pwsh-repl
dotnet build
```

Output: `release/v0.1.0/PowerShellMcpServer.exe`

## Configuration

Copy `.mcp.json.example` to `.mcp.json` and update paths, or add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "pwsh-repl": {
      "type": "stdio",
      "command": "C:\\path\\to\\PowerShellMcpServer.exe",
      "args": [],
      "cwd": ".",
      "env": {
        "PWSH_MCP_TIMEOUT_DEFAULT": "60"
      }
    }
  }
}
```

**Important:** The `"cwd": "."` field sets the server's working directory to the project root.
This ensures PowerShell scripts using relative paths (like `.gary/scripts/`) resolve correctly.
Each project's `.mcp.json` should include this field.

**Loading External Modules:**

To load additional PowerShell modules (like LoraxMod), add `PWSH_MCP_MODULES` to the `env` section:

```json
{
  "mcpServers": {
    "pwsh-repl": {
      "env": {
        "PWSH_MCP_MODULES": "C:\\path\\to\\module1.psd1;C:\\path\\to\\module2.psd1"
      }
    }
  }
}
```

Notes:
- Use absolute paths (required for MCP server context)
- Multiple modules: semicolon-delimited
- Modules auto-load on session creation
- Built-in modules (AgentBlocks, LoraxMod) load automatically

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

**Timeout Behavior:**

When a script exceeds `timeoutSeconds`, the server:
1. Stops the PowerShell pipeline
2. Takes a snapshot of child processes spawned during execution
3. Kills all new child processes (and their descendants) using Win32 APIs
4. Returns an error message with the count of killed processes

This prevents orphaned processes from consuming resources (GPU memory, database connections, etc.).

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

**Running Python Scripts - Here-String Pattern:**

PowerShell parses `{braces}` as scriptblocks. Python f-strings like `{var.attr}` will cause errors.

```powershell
# BAD - fails with "ScriptBlock should only be specified..."
python -c "print(f'{arr.shape}')"

# GOOD - here-string preserves braces literally
$code = @'
import numpy as np
arr = np.array([1,2,3])
print(f"Shape: {arr.shape}")
'@
$code | python -
```

> **Tip:** Add this pattern to your project or user `CLAUDE.md` to ensure Claude uses it automatically.

### stdio - Background Process & Stdin Control

**Purpose:** Interact with C#-managed background processes or session stdin pipes

**Parameters:**

- `name` (optional) - Background process name (interacts with that process if provided)
- `data` (optional) - String to write to stdin
- `close` (optional, default: false) - Close stdin to signal EOF
- `stop` (optional, default: false) - Stop process tree and cache output for Get-BackgroundData
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

# Stop process and cache output (kills entire process tree via taskkill /T /F)
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

**Full documentation:** See [docs/AGENTBLOCKS.md](docs/AGENTBLOCKS.md)

## Documentation

- [AGENTBLOCKS.md](docs/AGENTBLOCKS.md) - Complete AgentBlocks function reference
- [AGENTBLOCKS_EXAMPLES.md](docs/AGENTBLOCKS_EXAMPLES.md) - Usage examples and workflows

## Current Status

**Completed:**

- Core MCP server with stdio protocol
- 3 tools: pwsh (with mode callback), stdin, list_sessions
- SessionManager with named sessions and stdin pipe architecture
- Base module (39 functions), AgentBlocks (5 functions + 43 patterns)
- SessionLog module (external via PWSH_MCP_MODULES)
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

### Workflow 4: Interactive SSH Session

Use `runInBackground` + `stdio` for interactive remote sessions. This pattern enables
sending multiple commands to a persistent SSH connection without blocking.

```python
# Step 1: Start SSH in background
mcp__pwsh-repl__pwsh(
    script='ssh user@remote-server',
    runInBackground=True,
    name='remote',
    sessionId='ssh'
)
# Returns: Background process 'remote' started (PID 12345, running)

# Step 2: Read initial output (may show PTY warning - normal)
mcp__pwsh-repl__stdio(name='remote', sessionId='ssh')
# Returns:
# === stderr ===
# Pseudo-terminal will not be allocated because stdin is not a terminal.

# Step 3: Send a command (include newline!)
mcp__pwsh-repl__stdio(
    name='remote',
    data='cat ~/bin/my-script\n',
    sessionId='ssh'
)
# Returns: Wrote 21 chars to 'remote' stdin
# === stdout ===
# #!/bin/bash
# ... file contents ...

# Step 4: Create/edit remote files using heredoc
mcp__pwsh-repl__stdio(
    name='remote',
    data='''mkdir -p ~/.config/systemd/user && cat > ~/.config/systemd/user/my-service.service << 'EOF'
[Unit]
Description=My TCP Service
After=network.target

[Service]
Type=simple
ExecStart=/home/user/bin/my-server --host localhost --port 18812
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
echo "Service file created"
''',
    sessionId='ssh'
)

# Step 5: Enable and start the service
mcp__pwsh-repl__stdio(
    name='remote',
    data='systemctl --user daemon-reload && systemctl --user enable my-service && systemctl --user start my-service && systemctl --user status my-service\n',
    sessionId='ssh'
)

# Step 6: Read output
mcp__pwsh-repl__stdio(name='remote', sessionId='ssh')
# Returns:
# === stdout ===
# Service file created
# Created symlink...
# * my-service.service - My TCP Service
#      Active: active (running)...

# Step 7: Verify port is listening
mcp__pwsh-repl__stdio(
    name='remote',
    data='ss -tlnp | grep 18812\n',
    sessionId='ssh'
)

# Step 8: Close SSH when done
mcp__pwsh-repl__stdio(name='remote', data='exit\n', sessionId='ssh')
mcp__pwsh-repl__stdio(name='remote', stop=True, sessionId='ssh')
# Returns: Stopped background process 'remote' (output cached)
```

**Parameter Reference:**

| Parameter | Purpose |
|-----------|---------|
| `runInBackground=True` | Start process, return immediately |
| `name='remote'` | Name for later reference via stdio |
| `sessionId='ssh'` | Group related operations |
| `data='cmd\n'` | Send to stdin (include newline!) |
| `stop=True` | Terminate process, cache output |
| `close=True` | Close stdin pipe (signal EOF) |
| `readOutput=False` | Check status without reading |

**Limitations:**

- No PTY (pseudo-terminal) - some programs behave differently
- `sudo` requires `-S` flag or NOPASSWD config
- Interactive editors (vim, less) won't work
- Best for scripted remote operations

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

## Contributing

This is a custom MCP server for personal/organizational use. Contributions welcome for:

- Additional AgentBlocks patterns
- Performance optimizations
- Bug fixes
- Documentation improvements

## Security Considerations

This is a local PowerShell execution environment for agentic coding. By design, it executes commands you or your AI assistant provide.

- **Audit logging** (opt-in via `PWSH_MCP_AUDIT_LOG`): Logs contain full script content. Avoid enabling in shared environments if scripts may contain credentials.
- **Background processes**: Command arguments may appear in stderr logs.
- **Module loading** (`PWSH_MCP_MODULES`): Only loads modules from paths you explicitly configure.

## License

MIT License - See [LICENSE](LICENSE) file for details.

## References

- [MCP Protocol Specification](https://spec.modelcontextprotocol.io/)
- [Claude Code MCP Documentation](https://docs.claude.com/en/docs/claude-code/mcp)
- [MCP Server Examples](https://github.com/modelcontextprotocol/servers)
- [PowerShell SDK Documentation](https://learn.microsoft.com/en-us/powershell/scripting/developer/hosting/windows-powershell-host-quickstart)
