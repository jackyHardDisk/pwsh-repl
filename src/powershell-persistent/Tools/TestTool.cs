using System.ComponentModel;
using ModelContextProtocol.Server;

namespace PowerShellMcpServer.Tools;

[McpServerToolType]
public class TestTool
{
    [McpServerTool]
    [Description("Simple test tool that returns a greeting")]
    public string Test([Description("Name to greet")] string name = "World")
    {
        return $"Hello, {name}!";
    }
}
