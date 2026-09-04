import SwiftUI

struct CalculatorView: View {
    @EnvironmentObject private var store: CalculatorStore
    @State private var input = ""
    @State private var livePreview: Double?
    @State private var selectedLine: CalculatorLine?
    @State private var aliasLine: CalculatorLine?
    @State private var variableLine: CalculatorLine?
    @State private var showingVariableEditor = false
    @State private var showingSettings = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                historyPane
                    .frame(maxWidth: .infinity)
                Rectangle()
                    .fill(AppDesign.hairline)
                    .frame(width: 1)
                variablesPane
                    .frame(width: 238)
            }

            Divider()
            inputBar
        }
        .sheet(item: $aliasLine) { line in
            AliasEditor(line: line) { alias in
                store.setAlias(alias, for: line)
            }
        }
        .sheet(item: $variableLine) { line in
            VariableEditor(result: line.result, initialName: line.assignedVariable ?? "") { name in
                store.saveResultAsVariable(line, name: name)
            }
        }
        .sheet(isPresented: $showingVariableEditor) {
            VariableManager()
                .environmentObject(store)
        }
        .popover(isPresented: $showingSettings, arrowEdge: .top) {
            CalculatorSettings()
                .environmentObject(store)
            .frame(width: 300)
            .padding()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusCalculatorInput)) { _ in
            inputFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCalculatorSettings)) { _ in
            showingSettings = true
        }
        .onAppear {
            // SwiftUI may restore focus to the first historical TextField when
            // reopening a window. Re-assert focus after the list has mounted so
            // a fresh keyboard entry always starts in the new-calculation field.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                inputFocused = true
            }
        }
    }

    private var historyPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("计算记录")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("\(store.lines.count) 条")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    if store.lines.isEmpty {
                        EmptyCalculatorState {
                            inputFocused = true
                        }
                        .padding(.top, 92)
                    } else {
                        let sortedLines = store.lines.sorted {
                            if $0.isPinned != $1.isPinned { return $0.isPinned }
                            return $0.createdAt > $1.createdAt
                        }
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(sortedLines) { line in
                                CalculatorLineRow(
                                    line: line,
                                    isSelected: selectedLine?.id == line.id,
                                    onSelect: { selectedLine = line },
                                    onEdit: { expression in store.updateExpression(expression, for: line) },
                                    onPin: { store.togglePin(line) },
                                    onAlias: { aliasLine = line },
                                    onSaveVariable: { variableLine = line },
                                    onDelete: { store.remove(line) }
                                )
                                .id(line.id)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(0)
            }
            .background(AppDesign.pageBackground)
            .onChange(of: store.lines.count) { _, _ in
                if let first = store.lines.last { withAnimation { proxy.scrollTo(first.id, anchor: .bottom) } }
            }
        }
    }

    private var variablesPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("变量")
                        .font(.system(size: 13, weight: .semibold))
                    Text("在公式中重复使用")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                AppIconButton(systemName: "plus", help: "新建变量", tint: AppDesign.accent) {
                    showingVariableEditor = true
                }
            }
            .padding(.bottom, 14)
            Divider()
                .overlay(AppDesign.hairline)
                .padding(.bottom, 13)

            if store.variables.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "function")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("还没有变量")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("在公式中使用 x = 10，\n或从历史结果保存。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 55)
            } else {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(store.variables) { variable in
                            VariableRow(variable: variable)
                                .environmentObject(store)
                        }
                    }
                }
            }
            Spacer()
            Label("输入 ans 可引用上一行结果", systemImage: "arrow.turn.down.right")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 20)
        .background(AppDesign.surface.opacity(0.32))
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            HStack(alignment: .bottom, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "function")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.tertiary)
                    TextField("输入公式，例如 55 + 88 + 7689 * 543", text: $input, axis: .vertical)
                        .font(.system(size: 17, design: .monospaced))
                        .textFieldStyle(.plain)
                        .focused($inputFocused)
                        .lineLimit(1...4)
                        .onSubmit { submit() }
                    if let livePreview {
                        Text("= \(NumberDisplay.string(livePreview))")
                            .font(.system(size: 17, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppDesign.accent)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppDesign.inputBackground, in: Rectangle())
            }
            .onChange(of: input) { _, newValue in
                livePreview = store.preview(newValue)
            }
            HStack(spacing: 14) {
                Text("+  −  ×  ÷  //  %  **  ( )  ·  abs  sqrt  sin  log")
                Spacer()
                Text("↵ 保存")
                    .fontWeight(.medium)
                Text("历史 \(store.lines.count)/\(store.historyLimit)")
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 15)
        .background(AppDesign.pageBackground)
    }

    private func submit() {
        guard store.evaluate(input) != nil else { return }
        input = ""
        livePreview = nil
        inputFocused = true
    }
}

