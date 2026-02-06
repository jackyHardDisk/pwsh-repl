// Copyright (c) 2025 jackyHardDisk. Licensed under the MIT License.

namespace PowerShellMcpServer.pwsh_repl.Tools;

public static class ToolDescriptions
{
    public const string PwshToolDescription = @"Execute PowerShell with persistent sessions. Variables and state persist across calls within the same sessionId.

**Modules auto-loaded:** AgentBlocks + PWSH_MCP_MODULES (e.g., LoraxMod)
**Discovery:** pwsh_mcp://modules resource, Get-Command -Module AgentBlocks, Get-Help <function> -Full

**Mode callback:** mode='Invoke-DevRun' + script='...' + kwargs={...}
**Auto-caching:** Results in $global:DevRunCache (pwsh_1, pwsh_2, ...)
**Background:** runInBackground=true, then stdio tool to interact
**Note:** Start-Job unsupported in hosted PowerShell. Use runInBackground or Start-ThreadJob instead.
";
}
