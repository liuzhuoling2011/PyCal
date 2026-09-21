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

CI（`.github/workflows/flutter.yml`）在 Linux 上运行 `flutter pub get`、`flutter analyze`、`flutter test` 和 `flutter build web`。

## 本地持久化

计算历史与变量写入本机，不上传网络：

- **桌面 / 移动**：应用支持目录下的 `PyCal/calculator.json`（`path_provider` 的 Application Support）。
- **Web**：`shared_preferences` / `localStorage`，键为 `pycal.calculator.json`。

JSON 使用 ISO-8601 时间，与旧版 Swift `JSONEncoder` 默认日期编码不兼容。从 Swift 版升级时历史不会自动导入。

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

## 遗留 Swift 应用

若仍需构建原来的 macOS / iPhone SwiftUI 客户端（Xcode 16+ / Swift 6，macOS 14+，iOS 17+）：

```sh
swift run PyCal
./Scripts/run-macos.sh
swift test
```

macOS DMG、公证和 Mac App Store 流程见 [docs/release.md](docs/release.md) 与 [docs/mac-app-store.md](docs/mac-app-store.md)，目前仍针对 Swift `.app`，尚未改为 Flutter 桌面产物。
