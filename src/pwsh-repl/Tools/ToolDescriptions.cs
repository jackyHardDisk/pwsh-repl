// Copyright (c) 2025 jackyHardDisk. Licensed under the MIT License.

namespace PowerShellMcpServer.pwsh_repl.Tools;

public static class ToolDescriptions
{
    public const string PwshToolDescription = @"Execute PowerShell with persistent sessions. Variables and state persist across calls within the same sessionId.

**Modules auto-loaded:** Base, AgentBlocks + PWSH_MCP_MODULES (e.g., LoraxMod)
**Check loaded modules:** Use pwsh_mcp://modules resource

**Mode callback pattern:** Use mode parameter to call module functions directly:
  mode='Invoke-DevRun' + script='dotnet build' + kwargs={Streams: ['Error']}

**Auto-caching:** All executions cached in $global:DevRunCache with auto-generated names (pwsh_1, pwsh_2, ...)

**Python scripts:** Use here-string + pipe to avoid escaping issues:
  $code = @'
  print(f""Any 'quotes' and {braces} work"")
  '@
  $code | python -

**Background processes:** Use runInBackground=true, then stdio tool to interact:
  pwsh(script='python server.py', runInBackground=true, name='server')
  stdio(name='server')  # read output
  stdio(name='server', data='quit\n')  # write to stdin
  stdio(name='server', stop=true)  # stop and cache output

## Quick Reference

**AgentBlocks** - Pattern learning (49 pre-configured patterns)
  Get-Patterns [-Name] [-Category]
  Set-Pattern -Name -Pattern -Description [-Category]
  Test-Pattern -Name [-Sample] [-ShowMatches]
  (+38 more: Get-Command -Module AgentBlocks)

Use Get-Help <function> -Full for detailed documentation.
";
}
