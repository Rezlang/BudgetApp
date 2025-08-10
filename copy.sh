#!/usr/bin/env zsh
# Recursively collect all .swift files under the current directory,
# label each section with its file path, and copy the combined text to the clipboard.

set -euo pipefail

# If you want to exclude common build/vendor folders, uncomment the "EXCLUDES" block below.
# EXCLUDES=(
#   -path "./.git/*" -o
#   -path "./DerivedData/*" -o
#   -path "./.build/*" -o
#   -path "./Pods/*"
# )

# Build the find command (handles spaces/newlines safely via -print0)
# If EXCLUDES are used, this uses -prune to skip them.
if false; then
  :
  # placeholder to keep structure clear
fi

# Without excludes (default):
find . -type f -name '*.swift' -print0 \
| while IFS= read -r -d '' file; do
    printf '===== FILE: %s =====\n' "$file"
    cat -- "$file"
    printf '\n\n'
  done \
| pbcopy

# After running this script from your project root, your clipboard will contain:
# ===== FILE: ./Path/To/File.swift =====
# <file contents>
# (blank line)
# ...repeated for every .swift file

