<#
.SYNOPSIS
Interactive tree-sitter AST navigation via Node.js REPL

.DESCRIPTION
PowerShell wrappers for exploring tree-sitter AST nodes interactively.
Uses Node.js REPL with loraxmod for direct AST manipulation.

.NOTES
Requires Node.js (optional peer dependency)
loraxmod bundled in module directory
#>

# Store module root at load time (works in background sessions)
$script:ModuleRoot = $PSScriptRoot
$script:LoraxPath = "$script:ModuleRoot/loraxmod/lib/index.js" -replace '\\', '/'

function Start-TreeSitterSession {
    <#
    .SYNOPSIS
    Start interactive Node.js REPL with tree-sitter loaded

    .DESCRIPTION
    Initializes Node.js REPL session with loraxmod pre-loaded and parser initialized.
    Sets up global variables: parser, tree, root for immediate navigation.

    .PARAMETER Language
    Programming language to parse (c, python, javascript, etc.)

    .PARAMETER Code
    Source code to parse initially

    .PARAMETER FilePath
    Path to source file to parse

    .EXAMPLE
    Start-TreeSitterSession -Language c -Code 'int main() { printf("hi"); }'
    Starts REPL with C code parsed, ready to explore

    .EXAMPLE
    Start-TreeSitterSession -Language python -FilePath script.py
    Parse Python file and start interactive session

    .NOTES
    In the REPL you can:
    - root.type - Get node type
    - root.childCount - Count children
    - root.child(0) - Get first child
    - root.childForFieldName('function') - Get field
    - root.parent - Get parent node
    - root.startPosition - Get position {row, column}
    - root.text - Get source text
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('c', 'cpp', 'csharp', 'python', 'javascript', 'typescript', 'bash', 'powershell', 'r', 'rust', 'css', 'fortran')]
        [string]$Language,

        [Parameter(ParameterSetName='Code')]
        [string]$Code,

        [Parameter(ParameterSetName='File')]
        [string]$FilePath
    )

    # Get code from file if specified
    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path $FilePath)) {
            Write-Error "File not found: $FilePath"
            return
        }
        $Code = Get-Content $FilePath -Raw
    }

    # Escape code for JavaScript string
    $escapedCode = $Code -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r'

    # Get lorax path from module scope
    $loraxPath = $script:LoraxPath

    # Generate initialization script
    $initScript = @"
const lorax = require('$loraxPath');

console.log('Initializing tree-sitter...');
(async () => {
    await lorax.initParser();
    const parser = lorax.getParser();
    const lang = await lorax.loadLanguage('$Language');

    if (!lang) {
        console.error('Failed to load language: $Language');
        process.exit(1);
    }

    parser.setLanguage(lang);

    const code = "$escapedCode";
    const tree = parser.parse(code);
    const root = tree.rootNode;

    // Make available globally
    global.lorax = lorax;
    global.parser = parser;
    global.tree = tree;
    global.root = root;
    global.code = code;

    console.log('');
    console.log('=== Tree-sitter REPL Ready ===');
    console.log('Language: $Language');
    console.log('Root type:', root.type);
    console.log('Child count:', root.childCount);
    console.log('');
    console.log('Available globals:');
    console.log('  lorax  - loraxmod API');
    console.log('  parser - Parser instance');
    console.log('  tree   - Parsed tree');
    console.log('  root   - Root node');
    console.log('  code   - Source code');
    console.log('');
    console.log('Common operations:');
    console.log('  root.type - Node type');
    console.log('  root.childCount - Number of children');
    console.log('  root.child(0) - Get first child');
    console.log('  root.childForFieldName(\"function\") - Get field');
    console.log('  root.parent - Get parent');
    console.log('  root.startPosition - Position {row, column}');
    console.log('  root.startIndex - Byte offset');
    console.log('  root.text - Source text');
    console.log('  root.namedChildCount - Named children only');
    console.log('  root.namedChild(0) - Get named child');
    console.log('');
    console.log('Type .exit to quit');
    console.log('');

    // Start REPL
    const repl = require('repl');
    const replServer = repl.start({
        prompt: 'ts> ',
        useGlobal: true
    });
})();
"@

    # Write init script to temp file
    $tempScript = Join-Path $env:TEMP "treesitter-init-$(Get-Random).js"
    $initScript | Out-File -FilePath $tempScript -Encoding utf8 -NoNewline

    try {
        # Start Node.js with init script
        & node $tempScript
    } finally {
        # Cleanup
        if (Test-Path $tempScript) {
            Remove-Item $tempScript -Force
        }
    }
}

