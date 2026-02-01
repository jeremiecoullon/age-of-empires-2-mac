#!/bin/bash
# Run all tests with Godot project validation
# Usage: ./run_tests.sh

set -e

# Detect Godot path
if [[ "$OSTYPE" == "darwin"* ]]; then
    GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
    GODOT="godot"
fi

# Get script directory (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Step 1: Validating Godot project import ==="
if ! "$GODOT" --headless --import --path "$SCRIPT_DIR" 2>&1; then
    echo ""
    echo "ERROR: Godot project import failed!"
    echo "Check for syntax errors in .tscn/.tres files or missing dependencies."
    exit 1
fi
echo "Project import: OK"
echo ""

echo "=== Step 2: Running tests ==="
"$GODOT" --headless --path "$SCRIPT_DIR" tests/test_scene.tscn
