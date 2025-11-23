# Streaming Parser Protocol Specification

## Overview

JSON-based stdin/stdout protocol for long-running tree-sitter parser processes.
Eliminates per-file process spawn overhead (40x+ speedup for batch processing).

**Protocol:**
- Commands: JSON objects via stdin (one per line)
- Responses: JSON objects via stdout (one per line)
- Lifecycle: ping → parse/query (multiple) → shutdown

**Implementation:** `streaming_query_parser.js` (reference implementation)

## Command Reference

### ping

Health check. Returns parser status and statistics.

**Request:**
```json
{"command":"ping"}
```

**Response:**
```json
{
  "status": "pong",
  "uptime": 12345,
  "filesProcessed": 150,
  "queries": 45,
  "errors": 2,
  "memoryUsage": {
    "rss": 52428800,
    "heapTotal": 20971520,
    "heapUsed": 15728640,
    "external": 1048576,
    "arrayBuffers": 524288
  }
}
```

### parse

Parse file using loraxmod, extract code segments.

**Request:**
```json
{
  "command": "parse",
  "file": "/absolute/path/to/file.c",
  "context": {
    "filters": ["functions", "classes"]
  }
}
```

**Response (success):**
```json
{
  "status": "ok",
  "result": {
    "file": "/absolute/path/to/file.c",
    "language": "c",
    "segments": [
      {
        "type": "function",
        "name": "main",
        "startLine": 5,
        "endLine": 10,
        "content": "int main() {\n    ...\n}",
        "lineCount": 6
      }
    ],
    "segmentCount": 1,
    "parseTime": 0
  },
  "stats": {
    "filesProcessed": 151,
    "queries": 45
  }
}
```

**Response (error):**
```json
{
  "status": "error",
  "error": {
    "type": "ParseError",
    "message": "File not found: /path/to/file.c",
    "file": "/path/to/file.c"
  }
}
```

### query

Parse file and execute tree-sitter query pattern.

**Request:**
```json
{
  "command": "query",
  "file": "/absolute/path/to/file.c",
  "query": "(function_definition name: (identifier) @func)",
  "context": null
}
```

**Response (success):**
```json
{
  "status": "ok",
  "result": {
    "file": "/absolute/path/to/file.c",
    "language": "c",
    "queryResults": [
      {
        "name": "func",
        "text": "main",
        "startPosition": {"row": 5, "column": 4},
        "endPosition": {"row": 5, "column": 8},
        "startIndex": 120,
        "endIndex": 124
      }
    ],
    "captureCount": 1
  },
  "stats": {
    "filesProcessed": 152,
    "queries": 46
  }
}
```

**Response (error):**
```json
{
  "status": "error",
  "error": {
    "type": "QueryError",
    "message": "Query syntax invalid",
    "file": "/path/to/file.c"
  }
}
```

### shutdown

Graceful shutdown. Returns final statistics and exits.

**Request:**
```json
{"command":"shutdown"}
```

**Response:**
```json
{
  "status": "shutdown",
  "message": "Parser shutting down after 123 seconds",
  "finalStats": {
    "uptime": 123456,
    "filesProcessed": 500,
    "queries": 150,
    "errors": 5,
    "lastError": {
      "file": "/path/to/problem.c",
      "message": "Syntax error at line 42",
      "timestamp": 1234567890123
    },
    "memoryUsage": {
      "rss": 62428800,
      "heapTotal": 25971520,
      "heapUsed": 18728640,
      "external": 2048576,
      "arrayBuffers": 1024288
    }
  }
}
```

**Process exits after sending response.**

## JSON Schemas

### Request Schema

```typescript
interface CommandRequest {
  command: 'ping' | 'parse' | 'query' | 'shutdown';
  file?: string;           // Required for parse/query
  query?: string;          // Required for query
  context?: object;        // Optional extraction context
}
```

### Response Schema (Success)

```typescript
interface SuccessResponse {
  status: 'ok' | 'pong' | 'shutdown';
  result?: ParseResult | QueryResult;
  stats?: SessionStats;
  uptime?: number;
  filesProcessed?: number;
  queries?: number;
  errors?: number;
  memoryUsage?: MemoryUsage;
  message?: string;
  finalStats?: FinalStats;
}
```

### Response Schema (Error)

```typescript
interface ErrorResponse {
  status: 'error';
  error: {
    type: string;          // Error type (ParseError, QueryError, etc.)
    message: string;       // Human-readable error message
    file?: string;         // File that caused error
  };
}
```

### Parse Result

```typescript
interface ParseResult {
  file: string;
  language: string;
  segments: CodeSegment[];
  segmentCount: number;
  parseTime: number;
}

interface CodeSegment {
  type: string;            // 'function', 'class', etc.
  name: string;
  startLine: number;
  endLine: number;
  content: string;
  lineCount: number;
  // Additional fields vary by language/extractor
}
```

### Query Result

```typescript
interface QueryResult {
  file: string;
  language: string;
  queryResults: QueryCapture[];
  captureCount: number;
}

interface QueryCapture {
  name: string;            // Capture name from query (@func, @var, etc.)
  text: string;            // Matched text
  startPosition: Position;
  endPosition: Position;
  startIndex: number;
  endIndex: number;
}

interface Position {
  row: number;
  column: number;
}
```

### Session Stats

