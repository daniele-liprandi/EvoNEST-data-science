#!/usr/bin/env bash
# EvoNEST Data Science Setup Script for Linux/Mac
# Double-click this file to run the setup (if your system supports it)
# Or run from terminal: bash setup.sh [--uninstall|-u]

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the script directory
cd "$SCRIPT_DIR"

# Run the main setup script, passing along any arguments
bash setup/setup_language.sh "$@"
