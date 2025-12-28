# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-12-27

### Added

- **Core MCP Server**: Persistent PowerShell sessions with variable state across calls
- **3 MCP Tools**: `pwsh`, `stdio`, `list_sessions`
- **AgentBlocks Module**: 41 functions for execution, transformation, state management
  - Execution: `Invoke-DevRun`, `Get-DevRunOutput`, `Invoke-WithTimeout`
  - Transform: `Format-Count`, `Group-By`, `Group-Similar`, `Group-BuildErrors`
  - Extract: `Select-RegexMatch`, `Select-TextBetween`, `Select-Column`
  - Analyze: `Find-Errors`, `Find-Warnings`, `Get-BuildError`
  - 43 pre-configured patterns (ESLint, Pytest, MSBuild, GCC, etc.)
- **LoraxMod Module**: Tree-sitter AST parsing for 28 languages (via NuGet)
- **Mode Callback Pattern**: Call AgentBlocks functions via `mode` parameter
- **Session Isolation**: Named sessions with independent variable scopes
- **Background Execution**: Run long processes with `runInBackground=true`
- **Windows Job Objects**: Atomic process tree cleanup on timeout
- **EOF Pipe Stdin**: Proper subprocess compatibility
- **MCP Resources**: Dynamic module discovery via `pwsh_mcp_modules://`
- **Audit Logging**: Optional script logging via `PWSH_MCP_AUDIT_LOG`

### Infrastructure

- MIT License
- GitHub Actions release workflow with NuGet publishing
- NuGet package: `dotnet tool install -g pwsh-repl`
- Contributor Covenant Code of Conduct

## [Unreleased]

### Planned

- Integration test suite
- JEA (Just Enough Administration) support
- Multi-project MCP collection
