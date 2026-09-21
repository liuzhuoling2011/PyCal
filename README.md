# PyCal

PyCal 是一个跨平台小工具箱，现以 **Flutter** 为主要实现，可运行于 macOS、Windows、Linux、iOS、Android 和 Web。首版包含两个工具：

- **稿纸计算器**：连续输入并保留历史，支持 `+ - * / // % **`、括号、变量赋值、`ans`（上一行结果）和常用数学函数。输入时会实时预览有效结果，按回车保存到历史；历史默认保存 100 行，可置顶、设置 alias，把任意历史结果保存为变量，历史公式也能直接点击修改并实时重新计算。已关联变量的历史行修改后，变量值会同步更新。
- **时间转换**：纳秒、毫秒、秒三种单位；可直接输入 `YYYY-MM-DD HH:mm:ss` 日期（也支持斜杠和省略秒），也可打开日期选择器；输入有效值后自动换算；日期与 Unix 时间戳双向转换；时区选择；此刻、零点、每日末快捷操作；实时当前时间戳可复制、暂停和重置。

原生 SwiftUI（macOS / iPhone）代码仍保留在 `Sources/PyCal` 与 `PyCal.xcodeproj`，仅作为过渡期对照，**不再是默认入口**。

## 运行

需要 [Flutter](https://docs.flutter.dev/install) 3.24+（开发时使用 3.47 / Dart 3.13）。

```sh
flutter pub get
```

桌面：

```sh
flutter run -d macos
flutter run -d windows
flutter run -d linux
```

移动端：

```sh
flutter run -d ios
flutter run -d android
```

Web：

```sh
flutter run -d chrome
# 或
flutter run -d web-server --web-port 8080
```

构建 Web 静态产物：

```sh
flutter build web
```

产物在 `build/web/`。

### 表达式示例

```text
subtotal = 1200
tax = 0.06
subtotal * (1 + tax)
ans + 100
round(3.14159, 2)       # Python 风格的 round(x, ndigits)
```

为方便稿纸输入，`^` 也作为 `**` 的指数运算快捷写法；常用函数包括 `abs`、`sqrt`、`sin`、`cos`、`tan`、`ln`、`log`、`log10`、`exp`、`floor`、`ceil`、`round`、`min`、`max` 和 `pow`。

## 测试

```sh
flutter test
flutter analyze
```

计算与时间换算的核心逻辑在纯 Dart 中（`lib/calculator/`、`lib/time_converter/time_converter_store.dart`），不依赖 UI。测试从原来的 Swift XCTest 移植并扩展，见 `test/expression_evaluator_test.dart` 与 `test/time_converter_test.dart`。

CI（`.github/workflows/flutter.yml`）在 push / pull request 上运行 `flutter pub get`、`flutter analyze`、`flutter test` 和 `flutter build web`。

推送 `vX.Y.Z` tag 时，`.github/workflows/flutter-release.yml` 会先再跑一遍 analyze 和 test，再并行构建各平台并上传到该 tag 的 GitHub Release。见下方「发布」。

## 本地持久化

计算历史与变量写入本机，不上传网络：

- **桌面 / 移动**：应用支持目录下的 `PyCal/calculator.json`（`path_provider` 的 Application Support）。
- **Web**：`shared_preferences` / `localStorage`，键为 `pycal.calculator.json`。

JSON 使用 ISO-8601 时间，与旧版 Swift `JSONEncoder` 默认日期编码不兼容。从 Swift 版升级时历史不会自动导入。

Web CanvasKit 使用打包的 Noto Sans SC 子集（`assets/fonts/NotoSansSC-UI.ttf`，SIL OFL）渲染中文界面文案。子集只覆盖应用标签；用户输入的罕见汉字可能要等 Flutter 引擎回退字体加载后才完整显示。

## 项目结构

```text
lib/
  main.dart
  app.dart                          # 桌面侧栏 / 移动底栏
  calculator/                       # 表达式引擎、稿纸 store、UI
  time_converter/                   # 时间换算 store、UI
  settings/
  theme/
test/                               # flutter test
Sources/PyCal/                      # 遗留 SwiftUI
Tests/PyCalTests/                   # 遗留 XCTest
```

## 发布

推送符合 `vX.Y.Z` 的 tag（例如 `v0.2.1`，可选后缀 `v0.2.1-rc.1`）会同时触发两条 workflow：

1. **`.github/workflows/flutter-release.yml`** — 先在 Linux 上跑 `flutter analyze` 和 `flutter test`。通过后并行构建 Web、Linux x64、Windows x64、macOS、Android，以及未签名 iOS。全部必需平台成功后，把产物挂到该 tag 的 GitHub Release。
2. **`.github/workflows/release-dmg.yml`** — 遗留 Swift macOS DMG（配齐 secrets 时 Developer ID 签名并公证）。这条 workflow 保持原样，不负责 Flutter 产物。

也可以在 Actions 里手动运行 **Flutter release**，并填写已经存在的 tag。手动运行时构建的是这个 tag，不是你点运行时所在的分支。

版本号从 tag 解析（`v0.2.1` → `0.2.1`），用 `flutter build --build-name` / `--build-number` 写入各平台产物。仓库里的 `pubspec.yaml` 仍是开发版本号，发布 job 不会改它。不需要 Apple Developer ID 或 Play 上传密钥。

若该 tag 的 Release 已经存在（手动创建，或由 Swift DMG workflow 先创建），Flutter 发布只会用 `gh release upload --clobber` **覆盖同名文件**，不会删除其他附件，尤其不会删掉 `PyCal-<version>.dmg`。Release 还不存在时，会新建一个并写上 Flutter 多平台说明。两条 workflow 都会改 Release 正文：后结束的那条会覆盖说明文字，但不会删掉另一条已经上传的文件。

| 产物 | 内容 |
| --- | --- |
| `PyCal-<version>-web.tar.gz` | `flutter build web --release` 的静态站点。解压后直接托管该目录。 |
| `PyCal-<version>-linux-x64.tar.gz` | Linux x64 release bundle（`build/linux/x64/release/bundle`）。解压后运行 `./pycal`。 |
| `PyCal-<version>-windows-x64.zip` | Windows x64。未签名，首次打开时 SmartScreen 可能提示。 |
| `PyCal-<version>-macos.zip` | Flutter `PyCal.app`，只有 ad-hoc 签名，没有公证。从浏览器下载后 Gatekeeper 会拦截普通双击。对本份 App Control-click → **Open**，或只清掉这一份的隔离属性：`xattr -dr com.apple.quarantine PyCal.app`。这不是公证过的 DMG。 |
| `PyCal-<version>-android.apk` | release APK，使用 **debug** 签名（`android/app/build.gradle.kts` 里的 `signingConfig`；CI 没有 Play 上传密钥）。可以侧载，不能上架 Play。 |
| `PyCal-<version>-ios-unsigned.zip` | `flutter build ios --release --no-codesign` 打出的 `Runner.app`。未签名，不能直接装到设备。App Store 签名不在本 workflow 范围内。iOS 构建失败不会让其他平台的发布失败。 |

iOS 以外的平台是发布成功的必要条件。构建产物也会留在该次 Actions run 的 artifacts 里，方便在 Release 上传之前查看。

## 遗留 Swift 应用

若仍需构建原来的 macOS / iPhone SwiftUI 客户端（Xcode 16+ / Swift 6，macOS 14+，iOS 17+）：

```sh
swift run PyCal
./Scripts/run-macos.sh
swift test
```

遗留 Swift 应用的 macOS DMG、公证和 Mac App Store 流程见 [docs/release.md](docs/release.md) 与 [docs/mac-app-store.md](docs/mac-app-store.md)。Flutter 桌面 zip 由上面的发布 workflow 单独产出，不会替换这条 Swift DMG 流程。
