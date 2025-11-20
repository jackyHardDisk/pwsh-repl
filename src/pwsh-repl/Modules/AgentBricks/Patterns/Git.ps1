# Git Patterns
# Pre-configured patterns for Git version control output

# Git Status - Modified/Deleted Files
Set-Pattern -Name "Git-Status" `
    -Pattern '(?<status>modified|deleted|new file):\s+(?<file>[\w/\\.-]+)' `
    -Description "Git status: modified/deleted/new file: filename" `
    -Category "info"

# Git Conflict Markers
Set-Pattern -Name "Git-Conflict" `
    -Pattern '<<<<<<< HEAD|=======|>>>>>>>' `
    -Description "Git conflict markers in files" `
    -Category "error"

# Git Merge Conflicts
Set-Pattern -Name "Git-MergeConflict" `
    -Pattern 'CONFLICT\s+\((?<type>[\w\s]+)\):\s+Merge conflict in\s+(?<file>[\w/\\.-]+)' `
    -Description "Git merge conflict: CONFLICT (type): Merge conflict in file" `
    -Category "error"
