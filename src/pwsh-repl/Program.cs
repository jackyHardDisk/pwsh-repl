using System;
using System.Runtime.InteropServices;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using PowerShellMcpServer.pwsh_repl.Core;
using PowerShellMcpServer.pwsh_repl.Resources;

// Note: stdin pipe configuration is handled in SessionManager.cs for each runspace

// Create minimal host builder
var builder = Host.CreateEmptyApplicationBuilder(null);

// Register SessionManager as singleton (shared across all tool calls)
builder.Services.AddSingleton<SessionManager>();

// Register resource provider
builder.Services.AddSingleton<ResourceProvider>();

// Configure MCP server with stdio transport
builder.Services
    .AddMcpServer()
    .WithStdioServerTransport()
    .WithToolsFromAssembly()
    .WithResourcesFromAssembly();

// Run the server
await builder.Build().RunAsync();

// Windows API imports - must be after top-level statements
namespace PowerShellMcpServer.pwsh_repl
{
    using System;
    using System.Runtime.InteropServices;

    internal static class NativeMethods
    {
        public const int STD_INPUT_HANDLE = -10;
        public const int HANDLE_FLAG_INHERIT = 0x00000001;
        public static readonly IntPtr INVALID_HANDLE_VALUE = new(-1);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetStdHandle(int nStdHandle);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr hObject);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetStdHandle(int nStdHandle, IntPtr hHandle);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetHandleInformation(IntPtr hObject, int dwMask,
            int dwFlags);
    }
}