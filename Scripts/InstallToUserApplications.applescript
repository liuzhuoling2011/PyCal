on run
    try
        set installerPOSIX to POSIX path of (path to me)
        set dmgDir to do shell script "dirname " & quoted form of installerPOSIX
        set srcApp to dmgDir & "/PyCal.app"
        do shell script "test -d " & quoted form of srcApp
        do shell script "xattr -dr com.apple.quarantine " & quoted form of srcApp & " >/dev/null 2>&1 || true"
        do shell script "mkdir -p \"$HOME/Applications\" && rm -rf \"$HOME/Applications/PyCal.app\" && ditto --noqtn " & quoted form of srcApp & " \"$HOME/Applications/PyCal.app\" && (xattr -dr com.apple.quarantine \"$HOME/Applications/PyCal.app\" >/dev/null 2>&1 || true)"
        do shell script "open \"$HOME/Applications/PyCal.app\""
        display dialog "已安装到个人应用程序文件夹，不需要管理员权限。" & return & return & "~/Applications/PyCal.app" & return & return & "这只会去掉这一份 App 的下载隔离标记，没有关闭系统 Gatekeeper。" buttons {"好"} default button 1 with title "PyCal" with icon note
    on error errMsg
        display dialog "安装失败：" & return & errMsg buttons {"好"} default button 1 with title "PyCal" with icon stop
    end try
end run
