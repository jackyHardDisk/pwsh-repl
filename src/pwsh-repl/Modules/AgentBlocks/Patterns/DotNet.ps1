# .NET Tool Patterns
# Pre-configured patterns for .NET development tools

# MSBuild / .NET Build Errors (CS, MSB, NU, NETSDK, FS, BC codes)
Set-Pattern -Name "MSBuild-Error" `
    -Pattern '(?<file>[^(]+)\((?<line>\d+),(?<col>\d+)\):\s*error\s*(?<code>[A-Z]+\d+):\s*(?<message>.+)' `
    -Description "MSBuild errors: file(line,col): error CODE: message" `
    -Category "error"

# MSBuild / .NET Build Warnings (CS, MSB, NU, NETSDK, FS, BC codes)
Set-Pattern -Name "MSBuild-Warning" `
    -Pattern '(?<file>[^(]+)\((?<line>\d+),(?<col>\d+)\):\s*warning\s*(?<code>[A-Z]+\d+):\s*(?<message>.+)' `
    -Description "MSBuild warnings: file(line,col): warning CODE: message" `
    -Category "warning"

# NuGet Package Restore Errors
Set-Pattern -Name "NuGet-Error" `
    -Pattern 'error\s*(?<code>NU\d+):\s*(?<message>.+)' `
    -Description "NuGet errors: error NU####: message" `
    -Category "error"

# NUnit Test Failures
Set-Pattern -Name "NUnit-Fail" `
    -Pattern 'Failed\s+(?<test>[\w.]+)\s*\[(?<duration>[\d.]+)s\]' `
    -Description "NUnit test failures" `
    -Category "test"

# xUnit Test Failures
Set-Pattern -Name "xUnit-Fail" `
    -Pattern '\[FAIL\]\s+(?<test>[\w.]+)' `
    -Description "xUnit test failures" `
    -Category "test"

# MSTest Failures
Set-Pattern -Name "MSTest-Fail" `
    -Pattern 'Failed\s+(?<test>[\w.]+)' `
    -Description "MSTest test failures" `
    -Category "test"

# .NET Runtime Exceptions
Set-Pattern -Name "DotNet-Exception" `
    -Pattern '(?<exception>[\w.]+Exception):\s*(?<message>.+)' `
    -Description ".NET exception: ExceptionType: message" `
    -Category "error"

# Roslyn Analyzer Warnings (CA codes)
Set-Pattern -Name "Roslyn-Analyzer" `
    -Pattern '(?<file>[\w/\\.-]+)\((?<line>\d+),(?<col>\d+)\):\s*(?<severity>warning|error)\s*(?<code>CA\d+):\s*(?<message>.+)' `
    -Description "Roslyn analyzer diagnostics: CA codes" `
    -Category "lint"

# StyleCop Warnings (SA codes)
Set-Pattern -Name "StyleCop" `
    -Pattern '(?<file>[\w/\\.-]+)\((?<line>\d+),(?<col>\d+)\):\s*warning\s*(?<code>SA\d+):\s*(?<message>.+)' `
    -Description "StyleCop style warnings: SA codes" `
    -Category "lint"

# .NET SDK Errors
Set-Pattern -Name "DotNet-SDK" `
    -Pattern 'error\s*NETSDK(?<code>\d+):\s*(?<message>.+)' `
    -Description ".NET SDK errors" `
    -Category "error"