```typescript
interface SessionStats {
  filesProcessed: number;
  queries: number;
}

interface FinalStats extends SessionStats {
  uptime: number;
  errors: number;
  lastError: ErrorRecord | null;
  memoryUsage: MemoryUsage;
}

interface ErrorRecord {
  file: string;
  query?: string;
  message: string;
  timestamp: number;
}

interface MemoryUsage {
  rss: number;             // Resident Set Size
  heapTotal: number;
  heapUsed: number;
  external: number;
  arrayBuffers: number;
}
```

## Example Request/Response Pairs

### Example 1: Startup Health Check

**Request:**
```json
{"command":"ping"}
```

**Response:**
```json
{"status":"pong","uptime":950,"filesProcessed":0,"queries":0,"errors":0,"memoryUsage":{"rss":45678592,"heapTotal":18874368,"heapUsed":12456789,"external":987654,"arrayBuffers":456789}}
```

### Example 2: Parse C File

**Request:**
```json
{"command":"parse","file":"/home/user/project/main.c"}
```

**Response:**
```json
{"status":"ok","result":{"file":"/home/user/project/main.c","language":"c","segments":[{"type":"function","name":"add","startLine":3,"endLine":5,"content":"int add(int a, int b) {\n    return a + b;\n}","lineCount":3},{"type":"function","name":"main","startLine":7,"endLine":11,"content":"int main() {\n    int result = add(5, 3);\n    printf(\"Result: %d\\n\", result);\n    return 0;\n}","lineCount":5}],"segmentCount":2,"parseTime":0},"stats":{"filesProcessed":1,"queries":0}}
```

### Example 3: Query for Functions

**Request:**
```json
{"command":"query","file":"/home/user/project/main.c","query":"(function_definition name: (identifier) @func)"}
```

**Response:**
```json
{"status":"ok","result":{"file":"/home/user/project/main.c","language":"c","queryResults":[{"name":"func","text":"add","startPosition":{"row":2,"column":4},"endPosition":{"row":2,"column":7},"startIndex":38,"endIndex":41},{"name":"func","text":"main","startPosition":{"row":6,"column":4},"endPosition":{"row":6,"column":8},"startIndex":98,"endIndex":102}],"captureCount":2},"stats":{"filesProcessed":2,"queries":1}}
```

### Example 4: Error - File Not Found

**Request:**
```json
{"command":"parse","file":"/nonexistent/file.c"}
```

**Response:**
```json
{"status":"error","error":{"type":"ParseError","message":"File not found: /nonexistent/file.c","file":"/nonexistent/file.c"}}
```

### Example 5: Graceful Shutdown

**Request:**
```json
{"command":"shutdown"}
```

**Response:**
```json
{"status":"shutdown","message":"Parser shutting down after 125 seconds","finalStats":{"uptime":125432,"filesProcessed":347,"queries":89,"errors":3,"lastError":{"file":"/path/error.c","message":"Syntax error","timestamp":1234567890123},"memoryUsage":{"rss":52428800,"heapTotal":20971520,"heapUsed":15728640,"external":1048576,"arrayBuffers":524288}}}
```

## Implementation Guidelines

### Custom Parser Requirements

1. **Initialization**
   - Start parser (load grammars, initialize state)
   - Listen on stdin for JSON commands
   - Respond to ping within 5 seconds

2. **Command Processing**
   - Parse one JSON object per line
   - Execute command
   - Write one JSON response per line to stdout
   - Flush stdout after each response

3. **Error Handling**
   - Catch all exceptions
   - Return error response (never crash)
   - Continue processing subsequent commands
   - Track error count and last error

4. **State Management**
   - Track uptime, filesProcessed, queries, errors
   - Maintain lastError for debugging
   - Monitor memory usage

5. **Graceful Shutdown**
   - Respond to shutdown command
   - Send final statistics
   - Exit with code 0

### PowerShell Integration

LoraxMod streaming functions expect:
- **Initialization**: Parser responds to ping within TimeoutSeconds
- **Processing**: Parser responds to parse/query within TimeoutSeconds
- **Shutdown**: Parser exits within TimeoutSeconds after shutdown command

**Default Timeouts:**
- Initialization: 5 seconds
- Per-command: 30 seconds
- Shutdown: 5 seconds

### Performance Considerations

**Batch Processing:**
- Single process handles thousands of files
- Eliminates per-file spawn overhead
- Grammar loaded once, reused for all files
- 40x+ speedup vs per-file spawning (measured)

**Memory Management:**
- Monitor heap usage (return in ping response)
- Consider memory limits for large file sets
- Restart parser session if memory grows excessive

**Concurrency:**
- Multiple parser sessions supported (different SessionId)
- Each session is independent process
- No shared state between sessions

## Validation

**Protocol Compliance:**
1. Parser responds to ping immediately
2. Parser handles parse command for valid file
3. Parser handles query command with tree-sitter syntax
4. Parser returns error response (not crash) for invalid file
5. Parser shuts down gracefully with final stats

**Reference Implementation:**
- `streaming_query_parser.js` passes all protocol tests
- Used by LoraxMod v0.2.0 streaming functions
- Implements loraxmod integration

## See Also

- `Start-LoraxStreamParser` - PowerShell function to start parser
- `Invoke-LoraxStreamQuery` - PowerShell function to send commands
- `Stop-LoraxStreamParser` - PowerShell function to shutdown
- `streaming_query_parser.js` - Reference implementation
- loraxmod library documentation
