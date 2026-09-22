# macOS 发布（GitHub Release + DMG）

推送符合 `vX.Y.Z` 的 git tag 后，[`.github/workflows/flutter-release.yml`](../.github/workflows/flutter-release.yml) 在 `macos-latest` 上构建 Flutter `PyCal.app`，打成 **`PyCal-<version>.dmg`**，Developer ID 签名、公证（notarization）并 staple，然后挂到该 tag 的 GitHub Release。

这是 Release 上**唯一**的 macOS 安装包，沿用原来 Swift 磁盘映像的文件名。下载后：打开 DMG → 把 **PyCal** 拖到 **Applications** → 双击。不需要关 Gatekeeper，也不需要 `xattr`。

同一个 workflow 还会构建 Web、Linux x64、Windows x64 和 Android APK。某一个平台失败时，其他已经成功的附件仍会上传；Web、Linux、Windows、macOS、Android 任一失败仍会让 workflow 变红。它只用 `gh release upload --clobber` 覆盖同名文件，**不会删除**该 Release 上的其他附件。

**iOS 暂不发布。** 不再构建 `PyCal-<version>-ios-unsigned.zip`，也不做 TestFlight / App Store 上传。

`v0.2.1` 以及更早的 tag 仍保留当时的附件（旧 Swift `PyCal-<version>.dmg`、ad-hoc 的 `PyCal-<version>-macos.zip`、未签名 iOS zip）。本流程不回溯删除它们。要拿到 Flutter 公证 DMG，推一个新 tag。

没有配齐下面的六项 secrets 时，macOS job **失败**，不会再上传一个看起来能安装的 zip 或未签名 DMG。

不要关闭 Gatekeeper，也不要关 SIP。

## 为什么有的电脑能开、有的不能

之前内部分发的 App / DMG，有人双击就行、有人必须：

```sh
xattr -cr ~/Downloads/PyCal.app
open ~/Downloads/PyCal.app
```

这不是随机故障，而是 Gatekeeper 对 **隔离属性** 的评估结果不同。

| 原因 | 结果 |
| --- | --- |
| Safari / Chrome / 部分 Slack 下载 | 给文件打上 `com.apple.quarantine`。打开时走 Gatekeeper。 |
| U 盘、隔空投送、部分网盘/聊天工具、从源码自己编 | 常常 **没有** quarantine。看起来「双击就能开」。 |
| 未签名、临时签名（ad-hoc）、或用了 **Apple Development** 而不是 **Developer ID Application** | 带 quarantine 时被拒，提示已损坏 / 无法验证开发者。 |
| 有 Developer ID，但 **没公证** 或 **没 staple** 且当时连不上 Apple | 仍会被拒。公证 ticket 在 Apple 侧；staple 把 ticket 钉进 DMG/App，离线也能过。 |
| 从 DMG 里用 Finder 拖出 `.app` | 会 **继承** DMG 的 quarantine。未公证时，拖到 `~/Applications` 再双击照样拦截。 |
| 已经右键「打开」过，或对本份 App 做过 `xattr` | 这一份副本的隔离被清掉或已有用户同意，所以「以后就能开」。 |

`xattr -cr` 的作用是去掉 **这一份文件** 上的 `com.apple.quarantine`，不是关闭系统安全策略。同事机器上「必须 xattr 才能开」= 产物没有过公证，只是隔离评估没过。公证并 staple 之后的 DMG 不需要这一步。

## 切一版

```sh
git checkout main
git pull
git tag v0.2.2
git push origin v0.2.2
```

只推 tag 即可（`git push --tags` 也会把本地新 tag 推上去）。tag 格式：`v` + 三段数字，例如 `v0.2.2`。可选后缀：`v0.2.2-rc.1`（GitHub Release 会标成 prerelease）。

也可以在 Actions 里手动运行 **Flutter release**，填写已经存在的 tag。手动运行构建的是这个 tag，不是你点运行时所在的分支。

版本号：

| | `v0.2.2` | `v0.2.2-rc.1` |
| --- | --- | --- |
| 文件名 | `PyCal-0.2.2.dmg` | `PyCal-0.2.2-rc.1.dmg` |
| `CFBundleShortVersionString`（`--build-name`） | `0.2.2` | `0.2.2` |
| `CFBundleVersion`（`--build-number`） | GitHub Actions `run_number` | 同左 |

