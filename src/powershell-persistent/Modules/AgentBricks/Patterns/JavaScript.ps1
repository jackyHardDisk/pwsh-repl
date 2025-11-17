# JavaScript/TypeScript Tool Patterns
# Pre-configured patterns for common JS/TS development tools

# ESLint - JavaScript/TypeScript linter
Set-Pattern -Name "ESLint" `
    -Pattern '(?<file>[\w/\\.-]+):(?<line>\d+):(?<col>\d+):\s*(?<severity>error|warning):\s*(?<message>.+?)\s+(?<rule>[\w/-]+)' `
    -Description "ESLint output: file:line:col: severity: message rule" `
    -Category "lint"

# Stylelint - CSS/SCSS linter
Set-Pattern -Name "Stylelint" `
    -Pattern '(?<file>[\w/\\.-]+)\s+(?<line>\d+):(?<col>\d+)\s+(?<severity>✖|⚠)\s+(?<message>.+?)\s+(?<rule>[\w/-]+)' `
    -Description "Stylelint output: file line:col symbol message rule" `
    -Category "lint"

# TypeScript Compiler
Set-Pattern -Name "TypeScript" `
    -Pattern '(?<file>[\w/\\.-]+)\((?<line>\d+),(?<col>\d+)\):\s*error\s*TS(?<code>\d+):\s*(?<message>.+)' `
    -Description "TypeScript: file(line,col): error TS####: message" `
    -Category "error"

# Prettier - Code formatter (usually just file names when checking)
Set-Pattern -Name "Prettier" `
    -Pattern '(?<file>[\w/\\.-]+)' `
    -Description "Prettier unformatted files" `
    -Category "format"

# Vite - Build tool errors
Set-Pattern -Name "Vite" `
    -Pattern '(?<severity>error|warning):\s*(?<message>.+)' `
    -Description "Vite build errors/warnings" `
    -Category "build"

# Webpack - Build tool
Set-Pattern -Name "Webpack" `
    -Pattern 'ERROR in (?<file>[\w/\\.-]+)(?:\((?<line>\d+),(?<col>\d+)\))?\s*(?<message>.+)' `
    -Description "Webpack compilation errors" `
    -Category "build"

# Jest - Test framework
Set-Pattern -Name "Jest-Error" `
    -Pattern '●\s+(?<test>[\w\s›]+)\s*(?<message>.+)' `
    -Description "Jest test failures" `
    -Category "test"

# Node.js Stack Traces
Set-Pattern -Name "NodeStackTrace" `
    -Pattern 'at\s+(?<function>[\w.<>]+)\s+\((?<file>[\w/\\.-]+):(?<line>\d+):(?<col>\d+)\)' `
    -Description "Node.js stack trace format" `
    -Category "error"