function Invoke-TreeSitterQuery {
    <#
    .SYNOPSIS
    Run tree-sitter query pattern and return matches

    .DESCRIPTION
    Executes tree-sitter query pattern against code and returns JSON results.
    Non-interactive - use for scripting and automation.

    .PARAMETER Language
    Programming language

    .PARAMETER Code
    Source code to query

    .PARAMETER Pattern
    Tree-sitter query pattern (e.g., "(call_expression function: (identifier) @func)")

    .PARAMETER FilePath
    Path to source file to query

    .EXAMPLE
    Invoke-TreeSitterQuery -Language c -Code 'int main() { printf("hi"); }' -Pattern '(call_expression function: (identifier) @func)'
    Find all function calls in C code

    .EXAMPLE
    Invoke-TreeSitterQuery -Language python -FilePath script.py -Pattern '(function_definition name: (identifier) @name)'
    Extract all function names from Python file

    .NOTES
    Returns JSON object with matches array containing captured nodes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('c', 'cpp', 'csharp', 'python', 'javascript', 'typescript', 'bash', 'powershell', 'r', 'rust', 'css', 'fortran')]
        [string]$Language,

        [Parameter(ParameterSetName='Code', Mandatory=$true)]
        [string]$Code,

        [Parameter(ParameterSetName='File', Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string]$Pattern
    )

    # Get code from file if specified
    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path $FilePath)) {
            Write-Error "File not found: $FilePath"
            return
        }
        $Code = Get-Content $FilePath -Raw
    }

    # Escape for JSON
    $escapedCode = $Code -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r' -replace "`t", '\t'
    $escapedPattern = $Pattern -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n'

    # Get lorax path from module scope
    $loraxPath = $script:LoraxPath

    # Create query script
    $queryScript = @"
const lorax = require('$loraxPath');

(async () => {
    await lorax.initParser();
    const parser = lorax.getParser();
    const lang = await lorax.loadLanguage('$Language');

    if (!lang) {
        console.error(JSON.stringify({error: 'Failed to load language: $Language'}));
        process.exit(1);
    }

    parser.setLanguage(lang);

    const code = "$escapedCode";
    const tree = parser.parse(code);
    const query = lang.query("$escapedPattern");
    const matches = query.matches(tree.rootNode);

    const results = {
        language: '$Language',
        pattern: "$escapedPattern",
        matches: matches.map(match => ({
            pattern: match.pattern,
            captures: match.captures.map(capture => ({
                name: capture.name,
                text: capture.node.text,
                type: capture.node.type,
                startLine: capture.node.startPosition.row + 1,
                startColumn: capture.node.startPosition.column + 1,
                endLine: capture.node.endPosition.row + 1,
                endColumn: capture.node.endPosition.column + 1,
                startIndex: capture.node.startIndex,
                endIndex: capture.node.endIndex
            }))
        }))
    };

    console.log(JSON.stringify(results, null, 2));
})();
"@

    # Write query script to temp file
    $tempScript = Join-Path $env:TEMP "treesitter-query-$(Get-Random).js"
    $queryScript | Out-File -FilePath $tempScript -Encoding utf8 -NoNewline

    try {
        # Execute and capture output
        $output = & node $tempScript

        # Parse JSON output
        $output | ConvertFrom-Json
    } finally {
        # Cleanup
        if (Test-Path $tempScript) {
            Remove-Item $tempScript -Force
        }
    }
}

