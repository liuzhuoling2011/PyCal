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

# Write the DMG 使用说明.txt. version is passed in and printed with printf so
# it is never expanded next to UTF-8 in an unquoted heredoc.
# macOS /bin/bash 3.2 + set -u treats `$version（` as a different name
# (`version<corrupt>: unbound variable`) and the package step dies before hdiutil.
pycal_write_dmg_usage_note() {
    local dest="$1"
    local version="$2"
    local notarized_flag="$3"

    if [[ -z "${version}" ]]; then
        echo "internal error: version is unset before writing ${dest}" >&2
        return 1
    fi

    if [[ "$notarized_flag" -eq 1 ]]; then
        {
            printf 'PyCal %s（已 Developer ID 签名并公证）\n' "${version}"
            cat <<'NOTE'

把 PyCal.app 拖到旁边的 Applications，再从「应用程序」双击打开即可。
这张磁盘映像已公证并 staple，从浏览器下载后一般不必再清隔离属性。

不要关闭系统完整性保护，也不要关闭 Gatekeeper。

如果公司 MDM 仍拦截（少见），用旁边的「首次打开.command」装到
~/Applications。那只会去掉这一份 App 的下载隔离标记，不是关闭系统安全。
NOTE
        } > "$dest"
    else
        {
            printf 'PyCal %s（未公证，双击通常会被拦截）\n' "${version}"
            cat <<'NOTE'

这张磁盘映像没有 Apple 公证。Safari / Chrome / 部分聊天软件下载后会带上
com.apple.quarantine，Gatekeeper 会阻止直接双击。

请不要关闭 Gatekeeper。用下面任一方式打开这一份 App：

1. 双击「首次打开.command」（若提示来自互联网，选打开）。
2. 选中 PyCal.app，按住 Control 点按 → 打开。
3. 终端（先把 App 放到 ~/Applications）：

   xattr -d com.apple.quarantine ~/Applications/PyCal.app
   open ~/Applications/PyCal.app

需要「下载后直接双击」时，维护者要在 GitHub Actions 配好 Developer ID
与 App Store Connect API 密钥后再打 tag 发布。说明见 docs/release.md。
NOTE
        } > "$dest"
    fi
}
