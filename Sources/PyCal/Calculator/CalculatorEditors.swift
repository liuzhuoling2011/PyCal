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
        #if os(iOS)
        NavigationStack {
            Form {
                Section("公式") {
                    Text(line.expression)
                        .font(.system(.body, design: .monospaced))
                }
                Section("备注") {
                    TextField("例如：本月预算", text: $alias)
                        .onSubmit(save)
                }
            }
            .navigationTitle("设置备注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #else
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
                    .tint(AppDesign.ink)
                    .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 360)
        #endif
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
        #if os(iOS)
        NavigationStack {
            Form {
                Section("结果") {
                    Text("= \(NumberDisplay.string(result))")
                        .font(.system(.body, design: .monospaced))
                }
                Section {
                    TextField("例如：tax_rate", text: $name)
                        .formulaKeyboard()
                        .onSubmit(save)
                } header: {
                    Text("变量名")
                } footer: {
                    if !error.isEmpty {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("存为变量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #else
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
                    .tint(AppDesign.ink)
                    .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 360)
        #endif
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
        #if os(iOS)
        NavigationStack {
            Form {
                Section("新建变量") {
                    TextField("变量名", text: $name)
                        .formulaKeyboard()
                    TextField("数值", text: $value)
                        .numericKeyboard()
                    Button("添加") { addVariable() }
                    if !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("已有变量") {
                    if store.variables.isEmpty {
                        Text("暂无变量。可以直接写在公式里：total = 1200 * (1 + tax)。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.variables) { variable in
                            HStack {
                                Text(variable.name)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text(NumberDisplay.string(variable.value))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("删除", role: .destructive) {
                                    store.deleteVariable(variable)
                                }
                                Button("复制") {
                                    Clipboard.copy(variable.name)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("管理变量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #else
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
                AppIconButton(systemName: "plus", help: "添加变量", tint: AppDesign.ink) {
                    addVariable()
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
        #endif
    }

    private func addVariable() {
        guard let number = Double(value), store.upsertVariable(name: name, value: number) else {
            error = "变量名或数值无效"
            return
        }
        name = ""
        value = ""
        error = ""
    }
}

struct VariableRow: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var store: CalculatorStore
    let variable: CalculatorVariable
    @State private var isHovering = false

    private var showsActions: Bool {
        isHovering || AppLayout.isCompact(sizeClass)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(variable.name)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(AppDesign.secondary)
                .lineLimit(1)
            Spacer()
            if showsActions {
                AppIconButton(systemName: "doc.on.doc", help: "复制变量名") {
                    Clipboard.copy(variable.name)
                }
                AppIconButton(systemName: "trash", help: "删除变量", tint: .red) {
                    store.deleteVariable(variable)
                }
            }
            Text(NumberDisplay.string(variable.value))
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(AppDesign.muted)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppDesign.hairline)
                .frame(height: 1)
        }
        .onHover { isHovering = $0 }
    }
}

struct SettingsForm: View {
    @EnvironmentObject private var store: CalculatorStore
    var showsDoneButton = false
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Stepper(value: Binding(
                get: { store.historyLimit },
                set: { store.updateHistoryLimit($0) }
            ), in: 10...500, step: 10) {
                HStack {
                    Text("保存历史行数")
                    Spacer()
                    Text("\(store.historyLimit)")
                        .foregroundStyle(AppDesign.muted)
                }
            }
            .font(.system(size: 13))

            Text("置顶记录不会被普通历史清理。")
                .font(.system(size: 12))
                .foregroundStyle(AppDesign.muted)

            Divider().overlay(AppDesign.hairline)

            Button("清除未置顶历史", role: .destructive) {
                store.clearUnpinnedHistory()
            }
            .font(.system(size: 13))

            if showsDoneButton, let onDismiss {
                HStack {
                    Spacer()
                    Button("完成", action: onDismiss)
                        .buttonStyle(.borderedProminent)
                        .tint(AppDesign.ink)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}

struct SettingsPage: View {
    @EnvironmentObject private var store: CalculatorStore

    var body: some View {
        Form {
            Section {
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
            } footer: {
                Text("置顶记录不会被普通历史清理。")
            }

            Section {
                Button("清除未置顶历史", role: .destructive) {
                    store.clearUnpinnedHistory()
                }
            }
        }
        .navigationTitle("设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct SettingsModal: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("设置")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppDesign.ink)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppDesign.muted)
                            .frame(width: 24, height: 24)
                            .background(AppDesign.iconSelected, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("关闭")
                    .keyboardShortcut(.cancelAction)
                }

                SettingsForm(showsDoneButton: true, onDismiss: onDismiss)
            }
            .padding(22)
            .frame(width: 360)
            .background(AppDesign.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppDesign.hairline, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 24, y: 10)
        }
    }
}