function Find-FunctionCalls {
    <#
    .SYNOPSIS
    Find function calls with context (parent function, arguments, line numbers)

    .DESCRIPTION
    Extracts all function calls from source code with full context information.
    Similar to Chandra POSIX analysis pattern. Returns function name, location,
    parent function, arguments, and source line.

    .PARAMETER Language
    Programming language

    .PARAMETER Code
    Source code to analyze

    .PARAMETER FilePath
    Path to source file to analyze

    .PARAMETER FunctionNames
    Optional filter - only return calls to these functions

    .EXAMPLE
    Find-FunctionCalls -Language c -FilePath main.c
    Find all function calls in C file

    .EXAMPLE
    Find-FunctionCalls -Language c -FilePath main.c -FunctionNames @('printf', 'malloc', 'free')
    Find only POSIX memory/IO functions

    .EXAMPLE
    Find-FunctionCalls -Language python -Code 'import os; os.path.join("a", "b")'
    Find function calls in Python code

    .NOTES
    Returns objects with:
    - function: function name
    - line: line number (1-indexed)
    - column: column number
    - parentFunction: containing function name (or 'global')
    - arguments: array of argument text
    - codeLine: full source line
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('c', 'cpp', 'csharp', 'python', 'javascript', 'typescript', 'bash', 'powershell', 'r', 'rust', 'css', 'fortran')]
        [string]$Language,

        [Parameter(ParameterSetName='Code')]
        [string]$Code,

        [Parameter(ParameterSetName='File')]
        [string]$FilePath,

        [Parameter()]
        [string[]]$FunctionNames
    )

    # Get code from file
    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path $FilePath)) {
            Write-Error "File not found: $FilePath"
            return
        }
        $Code = Get-Content $FilePath -Raw
    }

    # Escape for JSON
    $escapedCode = $Code -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r'
    $filterJson = if ($FunctionNames) { ConvertTo-Json $FunctionNames -Compress } else { 'null' }

    # Get lorax path from module scope
    $loraxPath = $script:LoraxPath

    $analysisScript = @"
const lorax = require('$loraxPath');

(async () => {
    await lorax.initParser();
    const parser = lorax.getParser();
    const lang = await lorax.loadLanguage('$Language');
    parser.setLanguage(lang);

    const code = "$escapedCode";
    const tree = parser.parse(code);
    const lines = code.split('\n');
    const filterFuncs = $filterJson;

    const results = [];

    function findFunctionName(node) {
        if (node.type === 'identifier') return node;
        for (let i = 0; i < node.childCount; i++) {
            const found = findFunctionName(node.child(i));
            if (found) return found;
        }
        return null;
    }

    function traverse(node) {
        if (node.type === 'call_expression' || node.type === 'call') {
            const funcNode = node.childForFieldName('function');
            if (funcNode) {
                const funcName = funcNode.text;

                // Apply filter if specified
                if (filterFuncs && !filterFuncs.includes(funcName)) {
                    // Skip this function
                } else {
                    // Get arguments
                    const argsNode = node.childForFieldName('arguments');
                    const args = [];
                    if (argsNode) {
                        for (let i = 0; i < argsNode.namedChildCount; i++) {
                            const argNode = argsNode.namedChild(i);
                            args.push(argNode.text.length > 60 ? argNode.text.substring(0, 57) + '...' : argNode.text);
                        }
                    }

                    // Find parent function
                    let parentFunc = 'global';
                    let current = node.parent;
                    while (current) {
                        if (current.type === 'function_definition' || current.type === 'function_declaration') {
                            const declarator = current.childForFieldName('declarator') || current.childForFieldName('name');
                            if (declarator) {
                                const nameNode = findFunctionName(declarator);
                                if (nameNode) parentFunc = nameNode.text;
                            }
                            break;
                        }
                        current = current.parent;
                    }

                    results.push({
                        function: funcName,
                        line: node.startPosition.row + 1,
                        column: node.startPosition.column + 1,
                        parentFunction: parentFunc,
                        arguments: args,
                        codeLine: lines[node.startPosition.row]?.trim() || ''
                    });
                }
            }
        }

        for (let i = 0; i < node.childCount; i++) {
            traverse(node.child(i));
        }
    }

    traverse(tree.rootNode);
    console.log(JSON.stringify(results, null, 2));
})();
"@

    $tempScript = Join-Path $env:TEMP "find-calls-$(Get-Random).js"
    $analysisScript | Out-File -FilePath $tempScript -Encoding utf8 -NoNewline

    try {
        # Use node directly - output goes to stdout naturally
        $output = & node $tempScript
        $output | ConvertFrom-Json
    } finally {
        if (Test-Path $tempScript) { Remove-Item $tempScript -Force }
    }
}

