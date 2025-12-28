# Git Patterns
# Pre-configured patterns for Git version control output

# Git Status Short Format (git status --short)
# XY format: X=index, Y=worktree. M=modified, A=added, D=deleted, ?=untracked
Set-Pattern -Name "Git-Status" `
    -Pattern '^(?<index>[ MADRCU?!])(?<worktree>[ MADRCU?!])\s+(?<file>.+)$' `
    -Description "Git status short: XY file (M=modified, A=added, D=deleted, ?=untracked)" `
    -Category "info"

# Git Status Verbose Format (git status without --short)
Set-Pattern -Name "Git-StatusVerbose" `
    -Pattern '(?<status>modified|deleted|new file):\s+(?<file>[\w/\\.-]+)' `
    -Description "Git status verbose: modified/deleted/new file: filename" `
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
