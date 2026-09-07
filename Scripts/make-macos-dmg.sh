#!/bin/zsh
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_path="${1:-$HOME/Documents/PyCal.app}"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist" 2>/dev/null || echo "0.1.0")"
output_dir="${2:-$HOME/Documents}"
dmg_path="$output_dir/PyCal-$version.dmg"
stage="$(mktemp -d /tmp/pycal-dmg.XXXXXX)"

cleanup() {
    if [[ -n "${mount_dir:-}" && -d "$mount_dir" ]]; then
        hdiutil detach "$mount_dir" -quiet || true
    fi
    rm -rf "$stage"
}
trap cleanup EXIT

if [[ ! -d "$app_path" ]]; then
    echo "找不到 $app_path" >&2
    echo "用法: $0 [已公证的 PyCal.app] [输出目录]" >&2
    exit 1
fi

rw_dmg="$stage/PyCal.rw.dmg"
echo "Creating disk image…"
hdiutil create \
    -volname "PyCal" \
    -size 40m \
    -ov \
    -fs HFS+ \
    "$rw_dmg" >/dev/null

mount_dir="$(hdiutil attach -readwrite -noverify -noautoopen "$rw_dmg" | awk '/\/Volumes\//{print $NF}')"
if [[ -z "$mount_dir" || ! -d "$mount_dir" ]]; then
    echo "挂载 dmg 失败" >&2
    exit 1
fi

echo "Copying app…"
ditto "$app_path" "$mount_dir/PyCal.app"

ident="$(security find-identity -v -p codesigning | awk -F'\"' '/Developer ID Application:/{print $2; exit}')"
osacompile -o "$mount_dir/安装到个人目录.app" "$root_dir/Scripts/InstallToUserApplications.applescript"
if [[ -n "$ident" ]]; then
    codesign --force --options runtime --timestamp --sign "$ident" "$mount_dir/安装到个人目录.app"
fi

cp "$root_dir/Scripts/首次打开.command" "$mount_dir/首次打开.command"
chmod +x "$mount_dir/首次打开.command"

cat > "$mount_dir/使用说明.txt" <<'NOTE'
公司电脑请不要只把 PyCal.app 或 dmg 拖进 ~/Applications 就双击。
那样隔离标记还在，仍然会提示「无法打开」。

请用下面任一方式（都不需要管理员）：

1. 双击「首次打开.command」，若提示来自互联网，选打开。
2. 打开「终端」，粘贴下面两行后回车（先把 App 放到 ~/Applications）：

xattr -cr ~/Applications/PyCal.app
open ~/Applications/PyCal.app

以后直接从 ~/Applications 打开即可，不用再装。
NOTE

osascript <<EOF || echo "跳过窗口排版（不影响安装）"
tell application "Finder"
    tell disk "PyCal"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {160, 140, 820, 520}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 88
        set position of item "PyCal.app" of container window to {90, 180}
        set position of item "首次打开.command" of container window to {280, 180}
        set position of item "安装到个人目录.app" of container window to {470, 180}
        set position of item "使用说明.txt" of container window to {650, 180}
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

rm -f "$dmg_path"
hdiutil convert "$rw_dmg" -format UDZO -imagekey zlib-level=9 -o "$dmg_path" >/dev/null
echo "Wrote $dmg_path"

ident="$(security find-identity -v -p codesigning | awk -F'\"' '/Developer ID Application:/{print $2; exit}')"
if [[ -z "$ident" ]]; then
    echo "找不到 Developer ID Application 证书，无法给 dmg 签名" >&2
    exit 1
fi
echo "Signing DMG as $ident"
codesign --force --sign "$ident" --timestamp "$dmg_path"
codesign --verify --verbose=2 "$dmg_path"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "Submitting DMG to Apple notary service…"
    xcrun notarytool submit "$dmg_path" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg_path"
    stapler validate "$dmg_path"
    syspolicy_check distribution "$dmg_path" || true
    echo "Notarized and stapled $dmg_path"
else
    echo
    echo "下一步（只需做一次凭证）:"
    echo "  xcrun notarytool store-credentials pycal-notary --apple-id 你的AppleID --team-id B5W7AL6CG9"
    echo "然后公证这张 dmg:"
    echo "  NOTARY_PROFILE=pycal-notary $0 \"$app_path\" \"$output_dir\""
    echo "或对已有 dmg:"
    echo "  xcrun notarytool submit \"$dmg_path\" --keychain-profile pycal-notary --wait"
    echo "  xcrun stapler staple \"$dmg_path\""
fi