function Get-IncludeDependencies {
    <#
    .SYNOPSIS
    Parse include directives from C/C++ files

    .DESCRIPTION
    Extracts #include directives and categorizes them as system, local, or POSIX headers.
    Based on Chandra include dependency analysis pattern.

    .PARAMETER FilePath
    Path to C/C++ source or header file

    .PARAMETER Code
    Source code to analyze

    .EXAMPLE
    Get-IncludeDependencies -FilePath main.c
    Parse includes from C file

    .EXAMPLE
    Get-IncludeDependencies -FilePath header.h | Select-Object -ExpandProperty posix
    Get only POSIX headers

    .NOTES
    Returns object with:
    - system: array of system includes (from <header.h>)
    - local: array of local includes (from "header.h")
    - posix: array of POSIX headers
    #>
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName='File', Mandatory=$true)]
        [string]$FilePath,

        [Parameter(ParameterSetName='Code')]
        [string]$Code
    )

    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path $FilePath)) {
            Write-Error "File not found: $FilePath"
            return
        }
        $Code = Get-Content $FilePath -Raw
    }

    $escapedCode = $Code -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r'

    $includeScript = @"
const lorax = require('$loraxPath');

(async () => {
    await lorax.initParser();
    const parser = lorax.getParser();
    const lang = await lorax.loadLanguage('c');
    parser.setLanguage(lang);

    const code = "$escapedCode";
    const tree = parser.parse(code);

    const posixHeaders = new Set(['unistd.h', 'pwd.h', 'grp.h', 'glob.h', 'strings.h', 'sys/socket.h', 'netinet/in.h', 'arpa/inet.h']);
    const includes = { system: [], local: [], posix: [] };

    function traverse(node) {
        if (node.type === 'preproc_include') {
            const pathNode = node.childForFieldName('path');
            if (pathNode) {
                const isSystem = pathNode.type === 'system_lib_string';
                const header = pathNode.text.slice(1, -1); // Remove <> or ""

                if (isSystem) {
                    includes.system.push(header);
                    if (posixHeaders.has(header)) {
                        includes.posix.push(header);
                    }
                } else {
                    includes.local.push(header);
                }
            }
        }

        for (let i = 0; i < node.childCount; i++) {
            traverse(node.child(i));
        }
    }

    traverse(tree.rootNode);
    console.log(JSON.stringify(includes, null, 2));
})();
"@

    $tempScript = Join-Path $env:TEMP "includes-$(Get-Random).js"
    $includeScript | Out-File -FilePath $tempScript -Encoding utf8 -NoNewline

    try {
        $output = & node $tempScript
        $output | ConvertFrom-Json
    } finally {
        if (Test-Path $tempScript) { Remove-Item $tempScript -Force }
    }
}

