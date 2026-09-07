# macOS 发布（GitHub Release + DMG）

推送符合 `vX.Y.Z` 的 git tag 后，`.github/workflows/release-dmg.yml` 会在 `macos-latest` 上构建 `PyCal.app`、打成 `PyCal-X.Y.Z.dmg`，并挂到 GitHub Release。

**真正能让同事下载后双击打开的，只有 Developer ID 签名 + Apple 公证（notarization）+ staple。** 没有配齐 secrets 时，workflow 仍会发布 **未公证** 的 DMG，Release 说明会写明：Gatekeeper 仍会拦截，需要右键打开或对本份 App 做 `xattr`，**不要**宣称可以双击。

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

`xattr -cr` 的作用是去掉 **这一份文件** 上的 `com.apple.quarantine`，不是关闭系统安全策略。同事机器上「必须 xattr 才能开」= 产物没有过公证，只是隔离评估没过。

## 切一版

版本号以 tag 为准，写入 `CFBundleShortVersionString` 和 `CFBundleVersion`。

```sh
git checkout main
git pull
git tag v0.1.0
git push origin v0.1.0
```

只推 tag 即可（`git push --tags` 也会把本地新 tag 推上去）。tag 格式：`v` + 三段数字，例如 `v0.1.0`。可选后缀：`v0.1.0-rc.1`。

Actions 成功后，打开该 tag 的 GitHub Release，下载 `PyCal-0.1.0.dmg`。

本地等价步骤：

```sh
export PYCAL_VERSION=0.1.0
./Scripts/build-macos-app.sh
./Scripts/make-macos-dmg.sh Build/PyCal.app Build
```

开发用（编完装到 `/Applications` 或 `~/Applications` 并打开）：

```sh
./Scripts/run-macos.sh
```

## GitHub Actions secrets

在仓库 **Settings → Secrets and variables → Actions** 里添加。不要把证书或 `.p8` 提交进 git。

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

CI 会把证书导入临时钥匙串，并用 `Developer ID Application` 身份给 App 和 DMG 签名（Hardened Runtime + timestamp）。

### 公证（推荐 App Store Connect API 密钥）

API 密钥没有 Apple ID 登录 / 双重认证，适合 CI。比 `notarytool store-credentials` 的 app-specific password 更稳。

1. [App Store Connect → Users and Access → Integrations → Team Keys](https://appstoreconnect.apple.com/access/integrations/api) 创建密钥。
2. 角色至少 **Developer**（或 Admin / App Manager）。
3. 下载 **一次** `.p8`，整段粘进 `APP_STORE_CONNECT_API_KEY_P8`。
4. Key ID、Issuer ID 分别填另外两个 secret。

本机手动公证仍可用钥匙串 profile（Team ID 以账号为准）：

```sh
xcrun notarytool store-credentials pycal-notary --apple-id YOUR_APPLE_ID --team-id B5W7AL6CG9
NOTARY_PROFILE=pycal-notary ./Scripts/make-macos-dmg.sh Build/PyCal.app Build
```

### CI 怎么决定签不签、公不公证

| 仓库 secrets | 行为 |
| --- | --- |
| 全部为空 | 打 **未签名** DMG，Release 带警告。同事仍需右键打开 / `xattr`。 |
| 签名 + 公证六项都齐 | 签名 App → 公证并 staple App → 打 DMG → 签名、公证并 staple DMG。这是「双击就能开」的路径。 |
| 只配了一部分 | **失败**，避免发出版本却误以为已公证。 |
| 只有 Developer ID、没有公证密钥 | CI **失败**。签过名但没公证的下载照样拦。本地或刻意覆盖可设 `ALLOW_SIGNED_WITHOUT_NOTARY=1`。 |

公证成功后，把 App 拖到 DMG 里的 **Applications** 符号链接即可。未公证的 DMG 同样只有 App 和该链接；不要关 Gatekeeper，对本份 App 右键打开或 `xattr`。仓库里的 `Scripts/首次打开.command` 和 `Scripts/InstallToUserApplications.applescript` 只供本机调试，**不会**打进发布 DMG。

## 公证 / 双击仍失败时查什么

- **不是 Developer ID Application**：Apple Development 只能给本机/设备调试，不能给外发 DMG 公证。
- **`.p12` 没带私钥**：CI 会报找不到 `Developer ID Application` identity。重新从钥匙串导出「证书 + 私钥」。
- **Team ID 和证书不一致**：`APPLE_TEAM_ID` 必须是该 Developer ID 括号里的十位 ID。
- **Hardened Runtime**：公证要求启用。构建脚本用 `codesign --options runtime`。
- **API 密钥权限不够或 `.p8` 只下过一次丢了**：只能作废重建。
- **`notarytool` 网络**：runner 要能访问 Apple 公证服务；失败日志里有 RequestID，用 `xcrun notarytool log` 看具体拒因。
- **没 staple**：公证过了但没钉票，离线或刚下载时仍可能失败。workflow 在 App 和 DMG 上都会 `stapler staple`。
- **公司 MDM / 限制模式**：个别机器即使用户打开公证过的 App 也会被策略拦截。这不是再清一遍 xattr 能解决的，需要 IT。
- **把 `.app` 从「隔离的」未公证 DMG 里拖出来**：quarantine 会跟着走。要么发公证版，要么对本份 App 右键打开或 `xattr`。
- **iOS / App Store**：本流程只做 macOS 直接分发。不上传 App Store Connect，也不打 iOS ipa。

## DMG 里有什么

- `PyCal.app` — 版本号来自 tag。
- `Applications` — 指向 `/Applications` 的符号链接，拖进去安装。

脚本：

- `Scripts/build-macos-app.sh` — `xcodebuild` 打 universal Release `.app`，失败则退回 `swift build`。
- `Scripts/make-macos-dmg.sh` — 打 `PyCal-$version.dmg`（`hdiutil create` / `convert` 到 UDZO）。有身份就签；有公证凭证就提交并 staple。
- `Scripts/ci-import-signing.sh` — CI 把 `.p12` 推进临时钥匙串。
- `Scripts/run-macos.sh` — 本地编、安装、打开。