`pubspec.yaml` 不会被发布 job 改写。

Actions 成功后，打开该 tag 的 GitHub Release，下载 `PyCal-<version>.dmg`。

本地等价步骤（有 Developer ID 和公证凭证时才会签并公证；没有凭证时脚本仍会写出未签名 DMG 并打印 Gatekeeper 警告，CI 不允许这条退路）：

```sh
export PYCAL_VERSION=0.2.2
flutter build macos --release --build-name=0.2.2 --build-number=1
export PYCAL_DMG_VERSION=0.2.2
./Scripts/make-macos-dmg.sh build/macos/Build/Products/Release/PyCal.app Build
```

本机钥匙串 profile：

```sh
xcrun notarytool store-credentials pycal-notary --apple-id YOUR_APPLE_ID --team-id B5W7AL6CG9
NOTARY_PROFILE=pycal-notary ./Scripts/make-macos-dmg.sh build/macos/Build/Products/Release/PyCal.app Build
```

`Scripts/build-macos-app.sh` 和 `./Scripts/run-macos.sh` 只编译**遗留 Swift** 应用，不再参与 GitHub Release。

## GitHub Actions secrets

在仓库 **Settings → Secrets and variables → Actions** 里添加。不要把证书或 `.p8` 提交进 git。六项都要有；缺任何一项，macOS job 失败。

