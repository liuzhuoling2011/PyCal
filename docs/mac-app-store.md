# Mac App Store 上架（macOS）

本文只覆盖 **Mac App Store**。GitHub Release 的 Developer ID + 公证 DMG 见 [release.md](release.md)。两条线证书、签名、上传工具都不同，**不要混用**。

本仓库 **不会** 也不应保存 App Store Connect 账号或证书。

## 和现有 DMG 发布的区别

| | GitHub DMG（已有） | Mac App Store（本文） |
| --- | --- | --- |
| 证书 | **Developer ID Application** | **Apple Distribution**（Mac App Store 描述文件） |
| 沙盒 | DMG 脚本关闭签名后再用 Developer ID 签，**不带** App Sandbox，历史仍在 `~/Library/Application Support/PyCal` | **必须** App Sandbox。`FileManager` 的 Application Support 会落到容器：`~/Library/Containers/dev.pycal.app/Data/Library/Application Support/PyCal` |
| Hardened Runtime | 要（公证） | 要（工程已开） |
| 上传 | `notarytool` + `stapler` | Xcode Organizer / `xcodebuild -exportArchive` / Transporter / `iTMSTransporter` |
| 不要用 | — | **`notarytool`、`stapler`、已弃用的 `altool --upload-app`**。公证是 Developer ID 的事；MAS 包由 Apple 重签 |

现有 `Scripts/build-macos-app.sh` 和 `.github/workflows/release-dmg.yml` **保持原样用途**：`CODE_SIGNING_ALLOWED=NO` 之后只加 Developer ID，**不**传入 `PyCal.entitlements`。不要把 MAS 的 Apple Distribution 证书塞进 DMG workflow。

## 工程里已经对齐的

- Bundle ID：`dev.pycal.app`
- Team：`B5W7AL6CG9`（以 developer.apple.com 显示为准）
- 自动签名：`CODE_SIGN_STYLE = Automatic`
- macOS 14+，分类 `public.app-category.utilities`
- `ENABLE_HARDENED_RUNTIME = YES`（仅 macOS）
- `PyCal.entitlements`：只开 `com.apple.security.app-sandbox`，没有网络、文件选择器、临时例外、JIT、`get-task-allow`
- `ITSAppUsesNonExemptEncryption = NO`（无自定义加密、无网络）
- `PrivacyInfo.xcprivacy`：不追踪、不采集；文件时间戳 API 声明 `C617.1`（只碰容器内 `calculator.json`）
- 稿纸历史：`Application Support/PyCal/calculator.json`，沙盒默认容器即可，不需要 App Group 或 user-selected 文件权限
- 剪贴板复制时间戳：沙盒下可用，不必加 entitlement

审计时未发现必须联网、必须读用户自选文件、辅助功能、摄像头等会挡住 MAS 的 API。计算器 + 时间换算可以在最小沙盒里跑。

## 你必须在网页上做的（仓库代劳不了）

