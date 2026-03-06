<#
.SYNOPSIS
    Python pdb debugging helpers for AI agents

.DESCRIPTION
    Functions to generate pdb commands and parse output for efficient debugging workflows.
    Designed for batch inspection of variables, arrays, and dict structures.

.NOTES
    Used with pwsh-repl stdio tool for pdb interaction.
#>

function Get-PdbArrayCommands {
    <#
    .SYNOPSIS
        Generate pdb commands for comprehensive array inspection

    .DESCRIPTION
        Returns array of pdb print commands to inspect shape, dtype, range, and NaN/Inf counts.
        Works with both numpy and cupy arrays.

    .PARAMETER VarName
        Name of the array variable in pdb scope

    .EXAMPLE
        Get-PdbArrayCommands -VarName 'coord_tiles'
        # Returns commands for shape, dtype, min, max, nan count, inf count
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$VarName
    )
    @(
        "p $VarName.shape"
        "p $VarName.dtype"
        "p float($VarName.min())"
        "p float($VarName.max())"
        "p int(cp.isnan($VarName).sum()) if 'cupy' in str(type($VarName)) else int(np.isnan($VarName).sum())"
        "p int(cp.isinf($VarName).sum()) if 'cupy' in str(type($VarName)) else int(np.isinf($VarName).sum())"
    )
}

function Get-PdbDictCommands {
    <#
    .SYNOPSIS
        Generate pdb commands for dict inspection

    .DESCRIPTION
        Returns commands to inspect dict keys and optionally shapes of array values.

    .PARAMETER VarName
        Name of the dict variable in pdb scope

    .PARAMETER InspectShapes
        If true, also generates commands to inspect .shape of each value

    .EXAMPLE
        Get-PdbDictCommands -VarName 'results'
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$VarName,

        [switch]$InspectShapes
    )
    $cmds = @(
        "p list($VarName.keys())"
        "p {k: v.shape if hasattr(v, 'shape') else type(v).__name__ for k, v in $VarName.items()}"
    )
    if ($InspectShapes) {
        $cmds += "p {k: (float(v.min()), float(v.max())) if hasattr(v, 'min') else 'N/A' for k, v in $VarName.items()}"
    }
    $cmds
}

function Get-PdbLocalsCommands {
    <#
    .SYNOPSIS
        Generate pdb commands to inspect local variables

    .EXAMPLE
        Get-PdbLocalsCommands
    #>
    @(
        "p {k: type(v).__name__ for k, v in locals().items() if not k.startswith('_')}"
    )
}

function Join-PdbCommands {
    <#
    .SYNOPSIS
        Join pdb commands into a single string for batch sending

    .DESCRIPTION
        Concatenates commands with newlines, adds trailing newline for execution.

    .PARAMETER Commands
        Array of pdb commands to join

    .EXAMPLE
        $batch = Join-PdbCommands -Commands (Get-PdbArrayCommands 'data')
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Commands
    )
    begin { $all = @() }
    process { $all += $Commands }
    end { ($all -join "`n") + "`n" }
}

function New-PdbArrayInspect {
    <#
    .SYNOPSIS
        Generate batch command string for inspecting multiple arrays

    .PARAMETER VarNames
        Array of variable names to inspect

    .EXAMPLE
        $batch = New-PdbArrayInspect -VarNames @('coord_tiles', 'data_gpu')
        # Send $batch to pdb via stdio
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$VarNames
    )
    $cmds = foreach ($v in $VarNames) {
        Get-PdbArrayCommands -VarName $v
    }
    Join-PdbCommands -Commands $cmds
}

function ConvertFrom-PdbOutput {
    <#
    .SYNOPSIS
        Parse pdb output into structured results

    .DESCRIPTION
        Extracts expression -> value pairs from pdb print command output.
        Handles multi-line values and prompt detection.

    .PARAMETER Output
        Raw pdb output string

    .EXAMPLE
        $results = $pdbOutput | ConvertFrom-PdbOutput
        $results.'coord_tiles.shape'
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Output
    )
    begin { $allOutput = @() }
    process { $allOutput += $Output }
    end {
        $results = @{}
        $Output = $allOutput -join "`n"
        $lines = $Output -split "`n"
        $currentExpr = $null
        $currentValue = @()

        foreach ($line in $lines) {
            # Match "(Pdb) p <expression>"
            if ($line -match '^\(Pdb\)\s*p\s+(.+)$') {
                if ($currentExpr) {
                    $results[$currentExpr] = ($currentValue -join "`n").Trim()
                }
                $currentExpr = $Matches[1]
                $currentValue = @()
            }
            # Match standalone "(Pdb)" prompt
            elseif ($line -match '^\(Pdb\)\s*$') {
                if ($currentExpr) {
                    $results[$currentExpr] = ($currentValue -join "`n").Trim()
                }
                $currentExpr = $null
                $currentValue = @()
            }
            # Accumulate value lines
            elseif ($currentExpr -and $line.Trim()) {
                $currentValue += $line
            }
        }

        # Handle final expression
        if ($currentExpr) {
            $results[$currentExpr] = ($currentValue -join "`n").Trim()
        }

        [PSCustomObject]$results
    }
}

function Test-PdbReady {
    <#
    .SYNOPSIS
        Check if pdb output ends with prompt (ready for input)

    .PARAMETER Output
        Output string from pdb

    .EXAMPLE
        if (Test-PdbReady -Output $out) { "Ready for next command" }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Output
    )
    $Output -match '\(Pdb\)\s*$'
}

function Get-PdbStepCommands {
    <#
    .SYNOPSIS
        Common pdb navigation commands

    .PARAMETER Action
        One of: step, next, continue, return, where, list
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('step', 'next', 'continue', 'return', 'where', 'list', 'args')]
        [string]$Action
    )
    switch ($Action) {
        'step' { 's' }
        'next' { 'n' }
        'continue' { 'c' }
        'return' { 'r' }
        'where' { 'w' }
        'list' { 'l' }
        'args' { 'a' }
    }
}