function Get-ASTNode {
    <#
    .SYNOPSIS
    Navigate to specific AST node by path

    .DESCRIPTION
    Traverses AST tree using node path (e.g., "0.1.2" means root.child(0).child(1).child(2)).
    Returns node information including type, text, position, and available fields.

    .PARAMETER Language
    Programming language

    .PARAMETER Code
    Source code to parse

    .PARAMETER FilePath
    Path to source file

    .PARAMETER NodePath
    Dot-separated path to node (e.g., "0.1.2")

    .EXAMPLE
    Get-ASTNode -Language c -Code 'int main() {}' -NodePath "0"
    Get first child of root

    .EXAMPLE
    Get-ASTNode -Language python -FilePath script.py -NodePath "0.1.2"
    Navigate to specific node in Python file

    .NOTES
    Returns object with node details: type, text, position, fields, childCount
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('c', 'cpp', 'csharp', 'python', 'javascript', 'typescript', 'bash', 'powershell', 'r', 'rust', 'css', 'fortran')]
        [string]$Language,

        [Parameter(ParameterSetName='Code')]
        [string]$Code,

        [Parameter(ParameterSetName='File')]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string]$NodePath
    )

    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path $FilePath)) {
            Write-Error "File not found: $FilePath"
            return
        }
        $Code = Get-Content $FilePath -Raw
    }

    $escapedCode = $Code -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r'

    $navScript = @"
const lorax = require('$loraxPath');

(async () => {
    await lorax.initParser();
    const parser = lorax.getParser();
    const lang = await lorax.loadLanguage('$Language');
    parser.setLanguage(lang);

    const code = "$escapedCode";
    const tree = parser.parse(code);
    const path = "$NodePath".split('.').filter(x => x);

    let node = tree.rootNode;
    for (const index of path) {
        const i = parseInt(index);
        if (isNaN(i) || i >= node.childCount) {
            console.log(JSON.stringify({error: 'Invalid path: child index out of range'}));
            process.exit(1);
        }
        node = node.child(i);
    }

    // Extract fields
    const fields = {};
    for (let i = 0; i < node.childCount; i++) {
        const child = node.child(i);
        if (child.fieldName) {
            fields[child.fieldName] = { type: child.type, text: child.text.substring(0, 50) };
        }
    }

    const result = {
        type: node.type,
        text: node.text.length > 200 ? node.text.substring(0, 197) + '...' : node.text,
        startLine: node.startPosition.row + 1,
        endLine: node.endPosition.row + 1,
        childCount: node.childCount,
        namedChildCount: node.namedChildCount,
        fields: Object.keys(fields).length > 0 ? fields : undefined,
        parent: node.parent ? { type: node.parent.type } : undefined
    };

    console.log(JSON.stringify(result, null, 2));
})();
"@

    $tempScript = Join-Path $env:TEMP "get-node-$(Get-Random).js"
    $navScript | Out-File -FilePath $tempScript -Encoding utf8 -NoNewline

    try {
        $output = & node $tempScript
        $output | ConvertFrom-Json
    } finally {
        if (Test-Path $tempScript) { Remove-Item $tempScript -Force }
    }
}

function Show-ASTTree {
    <#
    .SYNOPSIS
    Display AST tree structure in readable format

    .DESCRIPTION
    Pretty-prints tree-sitter AST with indentation showing hierarchy.
    Useful for understanding code structure and exploring available nodes.

    .PARAMETER Language
    Programming language

    .PARAMETER Code
    Source code to parse

    .PARAMETER FilePath
    Path to source file

    .PARAMETER MaxDepth
    Maximum tree depth to display (default: 3)

    .PARAMETER ShowText
    Include node text in output

    .EXAMPLE
    Show-ASTTree -Language c -Code 'int main() { return 0; }' -MaxDepth 4
    Display C code structure

    .EXAMPLE
    Show-ASTTree -Language python -FilePath script.py -ShowText
    Show Python file structure with text

    .NOTES
    Output format:
    [type] text (line:col)
      [child_type] child_text
        [grandchild_type]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('c', 'cpp', 'csharp', 'python', 'javascript', 'typescript', 'bash', 'powershell', 'r', 'rust', 'css', 'fortran')]
        [string]$Language,

        [Parameter(ParameterSetName='Code')]
        [string]$Code,

        [Parameter(ParameterSetName='File')]
        [string]$FilePath,

        [Parameter()]
        [int]$MaxDepth = 3,

        [Parameter()]
        [switch]$ShowText
    )

    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path $FilePath)) {
            Write-Error "File not found: $FilePath"
            return
        }
        $Code = Get-Content $FilePath -Raw
    }

    $escapedCode = $Code -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r'
    $showTextFlag = if ($ShowText) { 'true' } else { 'false' }

    $treeScript = @"
