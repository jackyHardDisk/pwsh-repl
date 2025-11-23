# Pester Tests for LoraxMod REPL and Analysis Functions
# Compatible with: Pester 3.4.0+

# Module setup (executed once at script load)
$modulePath = Split-Path $PSScriptRoot -Parent
Import-Module "$modulePath\LoraxMod.psd1" -Force

# Test fixtures (script-level variables)
$script:FixturesPath = Join-Path $PSScriptRoot "fixtures"
$script:SampleC = Join-Path $script:FixturesPath "sample.c"
$script:SamplePy = Join-Path $script:FixturesPath "sample.py"

Describe "Find-FunctionCalls - C Language" {
    It "Should find all function calls in C file" {
        $result = Find-FunctionCalls -Language c -FilePath $script:SampleC

        $result.Count -gt 0 | Should Be $true
        $result | Where-Object { $_.function -eq 'add' } | Should Not Be $null
        $result | Where-Object { $_.function -eq 'printf' } | Should Not Be $null
    }

    It "Should provide function call context" {
        $result = Find-FunctionCalls -Language c -FilePath $script:SampleC
        $addCall = $result | Where-Object { $_.function -eq 'add' }

        $addCall.function | Should Be 'add'
        $addCall.line | Should Be 12
        $addCall.parentFunction | Should Be 'main'
        $addCall.arguments.Count | Should Be 2
        $addCall.codeLine | Should Not Be $null
    }

    It "Should filter by function names" {
        $result = Find-FunctionCalls -Language c -FilePath $script:SampleC -FunctionNames @('printf')

        $result.Count | Should Be 1
        $result[0].function | Should Be 'printf'
    }

    It "Should find calls in code string" {
        $code = 'int main() { printf("test"); return 0; }'
        $result = Find-FunctionCalls -Language c -Code $code

        $result.Count | Should Be 1
        $result[0].function | Should Be 'printf'
    }

    It "Should handle file with no function calls" {
        $code = 'int x = 42;'
        $result = Find-FunctionCalls -Language c -Code $code

        $result.Count | Should Be 0
    }
}

Describe "Find-FunctionCalls - Python Language" {
    It "Should find function calls in Python file" {
        $result = Find-FunctionCalls -Language python -FilePath $script:SamplePy

        $result.Count -gt 0 | Should Be $true
        $result | Where-Object { $_.function -match 'greet|calculate|print' } | Should Not Be $null
    }

    It "Should provide parent function context" {
        $code = 'def outer(): inner(); return 42'
        $result = Find-FunctionCalls -Language python -Code $code

        $innerCall = $result | Where-Object { $_.function -eq 'inner' }
        $innerCall.parentFunction | Should Be 'outer'
    }
}

Describe "Get-IncludeDependencies - C/C++ Files" {
    It "Should extract system includes from C file" {
        $result = Get-IncludeDependencies -FilePath $script:SampleC

        $result.system.Count -gt 0 | Should Be $true
        $result.system -contains 'stdio.h' | Should Be $true
    }

    It "Should categorize POSIX headers" {
        $code = '#include <unistd.h>
#include <stdio.h>
#include "local.h"'

        $result = Get-IncludeDependencies -Code $code

        $result.system.Count | Should Be 2
        $result.posix.Count | Should Be 1
        $result.posix -contains 'unistd.h' | Should Be $true
        $result.local.Count | Should Be 1
        $result.local -contains 'local.h' | Should Be $true
    }

    It "Should separate system and local includes" {
        $code = '#include <stdlib.h>
#include "myheader.h"
#include <string.h>'

        $result = Get-IncludeDependencies -Code $code

        $result.system.Count | Should Be 2
        $result.local.Count | Should Be 1
        $result.system -contains 'stdlib.h' | Should Be $true
        $result.system -contains 'string.h' | Should Be $true
        $result.local -contains 'myheader.h' | Should Be $true
    }

    It "Should handle file with no includes" {
        $code = 'int main() { return 0; }'
        $result = Get-IncludeDependencies -Code $code

        $result.system.Count | Should Be 0
        $result.local.Count | Should Be 0
        $result.posix.Count | Should Be 0
    }

    It "Should detect multiple POSIX headers" {
        $code = '#include <unistd.h>
#include <pwd.h>
#include <grp.h>
#include <stdio.h>'

        $result = Get-IncludeDependencies -Code $code

        $result.posix.Count | Should Be 3
        $result.posix -contains 'unistd.h' | Should Be $true
        $result.posix -contains 'pwd.h' | Should Be $true
        $result.posix -contains 'grp.h' | Should Be $true
    }
}

Describe "Start-TreeSitterSession - Error Handling" {
    # Note: Cannot test interactive REPL automatically (spawns Node.js REPL)
    # Manual test: Start-TreeSitterSession -Language c -Code 'int main() { return 0; }'
    # Expected: Opens REPL with globals: parser, tree, root, code
    # Test manually: root.type should return 'translation_unit'

    It "Should accept valid language parameter" {
        # Just verify the function exists and accepts the parameter
        $hasParam = (Get-Command Start-TreeSitterSession).Parameters.ContainsKey('Language')
        $hasParam | Should Be $true
    }
}

Describe "Integration - Find-FunctionCalls with Multiple Languages" {
    It "Should handle C++ code" {
        $code = 'void test() { std::cout << "test"; }'
        { Find-FunctionCalls -Language cpp -Code $code } | Should Not Throw
    }

    It "Should handle JavaScript code" {
        $code = 'function test() { console.log("test"); }'
        { Find-FunctionCalls -Language javascript -Code $code } | Should Not Throw
    }

    It "Should handle Rust code" {
        $code = 'fn main() { println!("test"); }'
        { Find-FunctionCalls -Language rust -Code $code } | Should Not Throw
    }
}

Describe "Error Handling - Invalid Inputs" {
    It "Find-FunctionCalls should handle missing file gracefully" {
        $result = Find-FunctionCalls -Language c -FilePath 'nonexistent.c' -ErrorAction SilentlyContinue -ErrorVariable capturedError 2>&1
        $result | Should Be $null
        $capturedError.Count -gt 0 | Should Be $true
    }

    It "Get-IncludeDependencies should handle missing file gracefully" {
        $result = Get-IncludeDependencies -FilePath 'nonexistent.c' -ErrorAction SilentlyContinue -ErrorVariable capturedError 2>&1
        $result | Should Be $null
        $capturedError.Count -gt 0 | Should Be $true
    }

    It "Find-FunctionCalls should handle empty code" {
        $result = Find-FunctionCalls -Language c -Code '' -ErrorAction SilentlyContinue
        # Empty code should parse without errors, just return empty result
        $result.Count | Should Be 0
    }
}
