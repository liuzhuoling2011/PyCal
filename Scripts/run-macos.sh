#!/bin/bash
# Build PyCal.app, copy it to Applications, and open it. For local development.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
app_dir="$root_dir/Build/PyCal.app"

"$script_dir/build-macos-app.sh"

if [[ ! -d "$app_dir" ]]; then
    echo "Build did not produce $app_dir" >&2
    exit 1
fi

installed_app_dir="/Applications/PyCal.app"
if [[ ! -w /Applications ]]; then
    mkdir -p "$HOME/Applications"
    installed_app_dir="$HOME/Applications/PyCal.app"
    echo "/Applications is not writable; installing to $installed_app_dir"
fi

echo "Installing $installed_app_dir"
rm -rf "$installed_app_dir"
ditto --norsrc --noqtn "$app_dir" "$installed_app_dir"
if command -v xattr >/dev/null 2>&1; then
    xattr -dr com.apple.quarantine "$installed_app_dir" 2>/dev/null || true
fi

echo "Opening $installed_app_dir"
open "$installed_app_dir"
