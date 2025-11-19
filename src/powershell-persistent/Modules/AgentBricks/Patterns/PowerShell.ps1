# PowerShell Error Patterns
# Pre-configured patterns for PowerShell script errors

# PowerShell Script Errors
Set-Pattern -Name "PowerShell-Error" `
    -Pattern 'At\s+(?<file>[\w/\\:.-]+):(?<line>\d+)\s+char:(?<col>\d+)' `
    -Description "PowerShell errors: At file:line char:col" `
    -Category "error"