1. 付费 [Apple Developer Program](https://developer.apple.com/programs/)（你已有 Developer ID，这项应已满足）。
2. [App Store Connect](https://appstoreconnect.apple.com) → **我的 App** → **+** → 新建：
   - 平台勾选 **macOS**（先不要为了「以后 iPhone」误建成纯 iOS）
   - Bundle ID 选 **`dev.pycal.app`**（若没有，先到 [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) 建 App ID，Explicit，不要用 Wildcard）
   - SKU 自定，例如 `dev.pycal.app`
   - 同一 Bundle ID 以后可以再加 iOS，做成统一购买；**现在不要改 Bundle ID**
3. 签署 Paid Applications / 税务银行信息（即使免费 App 也常要先过协议）。
4. 证书与描述文件（二选一即可）：
   - **推荐：Xcode 自动签名**。本机 Xcode → Settings → Accounts 登录该 Team。第一次 Archive / Export 时 Xcode 会建 **Apple Distribution** 和 **Mac App Store** profile。
   - 手动：Certificates 里建 **Apple Distribution**（不是 Developer ID，也不是 Apple Development），再为 `dev.pycal.app` 建 **Mac App Store** 发行描述文件。
5. 填元数据并上传构建，见下文。

## Xcode 图形界面（推荐第一次）

目标是 **macOS**，不要在选了 iPhone 时按 Archive。

1. 打开 `PyCal.xcodeproj`（不要只开 `Package.swift`）。
2. Scheme 选 **PyCal**，运行目的地选 **Any Mac**（或「我的 Mac」再 Archive 也行，命令行请用 `generic/platform=macOS`）。
3. **Signing & Capabilities**：Team = 你的付费 Team；应能看到 **App Sandbox**（无额外勾选）和 Hardened Runtime。
4. **General**：Version（`MARKETING_VERSION`，如 `0.1.0`）给用户看；Build（`CURRENT_PROJECT_VERSION`）每次上传 App Store Connect **必须递增**（现在工程是 `2`）。
5. Product → **Archive**。
6. Organizer → 选这份 macOS Archive → **Distribute App** → **App Store Connect** → **Upload**（或 Export 出 `.pkg` 再用 Transporter）。
7. 等 ASC 处理完（邮箱 / Activity），在该版本里选构建、填元数据、提交审核。

## 命令行

本机（必须是 Mac + Xcode 16+）：

```sh
# 只归档并导出 .pkg 到 Build/AppStore/export（不上传）
./Scripts/archive-mac-app-store.sh

# 导出并上传到 App Store Connect
# 优先用已登录 Xcode 的 Apple ID；或设置与 DMG 公证相同形状的 ASC API 密钥后再加 --upload
./Scripts/archive-mac-app-store.sh --upload
```

等价的手写命令：

```sh
xcodebuild archive \
  -project PyCal.xcodeproj \
  -scheme PyCal \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath Build/AppStore/PyCal.xcarchive \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath Build/AppStore/PyCal.xcarchive \
  -exportPath Build/AppStore/export \
  -exportOptionsPlist Scripts/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates
```

`Scripts/ExportOptions-AppStore.plist` 使用 Xcode 16+ 的 `method = app-store-connect`（旧名 `app-store` 已弃用，新 Xcode 可能直接拒绝）。默认 `destination = export`。脚本在 `--upload` 时改成 `upload`。

上传已导出的 `.pkg`：

```sh
# Transporter.app：把 .pkg 拖进去

# 命令行（2026 起请用 -assetFile，不要用旧的 -f / .itmsp 包）
xcrun iTMSTransporter -m upload \
  -assetFile Build/AppStore/export/PyCal.pkg \
  -apiKey "$APP_STORE_CONNECT_KEY_ID" \
  -apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
```

**不要：**

```sh
xcrun notarytool submit …     # Developer ID 公证，不是 MAS
xcrun stapler staple …        # 同上
xcrun altool --upload-app …   # 已弃用
```

没有配 MAS 证书时，不要为了「CI 也能上架」去改 `release-dmg.yml`。MAS 密钥和 Developer ID `.p12` 不是同一张证书；硬接到现有 DMG job 会把两条线搅在一起。

## App Store Connect 元数据（只列必填级）

审核要的是完整产品页，不是仓库里的文案。下面只标类别，不代写营销句子。

- **类别**：工具（Utilities），与 `LSApplicationCategoryType` 一致
- **年龄分级**：问卷。本 App 无用户生成社交、无位置、无购买也可先按「无受限内容」填
- **隐私**：计算历史只在本机；不追踪。营养标签选「不收集数据」。若 ASC 仍要隐私政策 URL，需要你自己托管一页（仓库不提供）
- **截图**：Mac 至少一套（常见 1280×800 或 2560×1600 等，以 ASC 当前尺寸表为准）。本仓库不代做
- **审核备注**：可写「本地计算器 + 时间戳换算，无账号、无网络」
- **版权 / 联系人**：Info.plist 已有 `NSHumanReadableCopyright`；ASC 还要自己的版权年和支持网址
- **价格**：免费或付费；付费要先完成合同
- **出口合规**：工程已设 `ITSAppUsesNonExemptEncryption = NO`，一般可跳过年度加密问卷

## 阻塞项与注意

这些不能靠再改两行代码绕过：

1. **没有付费 Team / 没建 ASC 的 macOS App 记录**：无法上传。Bundle ID 必须已经是 `dev.pycal.app`。
2. **用 Developer ID 去签 MAS Archive**：会被拒。Export 必须走 Apple Distribution + Mac App Store profile（自动签名即可）。
3. **构建号没涨**：ASC 拒绝重复的 `CFBundleVersion`。
4. **在 iPhone destination 上 Archive**：会打成 iOS，对不上「先上 Mac」。命令行务必 `generic/platform=macOS`。
5. **沙盒数据与 DMG 数据不互通**：同一台机器上，商店版看不到 DMG 版的 `~/Library/Application Support/PyCal`。沙盒进程也读不了那条路径（除非加 MAS 审核不喜欢的 temporary-exception）。首次从商店安装是空历史，这是预期，不是丢档 bug。
6. **`swift run` / `./Scripts/run-macos.sh` 不是商店包**：命令行包没有走 MAS 签名；商店行为请用 Xcode Run（带 entitlements）或 Archive 导出的包验证。
7. **本环境 / 普通 Linux CI 不能 Archive**：必须 Mac + Xcode。不要把 MAS 上传塞进现有 `macos-latest` DMG job。
8. **iOS App Store 不在本次范围**：同一工程已能编 iOS，但商店记录、截图、审核另做。

未发现「开了沙盒就跑不起来」的 API。若以后加「打开任意文件夹的 json」、网络同步或辅助功能，再补对应 entitlement，并准备审核说明。
