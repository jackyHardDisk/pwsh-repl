# Research: Three pwsh-repl Enhancement Concepts

**Date:** 2025-11-18
**Status:** Research Complete - Recommendations Provided

## Executive Summary

This document analyzes three potential enhancements to the pwsh-repl project:

1. **MCP Filter/Wrapper Server** - Token optimization through selective tool exposure
2. **AST Parser Tool** - Multi-language code analysis via loraxMod integration
3. **Project Rename** - Shorter, clearer name than "pwsh"

Each concept is evaluated for feasibility, implementation approach, token impact, and
alignment with project goals.

---

## Concept 1: MCP Filter/Wrapper Server

### Problem Statement

Large MCP servers expose 20-50+ tools, consuming 14k-35k tokens just for tool schemas
before conversation starts. Projects like JetBrains IDE (50+ tools) create severe token
pressure.

**Example token costs:**

- JetBrains unfiltered: ~50,000 tokens (50 tools × ~700-1000 tokens/tool)
- JetBrains filtered: ~1,900 tokens (91% reduction)
- PowerShell unfiltered (if tools): ~14,000 tokens (20 functions as tools)
- PowerShell current: ~1,400 tokens (3 tools, module discovery)

### Terminology Clarification

Research reveals **no meaningful distinction** between "filter" and "wrapper" in MCP
context:

**Filter** = **Wrapper** = Proxy MCP server that:

- Acts as MCP **client** to upstream server (spawns subprocess or HTTP connection)
- Acts as MCP **server** to Claude (stdio protocol)
- Selectively exposes subset of upstream tools
- Forwards allowed tool calls transparently

**Naming convention:** Use "filter" for clarity (matches existing mcp-filter project).

### Architecture Pattern

```
Claude Code
    ↓ stdio
┌─────────────────────┐
│  MCP Filter Server  │  (This project)
│  (Python/Node/.NET) │
└─────────────────────┘
    ↓ stdio/HTTP
┌─────────────────────┐
│  Upstream MCP Server│  (JetBrains, GitHub, etc.)
│  (Original binary)  │
└─────────────────────┘
```

**Proxy mechanisms:**

1. **Stdio transport** - Spawn upstream as subprocess, bidirectional pipe
2. **HTTP/SSE transport** - Connect to remote server, relay requests

**Filtering modes:**

- Allowlist (exact names or regex patterns)
- Denylist (security-focused blocking)
- Renaming (prefix tools to prevent collisions)

### Reference Implementation: mcp-filter (Python)

**Project:** https://github.com/pro-vi/mcp-filter
**Framework:** FastMCP (Python 3.11+)
**Key features:**

- CLI configuration with environment variable overrides
- Regex-based allowlisting/denylisting
- Optional tool renaming (prefix)
- Health monitoring tool
- Token estimation logging

**Configuration example:**

```bash
mcp-filter \
  --upstream-command "jetbrains-server" \
  --allow-patterns "^(read|write|search)_.*" \
  --deny-patterns ".*_delete_.*" \
  --tool-prefix "jb_" \
  --health-tool
```

**Results:** JetBrains 50 tools → 5 exposed = 91% token reduction

### Implementation Options for pwsh-repl

#### Option A: .NET Filter Server (Recommended)

**Pros:**

