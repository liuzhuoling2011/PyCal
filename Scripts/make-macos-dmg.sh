#!/bin/bash
# Package PyCal.app into PyCal-$version.dmg.
# When a Developer ID identity and notary credentials are available, the app and
# DMG are signed, notarized, and stapled — that is what makes a download
# double-clickable. Without credentials the script still writes an unsigned DMG
# and prints a Gatekeeper warning (it does not disable Gatekeeper).
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib-macos-release.sh
source "$script_dir/lib-macos-release.sh"

root_dir="$(pycal_repo_root)"
app_path="${1:-$root_dir/Build/PyCal.app}"
output_dir="${2:-$root_dir/Build}"
stage="$(mktemp -d /tmp/pycal-dmg.XXXXXX)"
payload="$stage/payload"
rw_dmg="$stage/PyCal.rw.dmg"
mount_dir=""
api_key_file=""
signed=0
notarized=0
identity=""
version=""
dmg_path=""

cleanup() {
    if [[ -n "${mount_dir:-}" && -d "$mount_dir" ]]; then
        hdiutil detach "$mount_dir" -quiet || true
    fi
    if [[ -n "${api_key_file:-}" ]]; then
        rm -f "$api_key_file"
    fi
    rm -rf "$stage"
}
trap cleanup EXIT

if [[ ! -d "$app_path" ]]; then
    echo "找不到 $app_path" >&2
    echo "用法: $0 [PyCal.app] [输出目录]" >&2
    echo "先运行: $root_dir/Scripts/build-macos-app.sh" >&2
    exit 1
fi

if [[ ! -d "$app_path/Contents" ]]; then
    echo "$app_path 不是有效的 .app 包" >&2
    exit 1
fi

mkdir -p "$output_dir"
version="$(pycal_resolve_version "$root_dir")"
if /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist" >/dev/null 2>&1; then
    version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
fi
dmg_path="$output_dir/PyCal-$version.dmg"

if identity="$(pycal_find_developer_id_identity)"; then
    echo "Signing with $identity"
    signed=1
    codesign --force --options runtime --timestamp --sign "$identity" "$app_path"
    codesign --verify --strict --verbose=2 "$app_path"
else
    echo "No Developer ID Application identity in the keychain."
    if [[ -n "${GITHUB_ACTIONS:-}" && "${ALLOW_UNSIGNED_DMG:-}" != "1" && "${PYCAL_RELEASE_MODE:-}" != "unsigned" ]]; then
        echo "CI refusing to ship an unsigned DMG unless PYCAL_RELEASE_MODE=unsigned." >&2
        exit 1
    fi
    echo "Will write an unsigned DMG. Gatekeeper will block typical downloads."
fi

if [[ "$signed" -eq 1 && -z "${NOTARY_PROFILE:-}" ]]; then
    if [[ -n "${APP_STORE_CONNECT_API_KEY_P8:-}" ]]; then
        api_key_file="$stage/AuthKey.p8"
        pycal_write_api_key_file "$api_key_file"
    fi
fi

can_notarize=0
if [[ "$signed" -eq 1 ]]; then
    if [[ -n "${NOTARY_PROFILE:-}" || -n "${api_key_file:-}" ]]; then
        can_notarize=1
    fi
fi

if [[ "$can_notarize" -eq 1 ]]; then
    echo "Notarizing app before packaging (so a copy in Applications stays trusted offline)…"
    app_zip="$stage/PyCal.app.zip"
    ditto -c -k --keepParent "$app_path" "$app_zip"
    pycal_notarytool_submit "$app_zip" "${api_key_file:-}"
    pycal_staple "$app_path"
    notarized=1
fi

rm -rf "$payload"
mkdir -p "$payload"

echo "Staging DMG contents…"
# Keep code-signing xattrs and the notarization ticket; only suppress quarantine.
ditto --noqtn "$app_path" "$payload/PyCal.app"
ln -s /Applications "$payload/Applications"
pycal_clear_quarantine "$payload/PyCal.app"
if [[ "$signed" -eq 1 ]]; then
    codesign --verify --strict --verbose=2 "$payload/PyCal.app"
fi

osacompile -o "$payload/安装到个人目录.app" "$root_dir/Scripts/InstallToUserApplications.applescript"
cp "$root_dir/Scripts/首次打开.command" "$payload/首次打开.command"
chmod +x "$payload/首次打开.command"
pycal_clear_quarantine "$payload/安装到个人目录.app"
pycal_clear_quarantine "$payload/首次打开.command"

if [[ "$signed" -eq 1 ]]; then
    codesign --force --options runtime --timestamp --sign "$identity" "$payload/安装到个人目录.app"
