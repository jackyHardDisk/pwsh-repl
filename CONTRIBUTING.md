# Contributing to pwsh-repl

Thanks for your interest in contributing to pwsh-repl!

## Reporting Issues

**Bug reports**: Use the bug report template. Include:
- PowerShell version (`$PSVersionTable`)
- .NET version (`dotnet --version`)
- Steps to reproduce
- Expected vs actual behavior

**Feature requests**: Use the feature request template. Describe the use case.

## Development Setup

1. Clone the repo
2. Ensure .NET 8.0 SDK installed
3. Run `dotnet restore`
4. Run `dotnet build`

Build output: `release/v0.1.0/`

## Code Style

- C#: Follow existing patterns in codebase
- PowerShell: Use approved verbs (`Get-Verb`), no emojis in scripts
- Commits: Use conventional commits (`feat:`, `fix:`, `refactor:`, etc.)

## Pull Requests

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make changes
4. Test locally (`dotnet build`)
5. Submit PR with description of changes

## Module Development

### AgentBlocks
Functions in `src/pwsh-repl/Modules/AgentBlocks/`. Export via manifest.

### Adding Patterns
Use `Set-Pattern` or add to `Patterns/Default.ps1`.

## Questions?

Open an issue with the question label.
