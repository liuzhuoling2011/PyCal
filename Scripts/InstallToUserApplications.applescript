on run
    try
        set installerPOSIX to POSIX path of (path to me)
        set dmgDir to do shell script "dirname " & quoted form of installerPOSIX
        set srcApp to dmgDir & "/PyCal.app"
        do shell script "test -d " & quoted form of srcApp
        do shell script "mkdir -p \"$HOME/Applications\" && rm -rf \"$HOME/Applications/PyCal.app\" && ditto " & quoted form of srcApp & " \"$HOME/Applications/PyCal.app\" && xattr -cr \"$HOME/Applications/PyCal.app\""
        do shell script "open \"$HOME/Applications/PyCal.app\""
        display dialog "已安装到个人应用程序文件夹，不需要管理员权限。" & return & return & "~/Applications/PyCal.app" buttons {"好"} default button 1 with title "PyCal" with icon note
    on error errMsg
        display dialog "安装失败：" & return & errMsg buttons {"好"} default button 1 with title "PyCal" with icon stop
    end try
end run
