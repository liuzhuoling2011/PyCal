import SwiftUI

struct AliasEditor: View {
    let line: CalculatorLine
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var alias: String

    init(line: CalculatorLine, onSave: @escaping (String) -> Void) {
        self.line = line
        self.onSave = onSave
        _alias = State(initialValue: line.alias)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置备注")
                .font(.title3.weight(.semibold))
            Text(line.expression)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            TextField("例如：本月预算", text: $alias)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("保存", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func save() {
        onSave(alias)
        dismiss()
    }
}

struct VariableEditor: View {
    let result: Double
    let initialName: String
    let onSave: (String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var error = ""

    init(result: Double, initialName: String = "", onSave: @escaping (String) -> Bool) {
        self.result = result
        self.initialName = initialName
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("保存结果为变量")
                .font(.title3.weight(.semibold))
            HStack(spacing: 6) {
                Text("结果")
                    .foregroundStyle(.secondary)
                Text("= \(NumberDisplay.string(result))")
                    .font(.system(.body, design: .monospaced))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("变量名")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("例如：tax_rate", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            if !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("保存", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func save() {
        guard onSave(name) else {
            error = "变量名无效或已经存在"
            return
        }
        dismiss()
    }
}

struct VariableManager: View {
    @EnvironmentObject private var store: CalculatorStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var value = ""
    @State private var error = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("管理变量")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("完成") { dismiss() }
            }

            HStack(spacing: 8) {
                TextField("变量名", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("数值", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                AppIconButton(systemName: "plus.circle.fill", help: "添加变量", tint: AppDesign.accent) {
                    guard let number = Double(value), store.upsertVariable(name: name, value: number) else {
                        error = "变量名或数值无效"
                        return
                    }
                    name = ""
                    value = ""
                    error = ""
                }
            }
            if !error.isEmpty {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            if store.variables.isEmpty {
                Text("暂无变量。变量可以直接写在公式中：total = 1200 * (1 + tax)。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                List {
                    ForEach(store.variables) { variable in
                        HStack(spacing: 10) {
                            Text(variable.name)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(NumberDisplay.string(variable.value))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                            AppIconButton(systemName: "doc.on.doc", help: "复制变量名") {
                                Clipboard.copy(variable.name)
                            }
                            AppIconButton(systemName: "trash", help: "删除变量", tint: .red) {
                                store.deleteVariable(variable)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(24)
        .frame(width: 520, height: 430)
    }
}

struct VariableRow: View {
    @EnvironmentObject private var store: CalculatorStore
    let variable: CalculatorVariable

    var body: some View {
        HStack(spacing: 8) {
            Text(variable.name)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
            Spacer()
            Text(NumberDisplay.string(variable.value))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Menu {
                Button("复制变量名") { Clipboard.copy(variable.name) }
                Button("删除变量", role: .destructive) { store.deleteVariable(variable) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct CalculatorSettings: View {
    @EnvironmentObject private var store: CalculatorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("计算器设置")
                .font(.headline)
            Stepper(value: Binding(
                get: { store.historyLimit },
                set: { store.updateHistoryLimit($0) }
            ), in: 10...500, step: 10) {
                HStack {
                    Text("保存历史行数")
                    Spacer()
                    Text("\(store.historyLimit)")
                        .foregroundStyle(.secondary)
                }
            }
            Text("置顶记录不会被普通历史清理。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button("清除未置顶历史", role: .destructive) {
                store.clearUnpinnedHistory()
            }
        }
    }
}
