# PyCal

PyCal 是一个 macOS / iPhone 原生 SwiftUI 小工具箱，首版包含两个工具：

- **稿纸计算器**：连续输入并保留历史，支持 `+ - * / // % **`、括号、变量赋值、`ans`（上一行结果）和常用数学函数。输入时会实时预览有效结果，按回车保存到历史；历史默认保存 100 行，可置顶、设置 alias，把任意历史结果保存为变量，历史公式也能直接点击修改并实时重新计算。已关联变量的历史行修改后，变量值会同步更新。
- **时间转换**：纳秒、毫秒、秒三种单位；可直接输入 `YYYY-MM-DD HH:mm:ss` 日期，也可打开原生日期选择器；输入有效值后自动换算；日期与 Unix 时间戳双向转换；时区选择；此刻、零点、每日末快捷操作；实时当前时间戳可复制、暂停和重置。

## 运行

需要 Xcode 16+ / Swift 6。macOS 14+ 可直接用命令行；iPhone 需要 iOS 17+，通过 Xcode 工程安装。

```sh
swift run PyCal
```

如果从终端启动后窗口没有拿到键盘焦点，推荐使用项目提供的原生 App 启动脚本：

```sh
./Scripts/run-macos.sh
```

脚本会生成 `Build/PyCal.app`，安装到 `/Applications/PyCal.app`（没有写权限时改到 `~/Applications`），并用 macOS 的 `open` 打开已安装版本。也可以在 Xcode 中打开 `Package.swift` 或 `PyCal.xcodeproj` 运行。构建：

```sh
swift build
swift test
```

### 发布 macOS DMG

推送 `vX.Y.Z` tag 后，GitHub Actions 会构建 `.app`、打包 `PyCal-X.Y.Z.dmg` 并挂到 [GitHub Release](https://github.com/liuzhuoling2011/PyCal/releases)：

```sh
git tag v0.1.0
git push origin v0.1.0
```

- **配齐** Developer ID `.p12` 和 App Store Connect API 密钥之后：产物会签名、公证并 staple，同事从浏览器下载后应能把 App 拖进 Applications 再双击打开。不要关 Gatekeeper。
- **没有** 这些 secrets：仍会发布 DMG，但 **不能** 当成「双击就能开」。下载会带 `com.apple.quarantine`，需要右键打开，或对这一份 App 做 `xattr`。Release 说明会写明这一点。

Secrets、为什么有的机器能开有的不能、以及公证失败时查什么，见 [docs/release.md](docs/release.md)。本流程只做 GitHub DMG，不上传 Mac App Store。

### 上架 Mac App Store

和上面的 Developer ID / 公证 **不是同一条线**：商店包必须开 App Sandbox，用 Apple Distribution 签名，用 Organizer / Transporter / `xcodebuild -exportArchive` 上传，**不要**对商店包跑 `notarytool`。两条线共用 Bundle ID **`com.liuzhuoling.pycal`**（与 App Store Connect 里已建的 Mac App 一致）。步骤、证书和阻塞项见 [docs/mac-app-store.md](docs/mac-app-store.md)。本机归档：

```sh
./Scripts/archive-mac-app-store.sh
```

### 装到自己的 iPhone

不需要付费 Apple Developer Program。用免费 Apple ID 即可：

1. 用 Xcode 打开 `PyCal.xcodeproj`（不要只开 `Package.swift`，那个目标没有 iOS）。
2. 顶部目标选自己的 iPhone，或先选任意 iPhone 模拟器验证。
3. 打开 **Signing & Capabilities**，Team 选自己的 **Personal Team**。
4. 手机用线连接，解锁并信任这台电脑，点 Run。

免费账号的个人签名大约 **7 天过期**，到期后在 Xcode 再签一次即可；同时大约只能装 3 个这类 App，也没有 TestFlight。

计算历史与变量会写入本机 Application Support 下的 `PyCal/calculator.json`，不上传到网络。

## 表达式示例

```text
subtotal = 1200
tax = 0.06
subtotal * (1 + tax)
ans + 100
round(3.14159, 2)       # Python 风格的 round(x, ndigits)
```

为方便稿纸输入，`^` 也作为 `**` 的指数运算快捷写法；常用函数包括 `abs`、`sqrt`、`sin`、`cos`、`tan`、`ln`、`log`、`log10`、`exp`、`floor`、`ceil`、`round`、`min`、`max` 和 `pow`。
