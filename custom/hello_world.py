import sys
from claude_agent.tools.tool_protocol import run_stdio_server, tool
from claude_agent.tools.tool_protocol import Tool, ToolError, ToolParam

@tool("A simple tool that returns a greeting.",
      params=[])
def hello() -> str:
    """
    Returns a friendly greeting.
    """
    return "Hello, world!"

if __name__ == "__main__":
    run_stdio_server([hello])