- Matches existing PowerShell MCP codebase (.NET 8.0)
- Can reuse MCP protocol infrastructure (stdio, tool schemas)
- Native Windows integration
- Single-language project (C#)

**Cons:**

- No established .NET MCP filter framework (would be ground-up)
- Heavier than Python/Node alternatives

**Implementation approach:**

```csharp
// McpFilterServer.cs
public class FilterServer : BaseMcpServer
{
    private Process _upstreamProcess;
    private FilterConfig _config;

    public async Task Start(FilterConfig config)
    {
        // Spawn upstream server
        _upstreamProcess = StartUpstream(config.UpstreamCommand);

        // Query upstream tools
        var upstreamTools = await QueryUpstreamTools();

        // Apply filters
        var filteredTools = ApplyFilters(upstreamTools, config);

        // Register filtered tools as local proxy tools
        RegisterProxyTools(filteredTools);

        // Start stdio server
        await RunStdioServer();
    }

    private async Task<ToolResult> ProxyToolCall(string toolName, object args)
    {
        // Forward to upstream, return result
        return await ForwardToUpstream(toolName, args);
    }
}
```

**Configuration format:**

```json
{
  "mcpServers": {
    "jetbrains-filtered": {
      "command": "McpFilterServer.exe",
      "args": [
        "--upstream", "jetbrains-server.exe",
        "--upstream-args", "--project C:\\path",
        "--allow", "get_file_text_by_path,replace_text_in_file,search_in_files_by_text",
        "--prefix", "jb_"
      ]
    }
  }
}
```

#### Option B: Node.js Filter Server

**Pros:**

- JavaScript ecosystem has existing MCP infrastructure
- Could leverage loraxMod (see Concept 2)
- Lighter weight than .NET

**Cons:**

- Introduces second language to project
- Node.js dependency on Windows

#### Option C: Python Filter Server

**Pros:**

- FastMCP framework available
- Can copy mcp-filter architecture directly
- Python widely available

**Cons:**

- Third language in project
- Python distribution on Windows (conda/venv complexity)

### Recommended Approach

**Implement Option A (.NET Filter Server) as separate subproject:**

```
pwsh-repl/
├── src/
│   ├── pwsh/     # Current PowerShell MCP
│   └── mcp-filter/                # NEW: .NET filter server
│       ├── McpFilterServer.csproj
│       ├── Program.cs
│       ├── FilterConfig.cs
│       ├── UpstreamProxy.cs       # Stdio/HTTP forwarding
│       └── FilterEngine.cs        # Allowlist/denylist logic
```

**Priority:** Medium (useful but not urgent)

- Current token optimization via AgentBricks module works well
- Would benefit JetBrains/GitHub server usage
- Could be standalone project (not tightly coupled to PowerShell MCP)

---

## Concept 2: AST Parser Tool via loraxMod

### Problem Statement

Code analysis tasks (extract functions, find classes, understand structure) currently
require:

- Manual file reading + regex parsing (brittle, language-specific)
- External tools (grep, clang-format --dump-config)
- Multiple tool calls with high token cost

**Example workflow (current):**

```
1. Grep for "class " pattern (fragile)
2. Read matched files
3. Parse with regex (breaks on complex syntax)
4. Manually extract method signatures
```

### Solution: loraxMod AST Parser Integration

**Project:** C:\Users\jacks\experiments\WebStormProjects\loraxMod
**Technology:** Tree-sitter WASM grammars (6 languages)
**Status:** Production-ready, extracted from vibe_tools

**Capabilities:**

- Parse JavaScript, Python, PowerShell, Bash, R, C#
- Extract classes, functions, methods, constants
- Ancestor-aware traversal (parent class context)
- Filtering by name, scope, inheritance
- Zero native dependencies (WASM)

**Example API:**

```javascript
const { parseCode } = require('loraxmod');

const code = `
class MyClass {
  myMethod() {
    console.log("Hello");
  }
}
`;

const segments = await parseCode(code, 'example.js', {
  Elements: ['class', 'method'],  // Extract classes and methods
  PreserveContext: true            // Include parent class in method names
});

// Returns:
// [
//   { type: 'class', name: 'MyClass', startLine: 1, endLine: 5, content: '...' },
//   { type: 'method', name: 'MyClass.myMethod', startLine: 2, endLine: 4, parent: 'MyClass', content: '...' }
// ]
```

### Integration Options

#### Option A: Node.js MCP Server (Recommended)

**Pros:**

- loraxMod is Node.js library (native integration)
- Clean separation from PowerShell MCP
- Could include filter server in same project (Node.js dual purpose)

**Cons:**

- Adds Node.js dependency to project
- Separate language stack

**Implementation approach:**

```
pwsh-repl/
├── src/
│   ├── pwsh/     # Current (C#)
│   └── ast-parser/                # NEW (Node.js)
│       ├── package.json           # Dependencies: loraxmod
│       ├── server.js              # MCP stdio server
│       └── tools/
│           ├── parse-code.js      # Tool: parse code string
│           ├── parse-file.js      # Tool: parse file by path
│           └── query-ast.js       # Tool: XPath-style queries
```

**MCP tools exposed:**

1. `parse_code(code, language, context)` - Parse code string
2. `parse_file(path, context)` - Parse file at path
3. `query_ast(code, language, query)` - XPath-style queries (future)

**Configuration:**

```json
{
  "mcpServers": {
    "ast-parser": {
      "command": "node",
      "args": ["C:\\path\\to\\pwsh-repl\\src\\ast-parser\\server.js"]
    }
  }
}
```

**Token cost:** ~2,100 tokens (3 tools × ~700 tokens)

#### Option B: PowerShell Wrapper

**Approach:** Call Node.js loraxMod from PowerShell via `dev_run`

**Pros:**

- Reuses existing PowerShell MCP
- No new MCP server needed

**Cons:**

- Awkward: PowerShell → Node.js → loraxMod
- Output parsing challenges (JSON via stdout)
- No direct loraxMod API access

**Example:**

```powershell
# Call from PowerShell MCP
dev_run(@"
node -e "
const { parseCode } = require('C:/path/to/loraxMod');
parseCode(\`${code}\`, 'example.js').then(segments =>
  console.log(JSON.stringify(segments))
);
"
"@, "parse")

# Parse JSON from $env:parse_stdout
```

**Assessment:** Not recommended - too indirect, loses type safety

#### Option C: Port loraxMod to .NET

**Approach:** Rewrite tree-sitter wrapper in C#

**Pros:**

- Single-language project
- Native .NET integration

**Cons:**

- Massive effort (loraxMod is ~2000 LOC + 6 language extractors)
- Tree-sitter .NET bindings less mature than Node.js
- Duplicate maintenance burden

**Assessment:** Not worth the effort

### Recommended Approach

**Implement Option A (Node.js MCP Server):**

1. Create `src/ast-parser/` Node.js project
2. Depend on loraxMod via npm link or relative path
3. Expose 3 MCP tools: parse_code, parse_file, query_ast
4. Configure as separate MCP server in settings

**Priority:** High (high-value feature, clean integration)

**Phasing:**

- **Phase 1:** Basic parse_code and parse_file tools
- **Phase 2:** Advanced filtering (Elements, Exclusions, Filters)
- **Phase 3:** XPath-style query_ast tool for complex traversal

---

## Concept 3: Project Rename

### Current Name Analysis

**Current:** `pwsh`

**Issues:**

- Long (21 chars, 6 syllables)
- "persistent" spelling complexity
- Doesn't reflect "Swiss Army toolkit" role
- Focuses on implementation detail (sessions) over utility

**Strengths:**

- Technically accurate
- Clear PowerShell identity
- Describes key differentiator (session persistence)

### Naming Criteria

1. **Shorter:** < 15 chars preferred
2. **Easier to spell:** Common words, no complex patterns
3. **Reflects role:** Swiss Army knife toolkit, development helper
4. **Memorable:** Simple, distinct, evocative
5. **MCP convention:** Fits existing naming (python-repl, filesystem, github)

### Top Recommendations

#### Tier 1: Strong Candidates

**1. `pwsh-kit` (8 chars)** ✓ RECOMMENDED

- **Rationale:** PowerShell toolkit - simple, short, clear role
- **Pros:** Easy to spell, memorable, obvious utility focus
- **Cons:** None significant
- **Fit:** Excellent for "Swiss Army knife" positioning

**2. `pwsh-tools` (10 chars)**

- **Rationale:** PowerShell tools - explicit multi-function focus
- **Pros:** Self-documenting, clear utility collection
- **Cons:** Slightly generic
- **Fit:** Good for toolkit positioning

**3. `pwsh-bench` (10 chars)**

- **Rationale:** PowerShell workbench - development environment
- **Pros:** Evokes craftsmanship, development focus
- **Cons:** "bench" less obvious than "kit"/"tools"
- **Fit:** Good for developer-focused positioning

#### Tier 2: Acceptable Alternatives

**4. `pwsh-agent` (10 chars)**

- **Rationale:** PowerShell agent - fits AI assistant context
- **Pros:** Modern, aligns with Claude Code as AI agent tool
- **Cons:** Might imply autonomous behavior
- **Fit:** Good for AI assistant positioning

**5. `pwsh-repl` (9 chars)**

- **Rationale:** PowerShell REPL - technically accurate
- **Pros:** REPL is known term, accurate description
- **Cons:** REPL doesn't capture AgentBricks toolkit aspect
- **Fit:** Accurate but undersells capabilities

**6. `pwsh-live` (9 chars)**

- **Rationale:** PowerShell live session - dynamic execution
- **Pros:** Conveys real-time, interactive nature
- **Cons:** "live" ambiguous (streaming? persistent?)
- **Fit:** Okay but less clear

#### Tier 3: Not Recommended

**7. `powertool` (9 chars)**

- **Pros:** Clever wordplay, memorable
- **Cons:** Loses clear PowerShell identity
- **Fit:** Poor - identity loss outweighs wordplay

**8. `pwsh` (4 chars)**

- **Pros:** Ultra-short, obvious
- **Cons:** Too generic, likely conflicts with PowerShell itself
- **Fit:** Poor - collision risk

### Recommendation

**Rename to `pwsh-kit`:**

**Justification:**

1. **Clarity:** "kit" clearly signals multi-tool utility
2. **Brevity:** 8 chars vs 21 (62% reduction)
3. **Spelling:** Simple, common words
4. **Identity:** Maintains PowerShell branding
5. **Positioning:** Aligns with "Swiss Army knife" messaging

**Migration path:**

1. Rename project file: `PwshKit.csproj`
2. Rename output binary: `PwshKit.exe` or `pwsh-kit.exe`
3. Update all documentation references
4. Update MCP configuration key: `"pwsh-kit": { ... }`
5. Consider backward compatibility alias (optional)

**Priority:** Low-Medium (improves UX but not urgent)

- Current name works, not broken
- Good time to rename: before wider adoption
- Could combine with v1.0 release milestone

---

## Implementation Priorities

### High Priority

**1. AST Parser (loraxMod integration)**

- **Value:** High - enables code analysis without brittle regex
- **Effort:** Medium - Node.js server, 3 tools
- **Impact:** New capability category
- **Timeline:** 2-3 weeks

### Medium Priority

**2. MCP Filter Server**

- **Value:** Medium - token optimization for other servers
- **Effort:** High - .NET ground-up implementation
- **Impact:** Improves multi-server usage
- **Timeline:** 4-6 weeks
- **Note:** Consider if high token pressure experienced with JetBrains/GitHub

### Low Priority

**3. Project Rename to pwsh-kit**

- **Value:** Low - UX improvement, not functional
- **Effort:** Low - primarily documentation + config
- **Impact:** Better first impression, easier to remember
- **Timeline:** 1-2 days
- **Note:** Do before wider release if at all

---

## Recommended Roadmap

**Phase 1: AST Parser (Immediate)**

```
Week 1-2: Node.js MCP server setup + parse_code/parse_file tools
Week 3: Filtering support (Elements, Exclusions, Filters)
Week 4: Testing, documentation, integration examples
```

**Phase 2: Project Rename (Optional, if time)**

```
Day 1: Rename files, update configs
Day 2: Documentation sweep, test all workflows
```

**Phase 3: MCP Filter (Future, if needed)**

```
Only pursue if:
- Heavy JetBrains/GitHub server usage
- Token pressure becomes problem
- Interest from community for reusable filter

Otherwise: Use existing mcp-filter (Python) via separate install
```

---

## Token Budget Analysis

**Current state:**

- PowerShell MCP: ~1,400 tokens (3 tools)
- AgentBricks: 0 tokens upfront (discovery)

**With AST parser added:**

- PowerShell MCP: ~1,400 tokens
- AST parser MCP: ~2,100 tokens (3 tools)
- **Total: ~3,500 tokens** (still excellent)

**With filter server added (for JetBrains example):**

- PowerShell MCP: ~1,400 tokens
- AST parser MCP: ~2,100 tokens
- JetBrains filtered: ~1,900 tokens (5 tools instead of 50)
- **Total: ~5,400 tokens** (vs 51,400 unfiltered)

**Assessment:** Plenty of token headroom for all three concepts

---

## Questions for Decision

1. **AST parser priority?** Agree high priority? Any specific use cases to prioritize?

2. **Filter server approach?** Build .NET version, or use existing Python mcp-filter?

3. **Rename decision?** Keep `pwsh` or rename to `pwsh-kit`?

4. **Phasing?** AST parser first, then decide on others based on usage patterns?

---

## References

**MCP Filter Pattern:**

- https://github.com/pro-vi/mcp-filter (Python FastMCP implementation)
- https://spec.modelcontextprotocol.io/ (MCP protocol spec)
- https://www.apollographql.com/blog/building-efficient-ai-agents-with-graphql-and-apollo-mcp-server (
  Token optimization)

**loraxMod AST Parser:**

- Local: C:\Users\jacks\experiments\WebStormProjects\loraxMod
- Technology: Tree-sitter WASM (web-tree-sitter)
- Languages: JavaScript, Python, PowerShell, Bash, R, C#

**Token Optimization Research:**

- mcp-filter: 91% reduction (50 tools → 5 tools)
- GraphQL approach: 70-80% reduction via schema optimization
- AgentBricks approach: 90% reduction (module discovery vs tool schemas)

---

## Conclusion

All three concepts are viable and align with pwsh-repl goals:

**Strongest case: AST parser via loraxMod**

- High value, clean integration, fills capability gap
- Node.js is right tool for this job (native loraxMod support)
- Recommended to implement first

**Filter server: Useful but less urgent**

- Current token efficiency already good
- Only needed if heavy multi-server usage
- Could use existing Python mcp-filter instead of building .NET version

**Rename: Low priority polish**

- `pwsh-kit` better than `pwsh`
- Not urgent, but good time is before wider adoption
- Easy change, improves first impressions

**Recommended action:** Build AST parser first, decide on others based on usage
patterns.
