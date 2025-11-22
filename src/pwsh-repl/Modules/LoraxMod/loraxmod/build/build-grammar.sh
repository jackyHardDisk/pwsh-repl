#!/bin/bash
# Build tree-sitter grammar WASM files
# Requires: tree-sitter CLI, emsdk activated

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LORAX_ROOT="$(dirname "$SCRIPT_DIR")"
GRAMMARS_DIR="$LORAX_ROOT/grammars"
TEMP_DIR="$LORAX_ROOT/build/temp"

echo "loraxMod Grammar Builder"
echo "======================="
echo ""

# Check for tree-sitter CLI
if ! command -v tree-sitter &> /dev/null; then
    echo "ERROR: tree-sitter CLI not found"
    echo "Install: npm install -g tree-sitter-cli@0.25.9"
    exit 1
fi

# Find emsdk installation
EMSDK_DIR=""
if [ -d "/c/tools/emsdk" ]; then
    EMSDK_DIR="/c/tools/emsdk"
elif [ -d "/usr/local/emsdk" ]; then
    EMSDK_DIR="/usr/local/emsdk"
elif [ -d "$HOME/emsdk" ]; then
    EMSDK_DIR="$HOME/emsdk"
elif [ -n "$EMSDK_ROOT" ] && [ -d "$EMSDK_ROOT" ]; then
    EMSDK_DIR="$EMSDK_ROOT"
fi

if [ -z "$EMSDK_DIR" ]; then
    echo "ERROR: emsdk not found"
    echo "Install to one of these locations:"
    echo "  Windows: C:\\tools\\emsdk"
    echo "  Linux:   /usr/local/emsdk or ~/emsdk"
    echo "  Or set EMSDK_ROOT environment variable"
    echo ""
    echo "Installation:"
    echo "  git clone https://github.com/emscripten-core/emsdk.git [location]"
    echo "  cd emsdk"
    echo "  ./emsdk install latest"
    echo "  ./emsdk activate latest"
    exit 1
fi

echo "Using emsdk from: $EMSDK_DIR"

# Check if emcc is available (emsdk already activated)
if command -v emcc &> /dev/null; then
    echo "✓ emcc found - emsdk already activated"
else
    echo "Activating emsdk..."
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        # On Windows, try to activate via PowerShell
        echo "Running: powershell.exe -ExecutionPolicy Bypass -File \"$EMSDK_DIR/emsdk_env.ps1\""
        powershell.exe -ExecutionPolicy Bypass -File "$EMSDK_DIR/emsdk_env.ps1"

        # Check if activation worked
        if ! command -v emcc &> /dev/null; then
            echo ""
            echo "ERROR: emcc not found after activation"
            echo "Please activate emsdk manually before running this script:"
            echo "  powershell.exe -ExecutionPolicy Bypass -File C:\\tools\\emsdk\\emsdk_env.ps1"
            exit 1
        fi
    else
        source "$EMSDK_DIR/emsdk_env.sh"
    fi
fi

# Create temp directory
mkdir -p "$TEMP_DIR"

# Grammar repository URLs
declare -A GRAMMARS=(
    ["javascript"]="https://github.com/tree-sitter/tree-sitter-javascript"
    ["python"]="https://github.com/tree-sitter/tree-sitter-python"
    ["bash"]="https://github.com/tree-sitter/tree-sitter-bash"
    ["powershell"]="https://github.com/Airbus-CERT/tree-sitter-powershell"
    ["r"]="https://github.com/r-lib/tree-sitter-r"
    ["c-sharp"]="https://github.com/tree-sitter/tree-sitter-c-sharp"
    ["rust"]="https://github.com/tree-sitter/tree-sitter-rust"
    ["c"]="https://github.com/tree-sitter/tree-sitter-c"
    ["css"]="https://github.com/tree-sitter/tree-sitter-css"
    ["fortran"]="https://github.com/stadelmanma/tree-sitter-fortran"
)

# Export function names (most use _tree_sitter_<lang>, powershell uses lowercase)
declare -A EXPORTS=(
    ["javascript"]="_tree_sitter_javascript"
    ["python"]="_tree_sitter_python"
    ["bash"]="_tree_sitter_bash"
    ["powershell"]="_tree_sitter_powershell"
    ["r"]="_tree_sitter_r"
    ["c-sharp"]="_tree_sitter_c_sharp"
    ["rust"]="_tree_sitter_rust"
    ["c"]="_tree_sitter_c"
    ["css"]="_tree_sitter_css"
    ["fortran"]="_tree_sitter_fortran"
)

# Build each grammar
for LANG in "${!GRAMMARS[@]}"; do
    echo "Building $LANG grammar..."

    REPO_URL="${GRAMMARS[$LANG]}"
    EXPORT_FUNC="${EXPORTS[$LANG]}"
    OUTPUT_FILE="tree-sitter-$LANG.wasm"

    cd "$TEMP_DIR"

    # Clone or update
    if [ -d "tree-sitter-$LANG" ]; then
        echo "  Updating existing clone..."
        cd "tree-sitter-$LANG"
        git pull
    else
        echo "  Cloning $REPO_URL..."
        git clone "$REPO_URL" "tree-sitter-$LANG"
        cd "tree-sitter-$LANG"
    fi

    # Generate parser
    echo "  Generating parser..."
    tree-sitter generate

    # Compile to WASM
    echo "  Compiling to WASM..."
    if [ -f "src/scanner.c" ]; then
        emcc src/parser.c src/scanner.c -o "$OUTPUT_FILE" \
            -I./src -Os -fPIC -s WASM=1 -s SIDE_MODULE=2 \
            -s EXPORTED_FUNCTIONS="['$EXPORT_FUNC']"
    elif [ -f "src/scanner.cc" ]; then
        emcc src/parser.c src/scanner.cc -o "$OUTPUT_FILE" \
            -I./src -Os -fPIC -s WASM=1 -s SIDE_MODULE=2 \
            -s EXPORTED_FUNCTIONS="['$EXPORT_FUNC']"
    else
        emcc src/parser.c -o "$OUTPUT_FILE" \
            -I./src -Os -fPIC -s WASM=1 -s SIDE_MODULE=2 \
            -s EXPORTED_FUNCTIONS="['$EXPORT_FUNC']"
    fi

    # Copy to grammars directory
    echo "  Copying to $GRAMMARS_DIR..."
    cp "$OUTPUT_FILE" "$GRAMMARS_DIR/"

    echo "  $LANG grammar built successfully!"
    echo ""
done

echo "All grammars built successfully!"
echo "Output: $GRAMMARS_DIR"