| Secret | 用途 |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | **Developer ID Application** 证书 + 私钥的 `.p12`，先 `base64`。 |
| `DEVELOPER_ID_P12_PASSWORD` | 导出该 `.p12` 时设的密码。 |
| `APPLE_TEAM_ID` | 十位 Team ID。本仓库脚本注释里是 `B5W7AL6CG9`，以 [developer.apple.com/account](https://developer.apple.com/account) 显示的为准。 |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API 密钥的 Key ID。 |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID（UUID）。 |
| `APP_STORE_CONNECT_API_KEY_P8` | `AuthKey_<KEY_ID>.p8` 的 **全文**（含 `BEGIN PRIVATE KEY`）。 |

### 证书（`.p12`）

1. 加入 [Apple Developer Program](https://developer.apple.com/programs/)（个人免费账号 **不能** 出 Developer ID，也就不能公证分发）。
2. Certificates 里创建 **Developer ID Application**（不要用 Apple Development / Apple Distribution）。
3. 在本机钥匙串里导出该证书 **和私钥** 为 `.p12`，设密码。
4. 编码后贴进 secret（不要把 `.p12` 提交进仓库）：

```sh
base64 -i DeveloperID.p12 | pbcopy    # Intel / 旧 macOS 也可能是 base64 -i
# 或
base64 < DeveloperID.p12 | pbcopy
```

CI 会把证书导入临时钥匙串。`Scripts/make-macos-dmg.sh` 用 `Developer ID Application` 从里到外签名 Flutter 的 frameworks / dylib / `.app`（Hardened Runtime + timestamp），再签 DMG。

GitHub DMG **不**嵌入 Mac App Store 描述文件，也 **不**带 App Sandbox。`path_provider` 因此写到 `~/Library/Application Support/PyCal/`，和 README 里的桌面路径一致。商店包是另一条线，见 [mac-app-store.md](mac-app-store.md)。

### 公证（App Store Connect API 密钥）

API 密钥没有 Apple ID 登录 / 双重认证，适合 CI。比 `notarytool store-credentials` 的 app-specific password 更稳。

1. [App Store Connect → Users and Access → Integrations → Team Keys](https://appstoreconnect.apple.com/access/integrations/api) 创建密钥。
2. 角色至少 **Developer**（或 Admin / App Manager）。
3. 下载 **一次** `.p8`，整段粘进 `APP_STORE_CONNECT_API_KEY_P8`。
4. Key ID、Issuer ID 分别填另外两个 secret。

公证顺序：先把已签名的 App 打成 zip 提交并 staple，再打 DMG，签 DMG，提交 DMG 并 staple。这样拖到 Applications 的那一份 App 离线也带着 ticket。

### CI 怎么决定签不签、公不公证

`Scripts/lib-macos-release.sh` 的 `pycal_release_mode` 和以前一样区分 secrets。Flutter 的 macOS job 在此之上只接受 **notarized**：

| 仓库 secrets | `pycal_release_mode` | Flutter macOS job |
| --- | --- | --- |
| 全部为空 | `unsigned` | **失败**。不上传 zip，也不上传未签名 DMG。 |
| 只配了一部分 | 直接失败 | **失败**，避免发出版本却误以为已公证。 |
| 只有 Developer ID、没有公证密钥 | CI 里失败（除非本机或显式 `ALLOW_SIGNED_WITHOUT_NOTARY=1`） | **失败**。签过名但没公证的下载照样被 Gatekeeper 拦。 |
| 签名 + 公证六项都齐 | `notarized` | 签名 App → 公证并 staple App → 打 DMG → 签名、公证并 staple DMG。这是「双击就能开」的路径。 |

本地脚本在没有身份时仍可写出未签名 DMG，并在终端说明 Gatekeeper 会拦截。这只方便本机看布局，不是 Release 产物。

公证成功后，把 App 拖到 DMG 里的 **Applications** 符号链接即可。仓库里的 `Scripts/首次打开.command` 和 `Scripts/InstallToUserApplications.applescript` 只供本机调试，**不会**打进发布 DMG。

## 公证 / 双击仍失败时查什么

- **不是 Developer ID Application**：Apple Development 只能给本机/设备调试，不能给外发 DMG 公证。
- **`.p12` 没带私钥**：CI 会报找不到 `Developer ID Application` identity。重新从钥匙串导出「证书 + 私钥」。
- **Team ID 和证书不一致**：`APPLE_TEAM_ID` 必须是该 Developer ID 括号里的十位 ID。签名后脚本会核对每个 framework / `.app` 的 `TeamIdentifier`。
- **Flutter 嵌套代码仍是 ad-hoc**：只签最外层 `.app` 不够。`pycal_codesign_app` 按深度先签 frameworks、dylib、bundle，再签 `PyCal.app`。
- **Hardened Runtime**：公证要求启用。签名使用 `codesign --options runtime --timestamp`。
- **App Sandbox**：直接分发这条线不传 entitlements。沙盒是受限权限，没有描述文件时公证会被拒。不要把 `macos/Runner/Release.entitlements` 接到 DMG 签名上。
- **API 密钥权限不够或 `.p8` 只下过一次丢了**：只能作废重建。
- **`notarytool` 网络**：runner 要能访问 Apple 公证服务；失败日志里有 RequestID，用 `xcrun notarytool log` 看具体拒因。
- **没 staple**：公证过了但没钉票，离线或刚下载时仍可能失败。workflow 在 App 和 DMG 上都会 `stapler staple`。
- **公司 MDM / 限制模式**：个别机器即使用户打开公证过的 App 也会被策略拦截。这不是再清一遍 xattr 能解决的，需要 IT。
- **把 `.app` 从「隔离的」未公证 DMG 里拖出来**：quarantine 会跟着走。发公证版即可。
- **iOS / Mac App Store**：本流程只做 macOS 直接分发（Developer ID + 公证）。商店上架是另一条线（App Sandbox + Apple Distribution + Transporter），见 [mac-app-store.md](mac-app-store.md)。不要用 `notarytool` 交商店包，也不要把 Apple Distribution 证书接到本 DMG workflow。两条线共用 Bundle ID **`com.liuzhuoling.pycal`**。

## DMG 里有什么

- `PyCal.app` — Flutter release 构建。营销版本号是 tag 的 `X.Y.Z`（预发布 tag 的文件名可以带后缀，短版本号仍是三段数字）。
- `Applications` — 指向 `/Applications` 的符号链接，拖进去安装。

脚本：

- `Scripts/make-macos-dmg.sh` — 打 `PyCal-$version.dmg`（`hdiutil` 到 UDZO）。有身份就从里到外签；有公证凭证就提交并 staple。`PYCAL_DMG_VERSION` 只改文件名。
- `Scripts/lib-macos-release.sh` — 版本号、secrets 是否配齐、`notarytool` / `stapler`、嵌套签名。
- `Scripts/ci-import-signing.sh` — CI 把 `.p12` 推进临时钥匙串，job 结束时删掉。
- `Scripts/build-macos-app.sh`、`Scripts/run-macos.sh` — 遗留 Swift 的本机编译和安装，不参与 Release。
- Mac App Store 归档 / 导出（不动本 DMG 路径）：`Scripts/archive-mac-app-store.sh`，说明见 [mac-app-store.md](mac-app-store.md)。
