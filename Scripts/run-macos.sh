#!/bin/zsh
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$root_dir/Build/PyCal.app"
installed_app_dir="/Applications/PyCal.app"
binary="$root_dir/.build/arm64-apple-macosx/release/PyCal"
resource_bundle="$root_dir/.build/arm64-apple-macosx/release/PyCal_PyCal.bundle"

echo "Building PyCal (release)…"
swift build -c release --package-path "$root_dir"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
mkdir -p "$app_dir/Contents/Resources"
cp "$binary" "$app_dir/Contents/MacOS/PyCal"
cp "$root_dir/Scripts/PyCal-Info.plist" "$app_dir/Contents/Info.plist"
cp "$root_dir/Sources/PyCal/Resources/PyCalIcon.icns" "$app_dir/Contents/Resources/PyCalIcon.icns"
ditto "$resource_bundle" "$app_dir/PyCal_PyCal.bundle"

echo "Installing $installed_app_dir"
rm -rf "$installed_app_dir"
ditto "$app_dir" "$installed_app_dir"

echo "Opening $installed_app_dir"
open "$installed_app_dir"
