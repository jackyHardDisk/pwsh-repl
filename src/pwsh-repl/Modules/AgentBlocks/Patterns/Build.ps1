# Build Tool Patterns
# Pre-configured patterns for Make, CMake, and other build systems

# GCC/G++ Errors
Set-Pattern -Name "GCC-Error" `
    -Pattern '(?<file>[\w/\\.-]+):(?<line>\d+):(?<col>\d+):\s*error:\s*(?<message>.+)' `
    -Description "GCC/G++ errors: file:line:col: error: message" `
    -Category "error"

# GCC/G++ Warnings
Set-Pattern -Name "GCC-Warning" `
    -Pattern '(?<file>[\w/\\.-]+):(?<line>\d+):(?<col>\d+):\s*warning:\s*(?<message>.+)' `
    -Description "GCC/G++ warnings: file:line:col: warning: message" `
    -Category "warning"

# Clang Errors
Set-Pattern -Name "Clang-Error" `
    -Pattern '(?<file>[\w/\\.-]+):(?<line>\d+):(?<col>\d+):\s*error:\s*(?<message>.+)' `
    -Description "Clang errors: file:line:col: error: message" `
    -Category "error"

# CMake Configuration Errors
Set-Pattern -Name "CMake-Error" `
    -Pattern 'CMake Error at (?<file>[\w/\\.-]+):(?<line>\d+)\s*\((?<function>\w+)\):\s*(?<message>.+)' `
    -Description "CMake errors: CMake Error at file:line (function): message" `
    -Category "error"

# CMake Warnings
Set-Pattern -Name "CMake-Warning" `
    -Pattern 'CMake Warning at (?<file>[\w/\\.-]+):(?<line>\d+)\s*\((?<function>\w+)\):\s*(?<message>.+)' `
    -Description "CMake warnings" `
    -Category "warning"

# Make Errors (generic)
Set-Pattern -Name "Make-Error" `
    -Pattern 'make(?:\[\d+\])?:\s*\*\*\*\s*(?<message>.+)' `
    -Description "Make errors: make: *** message" `
    -Category "error"

# Linker Errors (ld)
Set-Pattern -Name "Linker-Error" `
    -Pattern '(?<file>[\w/\\.-]+):(?<line>\d+):\s*undefined reference to\s*`(?<symbol>[\w:]+)' `
    -Description "Linker undefined reference errors" `
    -Category "error"

# Ninja Build Errors
Set-Pattern -Name "Ninja-Error" `
    -Pattern 'ninja:\s*error:\s*(?<message>.+)' `
    -Description "Ninja build errors" `
    -Category "error"

# Maven Build Errors
Set-Pattern -Name "Maven-Error" `
    -Pattern '\[ERROR\]\s*(?<message>.+)' `
    -Description "Maven build errors: [ERROR] message" `
    -Category "error"

# Gradle Build Errors
Set-Pattern -Name "Gradle-Error" `
    -Pattern '(?<severity>FAILURE|ERROR):\s*(?<message>.+)' `
    -Description "Gradle build errors" `
    -Category "error"

# Rust Compiler Errors
Set-Pattern -Name "Rustc-Error" `
    -Pattern 'error(?:\[(?<code>E\d+)\])?:\s*(?<message>.+)' `
    -Description "Rust compiler errors" `
    -Category "error"

# Cargo Build Errors (with file location)
Set-Pattern -Name "Cargo-Error" `
    -Pattern 'error:\s*(?<message>.+)\s*-->\s*(?<file>[\w/\\.-]+):(?<line>\d+):(?<col>\d+)' `
    -Description "Cargo errors with location" `
    -Category "error"

# Go Compiler Errors
Set-Pattern -Name "Go-Error" `
    -Pattern '(?<file>[\w/\\.-]+):(?<line>\d+):(?<col>\d+):\s*(?<message>.+)' `
    -Description "Go compiler errors: file:line:col: message" `
    -Category "error"

# Docker Build Errors
Set-Pattern -Name "Docker" `
    -Pattern 'ERROR\s+\[(?<stage>[\w\s]+)\s*\d*/\d*\]\s*(?<message>.+)' `
    -Description "Docker build errors: ERROR [stage] message" `
    -Category "error"
