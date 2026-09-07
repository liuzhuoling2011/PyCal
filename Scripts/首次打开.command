#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
if [[ ! -d "PyCal.app" ]]; then
    osascript -e 'display dialog "请从 PyCal 安装盘里运行这个脚本，旁边需要有 PyCal.app。" buttons {"好"} default button 1 with title "PyCal"'
    exit 1
fi
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/PyCal.app"
ditto "PyCal.app" "$HOME/Applications/PyCal.app"
xattr -cr "$HOME/Applications/PyCal.app"
open "$HOME/Applications/PyCal.app"
osascript -e 'display dialog "已安装到 ~/Applications/PyCal.app，不需要管理员权限。以后从这里打开即可。" buttons {"好"} default button 1 with title "PyCal"'
