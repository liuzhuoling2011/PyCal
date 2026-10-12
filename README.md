# PyCal

PyCal 是一个跨平台小工具箱，现以 **Flutter** 为主要实现，可运行于 macOS、Windows、Linux、iOS、Android 和 Web。首版包含两个工具：

- **稿纸计算器**：连续输入并保留历史，支持 `+ - * / // % **`、括号、变量赋值、`ans`（上一行结果）和常用数学函数。输入时会实时预览有效结果，按回车保存到历史；历史默认保存 100 行，可置顶、设置 alias，把任意历史结果保存为变量，历史公式也能直接点击修改并实时重新计算。已关联变量的历史行修改后，变量值会同步更新。
- **时间转换**：纳秒、毫秒、秒三种单位；可直接输入 `YYYY-MM-DD HH:mm:ss` 日期（也支持斜杠和省略秒），也可打开日期选择器；输入有效值后自动换算；日期与 Unix 时间戳双向转换；时区选择；此刻、零点、每日末快捷操作；实时当前时间戳可复制、暂停和重置。

原生 SwiftUI（macOS / iPhone）代码仍保留在 `Sources/PyCal` 与 `PyCal.xcodeproj`，仅作为过渡期对照，**不再是默认入口**。

在线试用：https://liuzhuoling2011.github.io/PyCal/

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

CI（`.github/workflows/flutter.yml`）在 push / pull request 上运行 `flutter pub get`、`flutter analyze`、`flutter test` 和 `flutter build web`。这次 web 构建用默认 base href `/`，只检查能否编过，不发布。

推送到 `main` 时，`.github/workflows/pages.yml` 会另外用 `--base-href /PyCal/` 构建并部署到 GitHub Pages。见下方「GitHub Pages」。

推送 `vX.Y.Z` tag 时，`.github/workflows/flutter-release.yml` 会先再跑一遍 analyze 和 test，再并行构建各平台，并把构建成功的产物上传到该 tag 的 GitHub Release。见下方「发布」。

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

## GitHub Pages

线上站点：https://liuzhuoling2011.github.io/PyCal/

推送到 `main`，或在 Actions 里手动运行 **Deploy GitHub Pages**，会跑 [`.github/workflows/pages.yml`](.github/workflows/pages.yml)：

1. `flutter build web --release --base-href /PyCal/`。项目站点挂在 `github.io/PyCal/` 下，base href 必须是 `/PyCal/`，否则脚本和资源会去域名根路径请求而 404。
2. 把 `docs/privacy.html` 和 `docs/support.html` 复制到 `build/web/`，并写入 `.nojekyll`。Flutter Web 产物里有下划线开头的文件；没有 `.nojekyll` 时，Pages 的 Jekyll 会丢掉它们。
3. 用 `actions/configure-pages`、`actions/upload-pages-artifact`（`include-hidden-files: true`，否则 `.nojekyll` 不会进产物）和 `actions/deploy-pages` 发布。部署 job 使用名为 `github-pages` 的 environment。

隐私政策与支持页的地址不变，App Store Connect 可以继续用：

- https://liuzhuoling2011.github.io/PyCal/privacy.html
- https://liuzhuoling2011.github.io/PyCal/support.html

正文仍以 `docs/privacy.html`、`docs/support.html` 为准，部署时复制到站点根目录。两页之间的相对链接不用改。

Release 里的 `PyCal-<version>-web.tar.gz` 是另一份构建，base href 为 `/`，适合解压后放在自己的站点根目录。不要把那份 tarball 直接放到 `/PyCal/` 路径下。

### 把 Pages 源改成 GitHub Actions

`deploy-pages` 只有在 Pages 源是 **GitHub Actions** 时才会成功。若 Settings 里仍是 **Deploy from a branch**（`main` / `/docs`），部署 job 会失败，线上暂时还是 `docs/` 里的静态页。

一次性切换：

1. 打开仓库 **Settings → Pages → Build and deployment**。
2. **Source** 选 **GitHub Actions**。

仓库管理员也可以用 API（把 `build_type` 设为 `workflow`）：

```sh
gh api --method PUT -H "Accept: application/vnd.github+json" \
  /repos/liuzhuoling2011/PyCal/pages \
  -f build_type=workflow
```

