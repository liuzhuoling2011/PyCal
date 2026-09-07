#!/bin/zsh
# Fallback installer for a Gatekeeper-blocked copy. Removes the download
# quarantine from this PyCal.app only — it does not disable Gatekeeper.
set -euo pipefail
cd "$(dirname "$0")"
if [[ ! -d "PyCal.app" ]]; then
    osascript -e 'display dialog "请从 PyCal 安装盘里运行这个脚本，旁边需要有 PyCal.app。" buttons {"好"} default button 1 with title "PyCal"'
    exit 1
fi
xattr -dr com.apple.quarantine "PyCal.app" 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/PyCal.app"
ditto --noqtn "PyCal.app" "$HOME/Applications/PyCal.app"
xattr -dr com.apple.quarantine "$HOME/Applications/PyCal.app" 2>/dev/null || true
open "$HOME/Applications/PyCal.app"
osascript -e 'display dialog "已安装到 ~/Applications/PyCal.app，不需要管理员权限。以后从这里打开即可。这只会去掉这一份 App 的下载隔离标记，没有关闭系统 Gatekeeper。" buttons {"好"} default button 1 with title "PyCal"'
