#!/bin/bash
# Shared helpers for macOS app/DMG release scripts. Source this file; do not execute it.

pycal_repo_root() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    printf '%s\n' "$here"
}

# Tag v0.1.0 / 0.1.0 → 0.1.0. Prefers PYCAL_VERSION, then an exact git tag, then Info.plist.
pycal_resolve_version() {
    local root="${1:-$(pycal_repo_root)}"
    local version="${PYCAL_VERSION:-}"
    local tag=""
    local plist="$root/Scripts/PyCal-Info.plist"

    if [[ -z "$version" && "${GITHUB_REF_TYPE:-}" == "tag" && -n "${GITHUB_REF_NAME:-}" ]]; then
        version="${GITHUB_REF_NAME}"
    fi

    if [[ -z "$version" ]] && command -v git >/dev/null 2>&1; then
        if tag="$(git -C "$root" describe --tags --exact-match 2>/dev/null)"; then
            version="$tag"
        fi
    fi

    if [[ -z "$version" && -f "$plist" ]] && command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
        version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null || true)"
    fi

    version="${version#v}"
    if [[ -z "$version" ]]; then
        version="0.1.0"
    fi

    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
        echo "Invalid marketing version '$version' (expected X.Y.Z from tag vX.Y.Z)" >&2
        return 1
    fi

    printf '%s\n' "$version"
}

pycal_is_set() {
    [[ -n "${1:-}" ]]
}

# Prints signing|notarized|unsigned|partial to stdout. Exits 1 on partial secrets.
pycal_release_mode() {
    local sign_any=0
    local sign_all=0
    local notary_any=0
    local notary_all=0
    local profile_notary=0

    if pycal_is_set "${DEVELOPER_ID_P12_BASE64:-}" || pycal_is_set "${DEVELOPER_ID_P12_PASSWORD:-}"; then
        sign_any=1
    fi
    if pycal_is_set "${DEVELOPER_ID_P12_BASE64:-}" && pycal_is_set "${DEVELOPER_ID_P12_PASSWORD:-}" && pycal_is_set "${APPLE_TEAM_ID:-}"; then
        sign_all=1
    fi

    if pycal_is_set "${APP_STORE_CONNECT_KEY_ID:-}" || pycal_is_set "${APP_STORE_CONNECT_ISSUER_ID:-}" || pycal_is_set "${APP_STORE_CONNECT_API_KEY_P8:-}"; then
        notary_any=1
    fi
    if pycal_is_set "${APP_STORE_CONNECT_KEY_ID:-}" && pycal_is_set "${APP_STORE_CONNECT_ISSUER_ID:-}" && pycal_is_set "${APP_STORE_CONNECT_API_KEY_P8:-}"; then
        notary_all=1
    fi
    if pycal_is_set "${NOTARY_PROFILE:-}"; then
        profile_notary=1
        notary_any=1
        notary_all=1
    fi

    if (( sign_any || notary_any )); then
        if (( !sign_all )); then
            echo "Signing secrets are incomplete." >&2
            echo "Need all of: DEVELOPER_ID_P12_BASE64, DEVELOPER_ID_P12_PASSWORD, APPLE_TEAM_ID" >&2
            return 1
        fi
        if (( notary_any || profile_notary )); then
            if (( !notary_all )); then
                echo "Notarization secrets are incomplete." >&2
                echo "Need App Store Connect API key: APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_API_KEY_P8" >&2
                echo "Or a local NOTARY_PROFILE keychain item." >&2
                return 1
            fi
            printf '%s\n' "notarized"
            return 0
        fi
        if [[ -n "${GITHUB_ACTIONS:-}" && "${ALLOW_SIGNED_WITHOUT_NOTARY:-}" != "1" ]]; then
            echo "Developer ID secrets are set, but notarization secrets are not." >&2
            echo "A signed-but-not-notarized download is still Gatekeeper-blocked after Safari/Chrome/Slack." >&2
            echo "Add the App Store Connect API key secrets, or set ALLOW_SIGNED_WITHOUT_NOTARY=1 to publish signed-only." >&2
            return 1
        fi
        printf '%s\n' "signing"
        return 0
    fi

    printf '%s\n' "unsigned"
}

pycal_find_developer_id_identity() {
    local team="${APPLE_TEAM_ID:-}"
    local line identity

    if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
        printf '%s\n' "$CODESIGN_IDENTITY"
        return 0
    fi

    if ! command -v security >/dev/null 2>&1; then
        return 1
    fi

    while IFS= read -r line; do
        identity="${line#*\"}"
        identity="${identity%\"*}"
        if [[ -n "$team" && "$identity" != *"$team"* ]]; then
            continue
        fi
        printf '%s\n' "$identity"
        return 0
    done < <(security find-identity -v -p codesigning 2>/dev/null | grep 'Developer ID Application:' || true)

    return 1
}

