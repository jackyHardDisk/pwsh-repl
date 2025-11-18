using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using ModelContextProtocol.Server;
using PowerShellMcpServer.Core;
using System.Runtime.InteropServices;

// Make stdin handle non-inheritable to prevent child processes from inheriting it
// This ensures Python, Node, and other external processes don't hang waiting for input
try
{
    if (OperatingSystem.IsWindows())
    {
        // Get current stdin handle
        var stdinHandle = NativeMethods.GetStdHandle(NativeMethods.STD_INPUT_HANDLE);

        if (stdinHandle != IntPtr.Zero && stdinHandle != NativeMethods.INVALID_HANDLE_VALUE)
        {
            // Clear the HANDLE_FLAG_INHERIT flag so child processes don't inherit stdin
            if (NativeMethods.SetHandleInformation(stdinHandle, NativeMethods.HANDLE_FLAG_INHERIT, 0))
            {
                Console.Error.WriteLine("MCP Server: Made stdin non-inheritable for child processes");
            }
            else
            {
                Console.Error.WriteLine("MCP Server: Warning - failed to make stdin non-inheritable");
            }
        }
    }
}
catch (Exception ex)
{
    Console.Error.WriteLine($"MCP Server: Note - stdin configuration failed: {ex.Message}");
}

// Create minimal host builder
var builder = Host.CreateEmptyApplicationBuilder(settings: null);

// Register SessionManager as singleton (shared across all tool calls)
builder.Services.AddSingleton<SessionManager>();

// Configure MCP server with stdio transport
builder.Services
    .AddMcpServer()
    .WithStdioServerTransport()
    .WithToolsFromAssembly();

// Run the server
await builder.Build().RunAsync();

// Windows API imports - must be after top-level statements
static partial class NativeMethods
{
    public const int STD_INPUT_HANDLE = -10;
    public const int HANDLE_FLAG_INHERIT = 0x00000001;
    public static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetStdHandle(int nStdHandle, IntPtr hHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetHandleInformation(IntPtr hObject, int dwMask, int dwFlags);
}