在合并引入本 workflow 的提交时再改。提前改掉的话，旧的 `/docs` 站点会停，而 `main` 上还没有这次部署。改完之后，合并进 `main` 的 push 会部署上面的 URL。若那次 run 的 deploy job 在改源之前就已经失败，在 Actions 里重跑 **Deploy GitHub Pages** 即可。不要再把源改回 `main` / `/docs`，否则线上会变回只有隐私页和支持页的旧站点。

## 发布

推送符合 `vX.Y.Z` 的 tag（例如 `v0.2.2`，可选后缀 `v0.2.2-rc.1`）会触发 **`.github/workflows/flutter-release.yml`**：

1. 在 Linux 上跑 `flutter analyze` 和 `flutter test`。
2. 通过后并行构建 Web、Linux x64、Windows x64、macOS、Android。
3. 把**已经构建成功**的产物挂到该 tag 的 GitHub Release。某一个平台失败不会挡住其他平台的附件；Web、Linux、Windows、macOS、Android 任一失败仍会让整次 workflow 变红。

也可以在 Actions 里手动运行 **Flutter release**，并填写已经存在的 tag。手动运行时构建的是这个 tag，不是你点运行时所在的分支。带 `-` 的版本（例如 `v0.2.2-rc.1`）会标成 prerelease。

版本号从 tag 解析（`v0.2.2` → `0.2.2`），用 `flutter build --build-name` / `--build-number` 写入各平台产物。仓库里的 `pubspec.yaml` 仍是开发版本号，发布 job 不会改它。macOS 需要仓库里已经配置的 Developer ID 和 App Store Connect API 密钥；没有配齐时 macOS job 失败，不会再上传一个看起来能安装的 zip。Android 仍然没有 Play 上传密钥。

`gh release upload --clobber` 只覆盖同名文件，不删除该 Release 上的其他附件。`v0.2.1` 以及更早的 tag 仍保留当时上传的文件（包括旧的 Swift `PyCal-<version>.dmg`、ad-hoc 的 `PyCal-<version>-macos.zip` 和 `PyCal-<version>-ios-unsigned.zip`），直到你发布一个新 tag。本 workflow 不会去删那些历史附件。

| 产物 | 内容 |
| --- | --- |
| `PyCal-<version>-web.tar.gz` | `flutter build web --release` 的静态站点，base href 为 `/`。解压后放在站点根目录托管。GitHub Pages 上的在线版是另一份 `--base-href /PyCal/` 构建，见「GitHub Pages」。 |
| `PyCal-<version>-linux-x64.tar.gz` | Linux x64 release bundle（`build/linux/x64/release/bundle`）。解压后运行 `./pycal`。 |
| `PyCal-<version>-windows-x64.zip` | Windows x64。未签名，首次打开时 SmartScreen 可能提示。 |
| `PyCal-<version>.dmg` | Flutter macOS 磁盘映像。Developer ID 签名、Apple 公证并 staple。打开 DMG，把 PyCal 拖到 Applications，再双击。不需要关 Gatekeeper，也不需要 `xattr`。这是 Release 上唯一的 macOS 安装包，沿用原来 Swift DMG 的文件名。 |
| `PyCal-<version>-android.apk` | release APK，使用 **debug** 签名（`android/app/build.gradle.kts` 里的 `signingConfig`；CI 没有 Play 上传密钥）。可以侧载，不能上架 Play。 |

iOS 暂不发布。workflow 不再构建 `PyCal-<version>-ios-unsigned.zip`，也不做 TestFlight / App Store 上传。

签名、公证 secrets 和本地打 DMG 的步骤见 [docs/release.md](docs/release.md)。构建产物也会留在该次 Actions run 的 artifacts 里，方便在 Release 上传之前查看。

## 遗留 Swift 应用

若仍需构建原来的 macOS / iPhone SwiftUI 客户端（Xcode 16+ / Swift 6，macOS 14+，iOS 17+）：

```sh
swift run PyCal
./Scripts/run-macos.sh
swift test
```

GitHub Release 上的 macOS 磁盘映像是 Flutter 版，签名和公证见 [docs/release.md](docs/release.md)。Mac App Store 仍是另一条线，见 [docs/mac-app-store.md](docs/mac-app-store.md)。`./Scripts/run-macos.sh` 只在本机编译安装遗留 Swift 应用，不再往 Release 上传 Swift DMG。
