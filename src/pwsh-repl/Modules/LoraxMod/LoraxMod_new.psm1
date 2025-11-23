<#
.SYNOPSIS
Interactive tree-sitter AST navigation via Node.js REPL

.DESCRIPTION
PowerShell wrappers for exploring tree-sitter AST nodes interactively.
Uses Node.js REPL with loraxmod for direct AST manipulation.

.NOTES
Requires Node.js (optional peer dependency)
loraxmod bundled in module directory
#>

# Store module root at load time (works in background sessions)
$script:ModuleRoot = $PSScriptRoot
$script:LoraxPath = "$script:ModuleRoot/loraxmod/lib/index.js" -replace '\', '/'