pycal_clear_quarantine() {
    local path="$1"
    if [[ ! -e "$path" ]]; then
        return 0
    fi
    if command -v xattr >/dev/null 2>&1; then
        # Only drop the download isolation flag. `xattr -c` would also strip
        # staple / provenance attributes and can undo notarization.
        xattr -dr com.apple.quarantine "$path" 2>/dev/null || true
    fi
}

pycal_write_api_key_file() {
    local dest="$1"
    if [[ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" ]]; then
        return 1
    fi
    printf '%s\n' "$APP_STORE_CONNECT_API_KEY_P8" | tr -d '\r' > "$dest"
    chmod 600 "$dest"
}

pycal_notarytool_submit() {
    local file="$1"
    local key_file="${2:-}"

    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait
        return
    fi

    if [[ -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" || -z "$key_file" ]]; then
        echo "No notary credentials (NOTARY_PROFILE or App Store Connect API key)." >&2
        return 1
    fi

    xcrun notarytool submit "$file" \
        --key "$key_file" \
        --key-id "$APP_STORE_CONNECT_KEY_ID" \
        --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
        --wait
}

pycal_staple() {
    local file="$1"
    xcrun stapler staple "$file"
    xcrun stapler validate "$file"
}

# Release asset name. Tag v0.2.1 → PyCal-0.2.1.dmg; v0.2.1-rc.1 → PyCal-0.2.1-rc.1.dmg.
pycal_dmg_basename() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
        echo "Invalid DMG version '$version' (expected X.Y.Z or X.Y.Z-suffix)" >&2
        return 1
    fi
    printf '%s\n' "PyCal-${version}.dmg"
}

pycal_codesign_item() {
    local target="$1"
    local identity="$2"
    # Hardened runtime + secure timestamp are required for notarization.
    # No --entitlements: app-sandbox is restricted and this direct-distribution
    # path does not embed a provisioning profile (same policy as the old DMG).
    codesign --force --options runtime --timestamp --generate-entitlement-der \
        --sign "$identity" "$target"
}

# Sign nested frameworks, dylibs, and bundles inside-out, then the outer app.
# Call this before notarization. It strips xattrs first; do not call it after staple.
pycal_codesign_app() {
    local app="$1"
    local identity="$2"
    local list item entitlements

    if [[ ! -d "$app/Contents" ]]; then
        echo "pycal_codesign_app: $app is not an application bundle" >&2
        return 1
    fi
    if [[ -z "$identity" ]]; then
        echo "pycal_codesign_app: empty signing identity" >&2
        return 1
    fi

    if command -v xattr >/dev/null 2>&1; then
        # Finder info and resource forks make the notary service reject the upload.
        # Quarantine-only cleanup is wrong here: there is no staple yet.
        xattr -cr "$app" || true
    fi

    list="$(mktemp)"
    find "$app" -depth \( \
        -name '*.framework' -o \
        -name '*.dylib' -o \
        -name '*.so' -o \
        -name '*.bundle' -o \
        -name '*.appex' -o \
        -name '*.xpc' -o \
        -name '*.app' \
        \) -print > "$list"

    while IFS= read -r item; do
        [[ -z "$item" || "$item" == "$app" ]] && continue
        echo "Signing $item"
        pycal_codesign_item "$item" "$identity" || {
            rm -f "$list"
            return 1
        }
    done < "$list"
    rm -f "$list"

    echo "Signing $app"
    pycal_codesign_item "$app" "$identity" || return 1
    codesign --verify --deep --strict --verbose=2 "$app" || return 1

    entitlements="$(codesign -d --entitlements :- "$app" 2>/dev/null || true)"
    if [[ "$entitlements" == *"com.apple.security.app-sandbox"* ]]; then
        echo "Refusing to notarize $app: com.apple.security.app-sandbox is present." >&2
        echo "Developer ID downloads in this repo are signed without a provisioning profile." >&2
        return 1
    fi

    pycal_assert_developer_id_signatures "$app"
}

pycal_assert_developer_id_signatures() {
    local root="$1"
    local list item details
    list="$(mktemp)"
    find "$root" \( \
        -name '*.framework' -o \
        -name '*.dylib' -o \
        -name '*.bundle' -o \
        -name '*.appex' -o \
        -name '*.app' \
        \) -print > "$list"

    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        if ! details="$(codesign -dv --verbose=4 "$item" 2>&1)"; then
            echo "codesign -dv failed for $item" >&2
            printf '%s\n' "$details" >&2
            rm -f "$list"
            return 1
        fi
        if [[ "$details" != *"Authority=Developer ID Application:"* ]]; then
            echo "Missing Developer ID Application authority: $item" >&2
            printf '%s\n' "$details" >&2
            rm -f "$list"
            return 1
        fi
        if [[ -n "${APPLE_TEAM_ID:-}" && "$details" != *"TeamIdentifier=${APPLE_TEAM_ID}"* ]]; then
            echo "TeamIdentifier is not ${APPLE_TEAM_ID}: $item" >&2
            printf '%s\n' "$details" >&2
            rm -f "$list"
            return 1
        fi
    done < "$list"
    rm -f "$list"
}
