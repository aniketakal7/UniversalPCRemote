#!/bin/bash
# Universal PC Remote™ — Mac Companion Launcher
# Double-click this file in macOS Finder to start the server!

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "========================================================"
echo "  Universal PC Remote™ — macOS Companion Server"
echo "  by Aniket Akal"
echo "========================================================"
echo ""

# Prefer .NET standalone executable if present
if [ -f "$DIR/UniversalPCRemoteMac" ]; then
    chmod +x "$DIR/UniversalPCRemoteMac"
    "$DIR/UniversalPCRemoteMac"
    exit 0
fi

# Fallback to pure Python 3 companion (works on 100% of Macs)
if command -v python3 &>/dev/null; then
    python3 "$DIR/UniversalPCRemote_Mac.py"
    exit 0
fi

echo "Error: Neither .NET nor python3 was found on this Mac."
echo "Please install Python 3 or .NET 8."
read -p "Press enter to exit..."
