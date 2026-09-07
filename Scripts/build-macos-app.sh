#!/bin/bash
# Build Build/PyCal.app for local run or DMG packaging.
# Version comes from PYCAL_VERSION or the current git tag (vX.Y.Z).
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib-macos-release.sh
source "$script_dir/lib-macos-release.sh"

root_dir="$(pycal_repo_root)"
version="$(pycal_resolve_version "$root_dir")"
build_number="${PYCAL_BUILD:-$version}"
app_dir="$root_dir/Build/PyCal.app"
derived_data="$root_dir/Build/DerivedData"
codesign_identity=""

echo "Building PyCal.app $version ($build_number)…"

apply_versions() {
    local plist="$1"
    if [[ ! -f "$plist" ]]; then
        echo "Missing Info.plist at $plist" >&2
        return 1
    fi
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $build_number" "$plist"
}

build_with_xcodebuild() {
    local product
    echo "Using xcodebuild (universal macOS Release)…"
    xcodebuild \
        -project "$root_dir/PyCal.xcodeproj" \
        -scheme PyCal \
        -configuration Release \
        -destination "generic/platform=macOS" \
        -derivedDataPath "$derived_data" \
        ARCHS="arm64 x86_64" \
        ONLY_ACTIVE_ARCH=NO \
        MARKETING_VERSION="$version" \
        CURRENT_PROJECT_VERSION="$build_number" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        DEVELOPMENT_TEAM="" \
        build

    product="$derived_data/Build/Products/Release/PyCal.app"
    if [[ ! -d "$product" ]]; then
        product="$(find "$derived_data/Build/Products" -name PyCal.app -type d | head -n 1 || true)"
    fi
    if [[ -z "${product:-}" || ! -d "$product" ]]; then
        echo "xcodebuild succeeded but PyCal.app was not found under $derived_data" >&2
        return 1
    fi

    rm -rf "$app_dir"
    mkdir -p "$root_dir/Build"
    ditto --noqtn "$product" "$app_dir"
    apply_versions "$app_dir/Contents/Info.plist"
}

build_with_swift() {
    local bin_dir binary resource_bundle icns
    echo "xcodebuild unavailable or failed; falling back to swift build…"
    if swift build -c release --package-path "$root_dir" --arch arm64 --arch x86_64; then
        bin_dir="$(swift build -c release --package-path "$root_dir" --arch arm64 --arch x86_64 --show-bin-path)"
    else
        echo "Universal swift build failed; building host architecture only…"
        swift build -c release --package-path "$root_dir"
        bin_dir="$(swift build -c release --package-path "$root_dir" --show-bin-path)"
    fi
    binary="$bin_dir/PyCal"
    resource_bundle="$bin_dir/PyCal_PyCal.bundle"
    icns="$root_dir/Sources/PyCal/Resources/PyCalIcon.icns"

    if [[ ! -x "$binary" ]]; then
        echo "swift build did not produce $binary" >&2
        return 1
    fi

    rm -rf "$app_dir"
    mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
    cp "$binary" "$app_dir/Contents/MacOS/PyCal"
    chmod +x "$app_dir/Contents/MacOS/PyCal"
    cp "$root_dir/Scripts/PyCal-Info.plist" "$app_dir/Contents/Info.plist"
    apply_versions "$app_dir/Contents/Info.plist"
    if [[ -f "$icns" ]]; then
        cp "$icns" "$app_dir/Contents/Resources/PyCalIcon.icns"
    fi
    if [[ -d "$resource_bundle" ]]; then
        ditto --norsrc --noqtn "$resource_bundle" "$app_dir/Contents/Resources/PyCal_PyCal.bundle"
    fi
    printf 'APPL????' > "$app_dir/Contents/PkgInfo"
}

if command -v xcodebuild >/dev/null 2>&1 && [[ -f "$root_dir/PyCal.xcodeproj/project.pbxproj" ]]; then
    if ! build_with_xcodebuild; then
        echo "xcodebuild path failed; trying SwiftPM bundle…" >&2
        build_with_swift
    fi
else
    build_with_swift
fi

executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_dir/Contents/Info.plist" 2>/dev/null || echo PyCal)"
if [[ ! -x "$app_dir/Contents/MacOS/$executable_name" ]]; then
    echo "Built bundle is missing Contents/MacOS/$executable_name" >&2
    exit 1
fi

pycal_clear_quarantine "$app_dir"

if codesign_identity="$(pycal_find_developer_id_identity)"; then
    echo "Signing app as $codesign_identity"
    codesign --force --options runtime --timestamp --sign "$codesign_identity" "$app_dir"
    codesign --verify --strict --verbose=2 "$app_dir"
else
    if command -v codesign >/dev/null 2>&1; then
        echo "No Developer ID identity; applying ad-hoc signature for local run (not Gatekeeper-safe)."
        codesign --force --deep -s - "$app_dir" 2>/dev/null || true
    fi
fi

echo "Wrote $app_dir"
echo "CFBundleShortVersionString=$version CFBundleVersion=$build_number"
