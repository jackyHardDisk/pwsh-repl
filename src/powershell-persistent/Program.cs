using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using ModelContextProtocol.Server;
using PowerShellMcpServer.Core;

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
