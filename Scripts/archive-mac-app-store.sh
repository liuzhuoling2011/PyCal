#!/bin/bash
# Archive and export a Mac App Store build (Apple Distribution / App Sandbox).
#
# This is NOT the Developer ID + notarytool + DMG path.
# Do not call notarytool or stapler here. Apple re-signs MAS uploads.
# `xcrun altool --upload-app` is deprecated; prefer Organizer, this script,
# Transporter.app, or `xcrun iTMSTransporter -m upload -assetFile`.
#
# Requires macOS + Xcode 16+ and a paid team that can create Mac App Store
# profiles (automatic signing). Does not invent or store credentials.
#
# Usage:
#   ./Scripts/archive-mac-app-store.sh            # archive + export .pkg locally
#   ./Scripts/archive-mac-app-store.sh --upload   # also send the pkg to App Store Connect
#
# Optional env:
#   PYCAL_VERSION / PYCAL_BUILD   marketing / build numbers
#   DEVELOPMENT_TEAM / APPLE_TEAM_ID
#   APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_API_KEY_P8
#     used only with --upload (same API key shape as docs/release.md, different purpose)
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib-macos-release.sh
source "$script_dir/lib-macos-release.sh"

root_dir="$(pycal_repo_root)"
upload=0
team="${DEVELOPMENT_TEAM:-${APPLE_TEAM_ID:-B5W7AL6CG9}}"
version="$(pycal_resolve_version "$root_dir")"
build_number="${PYCAL_BUILD:-$version}"
out_dir="$root_dir/Build/AppStore"
archive_path="$out_dir/PyCal.xcarchive"
export_path="$out_dir/export"
options_template="$script_dir/ExportOptions-AppStore.plist"
api_key_file=""

usage() {
    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
}

cleanup() {
    if [[ -n "${api_key_file:-}" ]]; then
        rm -f "$api_key_file"
    fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --upload)
            upload=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "xcodebuild not found. Archive on a Mac with Xcode 16+." >&2
    echo "This script does not run on Linux CI and does not touch the DMG workflow." >&2
    exit 1
fi

if [[ ! -f "$options_template" ]]; then
    echo "Missing $options_template" >&2
    exit 1
fi

mkdir -p "$out_dir"
rm -rf "$archive_path" "$export_path"
mkdir -p "$export_path"

export_options="$out_dir/ExportOptions.plist"
cp "$options_template" "$export_options"
/usr/libexec/PlistBuddy -c "Set :teamID $team" "$export_options"
if [[ "$upload" -eq 1 ]]; then
    /usr/libexec/PlistBuddy -c "Set :destination upload" "$export_options"
fi

echo "Archiving PyCal $version ($build_number) for Mac App Store…"
echo "Team $team  destination generic/platform=macOS"

auth_args=()
if [[ "$upload" -eq 1 && -n "${APP_STORE_CONNECT_API_KEY_P8:-}" && -n "${APP_STORE_CONNECT_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
    mkdir -p "$out_dir/private_keys"
    api_key_file="$out_dir/private_keys/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
    pycal_write_api_key_file "$api_key_file"
    auth_args=(
        -authenticationKeyPath "$api_key_file"
        -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID"
        -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"
    )
    echo "Using App Store Connect API key ${APP_STORE_CONNECT_KEY_ID} for upload."
elif [[ "$upload" -eq 1 ]]; then
    echo "No ASC API key env; xcodebuild will use the Apple ID signed into Xcode."
fi

xcodebuild archive \
    -project "$root_dir/PyCal.xcodeproj" \
    -scheme PyCal \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$archive_path" \
    MARKETING_VERSION="$version" \
    CURRENT_PROJECT_VERSION="$build_number" \
    DEVELOPMENT_TEAM="$team" \
    CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates

if [[ ! -d "$archive_path" ]]; then
    echo "Archive missing at $archive_path" >&2
    exit 1
fi

echo "Exporting App Store pkg (method=app-store-connect)…"
# Duplicate the invocation so empty auth_args is safe on macOS bash 3.2 + set -u.
if [[ ${#auth_args[@]} -gt 0 ]]; then
    xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "$export_options" \
        -allowProvisioningUpdates \
        "${auth_args[@]}"
else
    xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "$export_options" \
        -allowProvisioningUpdates
fi

pkg="$(find "$export_path" -name '*.pkg' -type f | head -n 1 || true)"
if [[ -z "${pkg:-}" && "$upload" -eq 0 ]]; then
    echo "Export finished but no .pkg under $export_path" >&2
    ls -la "$export_path" || true
    exit 1
fi

if [[ "$upload" -eq 1 ]]; then
    echo "xcodebuild destination=upload finished. Confirm the build in App Store Connect → Activity."
    echo "If you exported a .pkg earlier, upload it with Transporter.app or:"
    echo "  xcrun iTMSTransporter -m upload -assetFile <PyCal.pkg> -apiKey <KEY_ID> -apiIssuer <ISSUER>"
fi

echo
echo "Archive: $archive_path"
echo "Export:  $export_path"
if [[ -n "${pkg:-}" ]]; then
    echo "PKG:     $pkg"
fi
echo "CFBundleShortVersionString=$version CFBundleVersion=$build_number"
echo
echo "Next: select the App Store Connect Mac record for com.liuzhuoling.pycal,"
echo "then submit the build for review. See docs/mac-app-store.md."
echo "Do not notarize this pkg with notarytool."
