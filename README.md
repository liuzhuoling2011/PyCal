# PyCal

PyCal 是一个 macOS 原生 SwiftUI 小工具箱，首版包含两个工具：

- **稿纸计算器**：连续输入并保留历史，支持 `+ - * / // % **`、括号、变量赋值、`ans`（上一行结果）和常用数学函数。输入时会实时预览有效结果，按回车保存到历史；历史默认保存 100 行，可置顶、设置 alias，把任意历史结果保存为变量，历史公式也能直接点击修改并实时重新计算。已关联变量的历史行修改后，变量值会同步更新。
- **时间转换**：纳秒、毫秒、秒三种单位；可直接输入 `YYYY-MM-DD HH:mm:ss` 日期，也可打开原生日期选择器；输入有效值后自动换算；日期与 Unix 时间戳双向转换；时区选择；此刻、零点、每日末快捷操作；实时当前时间戳可复制、暂停和重置。

## 运行

需要 macOS 14 或更高版本，以及 Xcode 16+ / Swift 6：

```sh
swift run PyCal
```

如果从终端启动后窗口没有拿到键盘焦点，推荐使用项目提供的原生 App 启动脚本：

```sh
./Scripts/run-macos.sh
```

脚本会生成 `Build/PyCal.app`，安装到 `/Applications/PyCal.app`，并用 macOS 的 `open` 打开已安装版本。也可以在 Xcode 中打开 `Package.swift` 运行。构建：

```sh
swift build
swift test
```

计算历史与变量会写入 `~/Library/Application Support/PyCal/calculator.json`，不上传到网络。

## 表达式示例

```text
subtotal = 1200
tax = 0.06
subtotal * (1 + tax)
ans + 100
round(3.14159, 2)       # Python 风格的 round(x, ndigits)
```

为方便稿纸输入，`^` 也作为 `**` 的指数运算快捷写法；常用函数包括 `abs`、`sqrt`、`sin`、`cos`、`tan`、`ln`、`log`、`log10`、`exp`、`floor`、`ceil`、`round`、`min`、`max` 和 `pow`。