private struct CalculatorLineRow: View {
    let line: CalculatorLine
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: (String) -> Bool
    let onPin: () -> Void
    let onAlias: () -> Void
    let onSaveVariable: () -> Void
    let onDelete: () -> Void
    @State private var draftExpression: String
    @State private var editError = ""

    init(
        line: CalculatorLine,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        onEdit: @escaping (String) -> Bool,
        onPin: @escaping () -> Void,
        onAlias: @escaping () -> Void,
        onSaveVariable: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.line = line
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onEdit = onEdit
        self.onPin = onPin
        self.onAlias = onAlias
        self.onSaveVariable = onSaveVariable
        self.onDelete = onDelete
        _draftExpression = State(initialValue: line.expression)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: line.assignedVariable == nil ? "equal.circle" : "arrow.down.to.line.compact")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(line.assignedVariable == nil ? Color.secondary.opacity(0.65) : AppDesign.accent)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.045), in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    TextField("输入公式", text: $draftExpression, axis: .vertical)
                        .font(.system(size: 16, design: .monospaced))
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                        .onChange(of: draftExpression) { _, newValue in
                            if onEdit(newValue) {
                                editError = ""
                            } else if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                editError = "公式暂时无法计算"
                            }
                        }
                        .onChange(of: line.expression) { _, newValue in
                            if draftExpression != newValue { draftExpression = newValue }
                        }
                        .textSelection(.enabled)
                    if !editError.isEmpty {
                        Text(editError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if !line.alias.isEmpty || line.assignedVariable != nil {
                        HStack(spacing: 6) {
                            if !line.alias.isEmpty {
                                Text(line.alias)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                            if let assignedVariable = line.assignedVariable {
                                Label("已保存为 \(assignedVariable)", systemImage: "arrow.down.to.line.compact")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                Spacer(minLength: 15)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("= \(NumberDisplay.string(line.result))")
                        .font(.system(size: 21, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppDesign.accent)
                        .textSelection(.enabled)
                    Text(line.createdAt, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: 10) {
                Spacer()
                AppIconButton(
                    systemName: line.isPinned ? "pin.fill" : "pin",
                    help: line.isPinned ? "取消置顶" : "置顶",
                    tint: line.isPinned ? AppDesign.accent : .secondary,
                    action: onPin
                )
                AppIconButton(systemName: "note.text", help: "备注", action: onAlias)
                AppIconButton(systemName: "function", help: "变量", action: onSaveVariable)
                AppIconButton(systemName: "trash", help: "删除", tint: .red, action: onDelete)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .overlay {
            Rectangle()
                .stroke(isSelected ? AppDesign.accent : AppDesign.hairline, lineWidth: isSelected ? 1.5 : 1)
        }
    }
}

private struct EmptyCalculatorState: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "function")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(AppDesign.accent)
            Text("从一行公式开始")
                .font(.system(size: 16, weight: .semibold))
            Text("每次回车都会留下历史，支持变量、函数和连续计算。")
                .font(.system(size: 12))
                .foregroundStyle(AppDesign.muted)
            Button("开始计算", action: onStart)
                .buttonStyle(.borderedProminent)
                .tint(AppDesign.accent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
    }
}
