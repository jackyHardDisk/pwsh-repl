# Python Tool Patterns
# Pre-configured patterns for Python development tools

# Pytest - Test framework failures
Set-Pattern -Name "Pytest-Fail" `
    -Pattern 'FAILED\s+(?<test>[\w/:.-]+)\s*-\s*(?<reason>.+)' `
    -Description "Pytest test failures: FAILED test - reason" `
    -Category "test"

# Pytest - Test passes (for completeness)
Set-Pattern -Name "Pytest-Pass" `
    -Pattern 'PASSED\s+(?<test>[\w/:.-]+)' `
    -Description "Pytest test passes" `
    -Category "test"

# Python Traceback - File location
Set-Pattern -Name "PythonTraceback" `
    -Pattern 'File "(?<file>[\w/\\.-]+)",\s+line\s+(?<line>\d+),\s+in\s+(?<function>\w+)' `
    -Description "Python traceback: File, line, function" `
    -Category "error"

# Python Exception
Set-Pattern -Name "PythonException" `
    -Pattern '(?<exception>\w+Error|Exception):\s*(?<message>.+)' `
    -Description "Python exception: ExceptionType: message" `
    -Category "error"

# Mypy - Type checker
Set-Pattern -Name "Mypy" `
    -Pattern '(?<file>[\w/\\.-]+):(?<line>\d+):\s*(?<severity>error|warning|note):\s*(?<message>.+)' `
    -Description "Mypy type errors: file:line: severity: message" `
    -Category "lint"

# Flake8 - Linter
Set-Pattern -Name "Flake8" `
    -Pattern '(?<file>[\w/\\.-]+):(?<line>\d+):(?<col>\d+):\s*(?<code>[A-Z]\d+)\s+(?<message>.+)' `
    -Description "Flake8: file:line:col: code message" `
    -Category "lint"

# Black - Code formatter (usually just file names)
Set-Pattern -Name "Black" `
    -Pattern 'would reformat\s+(?<file>[\w/\\.-]+)' `
    -Description "Black files needing formatting" `
    -Category "format"

# Pylint - Linter
Set-Pattern -Name "Pylint" `
    -Pattern '(?<file>[\w/\\.-]+):(?<line>\d+):(?<col>\d+):\s*(?<code>[A-Z]\d+):\s*(?<message>.+)\s+\((?<rule>[\w-]+)\)' `
    -Description "Pylint: file:line:col: code: message (rule)" `
    -Category "lint"

# Python unittest - Failures
Set-Pattern -Name "Unittest-Fail" `
    -Pattern 'FAIL:\s+(?<test>[\w.]+)\s+\((?<class>[\w.]+)\)' `
    -Description "unittest failures" `
    -Category "test"

# Coverage.py - Missing coverage
Set-Pattern -Name "Coverage" `
    -Pattern '(?<file>[\w/\\.-]+)\s+(?<statements>\d+)\s+(?<missing>\d+)\s+(?<coverage>\d+)%' `
    -Description "Coverage report line: file statements missing coverage%" `
    -Category "info"
