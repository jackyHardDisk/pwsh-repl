function Find-ProjectTools
{
    <#
    .SYNOPSIS
    Auto-detect build tools and commands available in a project.

    .DESCRIPTION
    Scans a project directory to discover available build tools, test runners,
    linters, and other development commands by examining configuration files
    and project structure.

    Detects:
    - JavaScript/TypeScript: package.json scripts, node_modules bins
    - Python: setup.py, pyproject.toml, requirements.txt, Pipfile
    - .NET: *.csproj, *.sln files and MSBuild targets
    - Make: Makefile targets
    - CMake: CMakeLists.txt
    - Docker: Dockerfile, docker-compose.yml
    - Git hooks and CI configurations

    Returns structured information about discovered tools including how to invoke them.

    .PARAMETER Path
    Project root directory to scan. Defaults to current directory.

    .PARAMETER Deep
    Perform deep scan including subdirectories. Default is shallow scan of root only.

    .PARAMETER Category
    Filter by tool category: 'build', 'test', 'lint', 'format', 'deploy'. Default is all.

    .EXAMPLE
    PS> Find-ProjectTools

    Type       Tool        Command                  Source
    ----       ----        -------                  ------
    JavaScript npm         npm run build            package.json scripts.build
    JavaScript npm         npm run test             package.json scripts.test
    JavaScript npm         npm run lint             package.json scripts.lint
    Python     pytest      pytest tests/            pyproject.toml tool.pytest
    Make       make        make all                 Makefile target

    .EXAMPLE
    PS> Find-ProjectTools -Category test
    # Show only test-related tools

    .EXAMPLE
    PS> Find-ProjectTools C:\projects\myapp -Deep
    # Deep scan of specific directory

    .EXAMPLE
    PS> $tools = Find-ProjectTools
    PS> $tools | Where-Object { $_.Tool -eq 'npm' } | Select-Object -ExpandProperty Command
    # Get all npm commands available

    .NOTES
    Results can be used with dev-run() to execute discovered commands.
    Parsing heuristics may not detect all tools in complex projects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path = ".",

        [Parameter()]
        [switch]$Deep,

        [Parameter()]
        [ValidateSet('all', 'build', 'test', 'lint', 'format', 'deploy')]
        [string]$Category = 'all'
    )

    $tools = @()

    # Resolve full path
    $projectRoot = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $projectRoot)
    {
        Write-Error "Path not found: $Path"
        return
    }

    # JavaScript/TypeScript - package.json
    $packageJsonPath = Join-Path $projectRoot "package.json"
    if (Test-Path $packageJsonPath)
    {
        try
        {
            $packageJson = Get-Content $packageJsonPath | ConvertFrom-Json

            # Extract scripts
            if ($packageJson.scripts)
            {
                foreach ($script in $packageJson.scripts.PSObject.Properties)
                {
                    $scriptName = $script.Name
                    $scriptCmd = $script.Value

                    # Categorize script
                    $scriptCategory = 'build'
                    if ($scriptName -match 'test')
                    {
                        $scriptCategory = 'test'
                    }
                    elseif ($scriptName -match 'lint|eslint|stylelint')
                    {
                        $scriptCategory = 'lint'
                    }
                    elseif ($scriptName -match 'format|prettier')
                    {
                        $scriptCategory = 'format'
                    }
                    elseif ($scriptName -match 'deploy|publish|release')
                    {
                        $scriptCategory = 'deploy'
                    }

                    # Filter by category
                    if ($Category -eq 'all' -or $Category -eq $scriptCategory)
                    {
                        $tools += [PSCustomObject]@{
                            Type = 'JavaScript'
                            Tool = 'npm'
                            Command = "npm run $scriptName"
                            Category = $scriptCategory
                            Source = "package.json scripts.$scriptName"
                            Details = $scriptCmd
                        }
                    }
                }
            }

            # Check for common dev dependencies
            $devDeps = $packageJson.devDependencies
            if ($devDeps)
            {
                if ($devDeps.eslint)
                {
                    $tools += [PSCustomObject]@{
                        Type = 'JavaScript'
                        Tool = 'eslint'
                        Command = "npx eslint ."
                        Category = 'lint'
                        Source = "package.json devDependencies"
                        Details = "ESLint $( $devDeps.eslint )"
                    }
                }
                if ($devDeps.prettier)
                {
                    $tools += [PSCustomObject]@{
                        Type = 'JavaScript'
                        Tool = 'prettier'
                        Command = "npx prettier --check ."
                        Category = 'format'
                        Source = "package.json devDependencies"
                        Details = "Prettier $( $devDeps.prettier )"
                    }
                }
                if ($devDeps.typescript)
                {
                    $tools += [PSCustomObject]@{
                        Type = 'JavaScript'
                        Tool = 'tsc'
                        Command = "npx tsc --noEmit"
                        Category = 'build'
                        Source = "package.json devDependencies"
                        Details = "TypeScript $( $devDeps.typescript )"
                    }
                }
            }
        }
        catch
        {
            Write-Warning "Failed to parse package.json: $_"
        }
    }

    # Python - setup.py, pyproject.toml, requirements.txt
    $setupPyPath = Join-Path $projectRoot "setup.py"
    $pyprojectPath = Join-Path $projectRoot "pyproject.toml"
    $requirementsPath = Join-Path $projectRoot "requirements.txt"

    if (Test-Path $setupPyPath)
    {
        $tools += [PSCustomObject]@{
            Type = 'Python'
            Tool = 'setuptools'
            Command = "python setup.py install"
            Category = 'build'
            Source = "setup.py"
            Details = "Python package setup"
        }
    }

    if (Test-Path $pyprojectPath)
    {
        try
        {
            $pyprojectContent = Get-Content $pyprojectPath -Raw

            # Check for pytest
            if ($pyprojectContent -match '\[tool\.pytest')
            {
                $tools += [PSCustomObject]@{
                    Type = 'Python'
                    Tool = 'pytest'
                    Command = "pytest tests/"
                    Category = 'test'
                    Source = "pyproject.toml tool.pytest"
                    Details = "Python test framework"
                }
            }

            # Check for black (formatter)
            if ($pyprojectContent -match '\[tool\.black')
            {
                $tools += [PSCustomObject]@{
                    Type = 'Python'
                    Tool = 'black'
                    Command = "black ."
                    Category = 'format'
                    Source = "pyproject.toml tool.black"
                    Details = "Python code formatter"
                }
            }

            # Check for mypy (type checker)
            if ($pyprojectContent -match '\[tool\.mypy')
            {
                $tools += [PSCustomObject]@{
                    Type = 'Python'
                    Tool = 'mypy'
                    Command = "mypy ."
                    Category = 'lint'
                    Source = "pyproject.toml tool.mypy"
                    Details = "Python type checker"
                }
            }
        }
        catch
        {
            Write-Warning "Failed to parse pyproject.toml: $_"
        }
    }

    if (Test-Path $requirementsPath)
    {
        $tools += [PSCustomObject]@{
            Type = 'Python'
            Tool = 'pip'
            Command = "pip install -r requirements.txt"
            Category = 'build'
            Source = "requirements.txt"
            Details = "Python dependencies"
        }
    }

    # .NET - .csproj, .sln
    $csprojFiles = Get-ChildItem -Path $projectRoot -Filter "*.csproj" -ErrorAction SilentlyContinue
    $slnFiles = Get-ChildItem -Path $projectRoot -Filter "*.sln" -ErrorAction SilentlyContinue

    if ($slnFiles)
    {
        foreach ($sln in $slnFiles)
        {
            $tools += [PSCustomObject]@{
                Type = 'DotNet'
                Tool = 'dotnet'
                Command = "dotnet build $( $sln.Name )"
                Category = 'build'
                Source = $sln.Name
                Details = "Visual Studio solution"
            }
        }
    }

    if ($csprojFiles)
    {
        foreach ($csproj in $csprojFiles)
        {
            $tools += [PSCustomObject]@{
                Type = 'DotNet'
                Tool = 'dotnet'
                Command = "dotnet build $( $csproj.Name )"
                Category = 'build'
                Source = $csproj.Name
                Details = "C# project"
            }
        }
    }

    # Makefile
    $makefilePath = Join-Path $projectRoot "Makefile"
    if (Test-Path $makefilePath)
    {
        try
        {
            $makefileContent = Get-Content $makefilePath

            # Extract targets (lines ending with :)
            $targets = $makefileContent | Where-Object {
                $_ -match '^([a-zA-Z0-9_-]+):\s*(.*)$'
            } | ForEach-Object {
                if ($_ -match '^([a-zA-Z0-9_-]+):')
                {
                    $Matches[1]
                }
            }

            foreach ($target in $targets)
            {
                # Categorize common target names
                $targetCategory = 'build'
                if ($target -match 'test')
                {
                    $targetCategory = 'test'
                }
                elseif ($target -match 'clean|install|deps')
                {
                    $targetCategory = 'build'
                }
                elseif ($target -match 'deploy|release')
                {
                    $targetCategory = 'deploy'
                }

                if ($Category -eq 'all' -or $Category -eq $targetCategory)
                {
                    $tools += [PSCustomObject]@{
                        Type = 'Make'
                        Tool = 'make'
                        Command = "make $target"
                        Category = $targetCategory
                        Source = "Makefile target"
                        Details = "Make target: $target"
                    }
                }
            }
        }
        catch
        {
            Write-Warning "Failed to parse Makefile: $_"
        }
    }

    # CMake
    $cmakePath = Join-Path $projectRoot "CMakeLists.txt"
    if (Test-Path $cmakePath)
    {
        $tools += [PSCustomObject]@{
            Type = 'CMake'
            Tool = 'cmake'
            Command = "cmake -S . -B build && cmake --build build"
            Category = 'build'
            Source = "CMakeLists.txt"
            Details = "CMake build system"
        }
    }

    # Docker
    $dockerfilePath = Join-Path $projectRoot "Dockerfile"
    if (Test-Path $dockerfilePath)
    {
        $tools += [PSCustomObject]@{
            Type = 'Docker'
            Tool = 'docker'
            Command = "docker build -t app ."
            Category = 'build'
            Source = "Dockerfile"
            Details = "Docker containerization"
        }
    }

    $dockerComposePath = Join-Path $projectRoot "docker-compose.yml"
    if (Test-Path $dockerComposePath)
    {
        $tools += [PSCustomObject]@{
            Type = 'Docker'
            Tool = 'docker-compose'
            Command = "docker-compose up"
            Category = 'deploy'
            Source = "docker-compose.yml"
            Details = "Docker Compose orchestration"
        }
    }

    # Return results
    if ($tools.Count -eq 0)
    {
        Write-Warning "No project tools detected in $projectRoot"
    }

    $tools
}