const lorax = require('$loraxPath');

(async () => {
    await lorax.initParser();
    const parser = lorax.getParser();
    const lang = await lorax.loadLanguage('$Language');
    parser.setLanguage(lang);

    const code = "$escapedCode";
    const tree = parser.parse(code);
    const maxDepth = $MaxDepth;
    const showText = $showTextFlag;

    function display(node, depth = 0) {
        if (depth > maxDepth) return;

        const indent = '  '.repeat(depth);
        const pos = node.startPosition.row + 1 + ':' + (node.startPosition.column + 1);
        const text = showText && node.text.length < 40 ? ' ' + node.text.replace(/\n/g, '\\n') : '';

        console.log(indent + '[' + node.type + ']' + text + ' (' + pos + ')');

        for (let i = 0; i < node.childCount; i++) {
            display(node.child(i), depth + 1);
        }
    }

    display(tree.rootNode);
})();
"@

    $tempScript = Join-Path $env:TEMP "show-tree-$(Get-Random).js"
    $treeScript | Out-File -FilePath $tempScript -Encoding utf8 -NoNewline

    try {
        & node $tempScript
    } finally {
        if (Test-Path $tempScript) { Remove-Item $tempScript -Force }
    }
}

function Export-ASTJson {
    <#
    .SYNOPSIS
    Export complete AST to JSON file

    .DESCRIPTION
    Dumps full AST tree to JSON file for offline analysis, archival, or integration
    with other tools. Includes node types, positions, text, and field information.

    .PARAMETER Language
    Programming language

    .PARAMETER Code
    Source code to parse

    .PARAMETER FilePath
    Path to source file to parse

    .PARAMETER OutFile
    Output JSON file path

    .PARAMETER MaxDepth
    Maximum tree depth to export (default: 10)

    .PARAMETER IncludeFields
    Include field information in output

    .EXAMPLE
    Export-ASTJson -Language c -FilePath main.c -OutFile main.ast.json
    Export C file AST to JSON

    .EXAMPLE
    Export-ASTJson -Language python -FilePath script.py -OutFile ast.json -MaxDepth 5 -IncludeFields
    Export Python AST with limited depth and fields

    .NOTES
    Output JSON contains nested node structure with type, position, text, children
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('c', 'cpp', 'csharp', 'python', 'javascript', 'typescript', 'bash', 'powershell', 'r', 'rust', 'css', 'fortran')]
        [string]$Language,

        [Parameter(ParameterSetName='Code')]
        [string]$Code,

        [Parameter(ParameterSetName='File')]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string]$OutFile,

        [Parameter()]
        [int]$MaxDepth = 10,

        [Parameter()]
        [switch]$IncludeFields
    )

    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path $FilePath)) {
            Write-Error "File not found: $FilePath"
            return
        }
        $Code = Get-Content $FilePath -Raw
    }

    $escapedCode = $Code -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r'
    $includeFieldsFlag = if ($IncludeFields) { 'true' } else { 'false' }

    $exportScript = @"
const lorax = require('$loraxPath');
const fs = require('fs');