fi

if [[ "$notarized" -eq 1 ]]; then
    cat > "$payload/使用说明.txt" <<NOTE
PyCal $version（已 Developer ID 签名并公证）

把 PyCal.app 拖到旁边的 Applications，再从「应用程序」双击打开即可。
这张磁盘映像已公证并 staple，从浏览器下载后一般不必再清隔离属性。

不要关闭系统完整性保护，也不要关闭 Gatekeeper。

如果公司 MDM 仍拦截（少见），用旁边的「首次打开.command」装到
~/Applications。那只会去掉这一份 App 的下载隔离标记，不是关闭系统安全。
NOTE
else
    cat > "$payload/使用说明.txt" <<NOTE
PyCal $version（未公证，双击通常会被拦截）

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
fi

layout_dmg() {
    mount_dir="$(hdiutil attach -readwrite -noverify -noautoopen "$rw_dmg" | awk '/\/Volumes\//{print $NF; exit}')"
    if [[ -z "$mount_dir" || ! -d "$mount_dir" ]]; then
        echo "挂载 dmg 失败" >&2
        return 1
    fi

    ditto --noqtn "$payload/." "$mount_dir/"
    sync

    osascript <<'EOF' || echo "跳过窗口排版（不影响安装）"
tell application "Finder"
    tell disk "PyCal"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {160, 140, 860, 520}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set position of item "PyCal.app" of container window to {120, 180}
        set position of item "Applications" of container window to {360, 180}
        set position of item "首次打开.command" of container window to {560, 140}
        set position of item "安装到个人目录.app" of container window to {560, 260}
        set position of item "使用说明.txt" of container window to {720, 180}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

    sync
    hdiutil detach "$mount_dir" -quiet
    mount_dir=""
}

echo "Creating disk image…"
rm -f "$dmg_path"

if [[ -z "${GITHUB_ACTIONS:-}" && "${SKIP_DMG_LAYOUT:-}" != "1" ]]; then
    hdiutil create -volname "PyCal" -size 80m -ov -fs HFS+ "$rw_dmg" >/dev/null
    if layout_dmg; then
        hdiutil convert "$rw_dmg" -format UDZO -imagekey zlib-level=9 -o "$dmg_path" >/dev/null
    else
        echo "Pretty layout failed; using srcfolder…"
        hdiutil create -volname "PyCal" -srcfolder "$payload" -ov -format UDZO -imagekey zlib-level=9 -o "$dmg_path" >/dev/null
    fi
else
    # Headless CI: srcfolder + convert is reliable and still produces UDZO.
    hdiutil create -volname "PyCal" -srcfolder "$payload" -ov -format UDZO -imagekey zlib-level=9 -o "$dmg_path" >/dev/null
fi

if [[ ! -f "$dmg_path" ]]; then
    echo "Failed to create $dmg_path" >&2
    exit 1
fi

pycal_clear_quarantine "$dmg_path"

if [[ "$signed" -eq 1 ]]; then
    echo "Signing DMG as $identity"
    codesign --force --sign "$identity" --timestamp "$dmg_path"
    codesign --verify --verbose=2 "$dmg_path"
else
    echo "Unsigned DMG written (no Developer ID)."
fi

if [[ "$can_notarize" -eq 1 ]]; then
    echo "Submitting DMG to Apple notary service…"
    pycal_notarytool_submit "$dmg_path" "${api_key_file:-}"
    pycal_staple "$dmg_path"
    notarized=1
    if command -v syspolicy_check >/dev/null 2>&1; then
        syspolicy_check distribution "$dmg_path" || true
    fi
    echo "Notarized and stapled $dmg_path"
elif [[ "$signed" -eq 1 ]]; then
    echo
    echo "App/DMG are Developer ID signed but not notarized."
    echo "Downloads will still be Gatekeeper-blocked until you notarize:"
    echo "  xcrun notarytool store-credentials pycal-notary --apple-id YOUR_APPLE_ID --team-id ${APPLE_TEAM_ID:-B5W7AL6CG9}"
    echo "  NOTARY_PROFILE=pycal-notary $0 \"$app_path\" \"$output_dir\""
fi

echo "Wrote $dmg_path"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        echo "dmg_path=$dmg_path"
        echo "version=$version"
        echo "signed=$signed"
        echo "notarized=$notarized"
    } >> "$GITHUB_OUTPUT"
fi

if [[ "$notarized" -eq 1 ]]; then
    echo "PYCAL_DMG_STATUS=notarized"
else
    echo "PYCAL_DMG_STATUS=unsigned-or-not-notarized"
fi
