# CI/CD Tool Patterns
# Pre-configured patterns for continuous integration platforms

# GitHub Actions Workflow Errors
Set-Pattern -Name "GitHub-Actions" `
    -Pattern 'Error:\s*(?<message>.+)' `
    -Description "GitHub Actions: Error: message" `
    -Category "error"
