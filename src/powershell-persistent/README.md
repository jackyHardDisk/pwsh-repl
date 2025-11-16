# PowerShell Persistent MCP Server

Provides persistent PowerShell environment through MCP protocol - variables and state persist across tool calls.

## Architecture

**Pattern**: Channel-based pool (from PowerAuger `BackgroundProcessor.cs`)
- Pool of 4 PowerShell instances, each with persistent Runspace
- Thread-safe via `Channel<T>` (no locks)
- Async-native for MCP stdio protocol

## Key Components

### Core/PowerShellPool.cs
Channel-based object pool for PowerShell instances.

### Tools/PwshTool.cs
Execute PowerShell scripts with state persistence.

### Utils/StreamCollector.cs
Collect all 6 PowerShell streams (Output, Error, Warning, Verbose, Debug, Information).

## Critical Patterns from Research

### 1. Stream Clearing (prevents error accumulation)
```csharp
session.PowerShell.Commands.Clear();
session.PowerShell.Streams.ClearStreams();  // CRITICAL!
```

### 2. Channel Pattern (not locks)
```csharp
var pool = Channel.CreateUnbounded<PowerShellSession>();
var session = await pool.Reader.ReadAsync(ct);  // Async checkout
pool.Writer.TryWrite(session);  // Non-blocking checkin
```

### 3. Module Pre-loading
```csharp
ps.AddScript(@"
    Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue
    Import-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue
");
```

### 4. Output Formatting (prevent truncation)
```csharp
ps.AddCommand("Out-String");
ps.AddParameter("Width", 250);
```

## Dependencies

```xml
<PackageReference Include="System.Management.Automation" Version="7.4.0" />
<PackageReference Include="System.Threading.Channels" Version="8.0.0" />
```

## Documentation

- `/docs/api-references.md` - Microsoft Learn API links
- `/docs/*.md` - Complete fetched documentation
- `IMPLEMENTATION_OUTLINE.md` - Detailed design doc

## Usage Example

```json
// Call 1
{"tool": "pwsh", "args": {"script": "$myVar = 42"}}

// Call 2 (same session)
{"tool": "pwsh", "args": {"script": "$myVar * 2"}}
// Returns: 84
```

## Implementation Phases

1. **Core Pool** - PowerShellPool + Session wrapper
2. **MCP Integration** - stdio server + PwshTool
3. **Stream Handling** - Collect all 6 streams
4. **Testing** - Unit/integration tests

Estimated: 2-3 weeks part-time