(async () => {
    await lorax.initParser();
    const parser = lorax.getParser();
    const lang = await lorax.loadLanguage('$Language');
    parser.setLanguage(lang);

    const code = "$escapedCode";
    const tree = parser.parse(code);
    const maxDepth = $MaxDepth;
    const includeFields = $includeFieldsFlag;

    function toJson(node, depth = 0) {
        if (depth > maxDepth) {
            return { type: node.type, truncated: true };
        }

        const result = {
            type: node.type,
            startLine: node.startPosition.row + 1,
            startColumn: node.startPosition.column + 1,
            endLine: node.endPosition.row + 1,
            endColumn: node.endPosition.column + 1,
            startIndex: node.startIndex,
            endIndex: node.endIndex,
            text: node.text.length > 100 ? node.text.substring(0, 97) + '...' : node.text
        };

        if (includeFields && node.childCount > 0) {
            const fields = {};
            for (let i = 0; i < node.childCount; i++) {
                const child = node.child(i);
                if (child.fieldName) {
                    fields[child.fieldName] = { type: child.type, text: child.text.substring(0, 50) };
                }
            }
            if (Object.keys(fields).length > 0) {
                result.fields = fields;
            }
        }

        if (node.childCount > 0) {
            result.children = [];
            for (let i = 0; i < node.childCount; i++) {
                result.children.push(toJson(node.child(i), depth + 1));
            }
        }

        return result;
    }

    const ast = {
        language: '$Language',
        rootNode: toJson(tree.rootNode)
    };

    fs.writeFileSync('$($OutFile -replace '\\', '\\')', JSON.stringify(ast, null, 2));
    console.log('AST exported to: $OutFile');
})();
"@

    $tempScript = Join-Path $env:TEMP "export-ast-$(Get-Random).js"
    $exportScript | Out-File -FilePath $tempScript -Encoding utf8 -NoNewline

    try {
        & node $tempScript
    } finally {
        if (Test-Path $tempScript) { Remove-Item $tempScript -Force }
    }
}

function Get-NodesByType {
    <#
    .SYNOPSIS
    Find all AST nodes of specific type

    .DESCRIPTION
    Searches AST tree for all nodes matching specified type(s).
    Quick filter without writing tree-sitter query patterns.

    .PARAMETER Language
    Programming language

    .PARAMETER Code
    Source code to parse

    .PARAMETER FilePath
    Path to source file

    .PARAMETER NodeType
    Node type(s) to find (e.g., 'function_definition', 'call_expression')

    .EXAMPLE
    Get-NodesByType -Language c -FilePath main.c -NodeType 'function_definition'
    Find all function definitions

    .EXAMPLE
    Get-NodesByType -Language python -Code $script -NodeType 'call', 'import_statement'
    Find calls and imports

    .NOTES
    Returns array of nodes with type, text, line, and parent information
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('c', 'cpp', 'csharp', 'python', 'javascript', 'typescript', 'bash', 'powershell', 'r', 'rust', 'css', 'fortran')]
        [string]$Language,

        [Parameter(ParameterSetName='Code')]
        [string]$Code,

        [Parameter(ParameterSetName='File')]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string[]]$NodeType
    )

    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path $FilePath)) {
            Write-Error "File not found: $FilePath"
            return
        }
        $Code = Get-Content $FilePath -Raw
    }

    $escapedCode = $Code -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r'
    $typesJson = ConvertTo-Json $NodeType -Compress

    $filterScript = @"
const lorax = require('$loraxPath');

(async () => {
    await lorax.initParser();
    const parser = lorax.getParser();
    const lang = await lorax.loadLanguage('$Language');
    parser.setLanguage(lang);

    const code = "$escapedCode";
    const tree = parser.parse(code);
    const targetTypes = $typesJson;

    const results = [];

    function traverse(node) {
        if (targetTypes.includes(node.type)) {
            results.push({
                type: node.type,
                text: node.text.length > 100 ? node.text.substring(0, 97) + '...' : node.text,
                startLine: node.startPosition.row + 1,
                endLine: node.endPosition.row + 1,
                startIndex: node.startIndex,
                endIndex: node.endIndex,
                parent: node.parent ? { type: node.parent.type } : undefined
            });
        }

        for (let i = 0; i < node.childCount; i++) {
            traverse(node.child(i));
        }
    }

    traverse(tree.rootNode);
    console.log(JSON.stringify(results, null, 2));
})();
"@

    $tempScript = Join-Path $env:TEMP "filter-nodes-$(Get-Random).js"
    $filterScript | Out-File -FilePath $tempScript -Encoding utf8 -NoNewline

    try {
        $output = & node $tempScript
        $output | ConvertFrom-Json
    } finally {
        if (Test-Path $tempScript) { Remove-Item $tempScript -Force }
    }
}

# Functions exported via manifest (LoraxMod.psd1)
# No Export-ModuleMember needed when using FunctionsToExport in manifest
