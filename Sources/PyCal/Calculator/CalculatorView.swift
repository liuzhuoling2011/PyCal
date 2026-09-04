import SwiftUI

struct CalculatorView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var store: CalculatorStore
    @State private var input = ""
    @State private var livePreview: CalculatorPreview?
    @State private var selectedLine: CalculatorLine?
    @State private var aliasLine: CalculatorLine?
    @State private var variableLine: CalculatorLine?
    @State private var showingVariableEditor = false
    @State private var showingVariables = false
    @State private var draggingLineID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragInsertionIndex = 0
    @State private var dragStartOrder: [UUID] = []
    @State private var dragStartFrames: [UUID: CGRect] = [:]
    @State private var rowFrames: [UUID: CGRect] = [:]
    @FocusState private var inputFocused: Bool

    private var isCompact: Bool { AppLayout.isCompact(sizeClass) }

    var body: some View {
        Group {
            if isCompact {
                historyPane
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        composer
                    }
            } else {
                VStack(spacing: 0) {
                    ZStack(alignment: .trailing) {
                        historyPane
                            .padding(.trailing, showingVariables ? AppDesign.inspectorWidth + 8 : 0)
                        if showingVariables {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { showingVariables = false }
                            VariableInspector(showingEditor: $showingVariableEditor)
                                .environmentObject(store)
                                .padding(12)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    composer
                }
            }
        }
        .background(AppDesign.canvas)
        .animation(.easeOut(duration: 0.18), value: showingVariables)
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
        .sheet(isPresented: compactVariablesBinding) {
            NavigationStack {
                VariableInspector(showingEditor: $showingVariableEditor, usesSheetChrome: true)
                    .environmentObject(store)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("完成") { showingVariables = false }
                        }
                    }
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusCalculatorInput)) { _ in
            inputFocused = true
        }
        .onAppear {
            #if os(macOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                inputFocused = true
            }
            #endif
        }
        .macOSExitCommand {
            if showingVariables { showingVariables = false }
        }
    }

    private var compactVariablesBinding: Binding<Bool> {
        Binding(
            get: { isCompact && showingVariables },
            set: { if !$0 { showingVariables = false } }
        )
    }

    private var historyPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if store.lines.isEmpty {
                        EmptyCalculatorState {
                            inputFocused = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, isCompact ? 72 : 120)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(store.lines) { line in
                                CalculatorLineRow(
                                    line: line,
                                    isSelected: selectedLine?.id == line.id,
                                    isDragging: draggingLineID == line.id,
                                    onSelect: { selectedLine = line },
                                    onEdit: { expression in store.updateExpression(expression, for: line) },
                                    onPin: { store.togglePin(line) },
                                    onAlias: { aliasLine = line },
                                    onSaveVariable: { variableLine = line },
                                    onDelete: { store.remove(line) },
                                    onReorderDrag: { value in
                                        handleReorderDrag(lineID: line.id, value: value)
                                    }
                                )
                                .id(line.id)
                                .offset(y: liftOffset(for: line.id))
                                .zIndex(draggingLineID == line.id ? 20 : 0)
                                .animation(
                                    draggingLineID == line.id
                                        ? nil
                                        : .interactiveSpring(response: 0.28, dampingFraction: 0.86),
                                    value: dragInsertionIndex
                                )
                                .background {
                                    GeometryReader { proxy in
                                        Color.clear.preference(
                                            key: HistoryRowFrameKey.self,
                                            value: [line.id: proxy.frame(in: .global)]
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, isCompact ? 12 : 20)
                        .padding(.top, isCompact ? 12 : 18)
                        .padding(.bottom, 8)
                        .onPreferenceChange(HistoryRowFrameKey.self) { frames in
                            guard draggingLineID == nil else { return }
                            rowFrames = frames
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.lines.count) { _, _ in
                if let first = store.lines.first { withAnimation { proxy.scrollTo(first.id, anchor: .top) } }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = store.lastError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
            Group {
                if isCompact {
                    VStack(alignment: .leading, spacing: 8) {
                        inputField
                        HStack(spacing: 10) {
                            previewLabelView
                            Spacer(minLength: 8)
                            variablesButton
                            submitButton
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        inputField
                        previewLabelView
                        variablesButton
                        submitButton
                    }
                }
            }
            .padding(.leading, isCompact ? 14 : 16)
            .padding(.trailing, 8)
            .padding(.vertical, isCompact ? 12 : 10)
            .background(AppDesign.paper, in: RoundedRectangle(cornerRadius: AppDesign.composerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.composerRadius, style: .continuous)
                    .stroke(inputFocused ? AppDesign.ink.opacity(0.28) : AppDesign.composerBorder, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.045), radius: 14, y: 6)
            .onChange(of: input) { _, newValue in
                livePreview = store.previewEvaluation(newValue)
            }
        }
        .padding(.horizontal, isCompact ? 12 : 18)
        .padding(.bottom, isCompact ? 10 : 16)
        .padding(.top, 4)
    }

    private var inputField: some View {
        TextField("直接输入计算公式，比如: 5 * (7 + 8)", text: $input, axis: .vertical)
            .font(.system(size: 15, design: .monospaced))
            .textFieldStyle(.plain)
            .focused($inputFocused)
            .lineLimit(1...4)
            .formulaKeyboard()
            .onSubmit { submit() }
    }

    @ViewBuilder
    private var previewLabelView: some View {
        if let livePreview {
            Text(previewLabel(livePreview))
                .font(.system(size: 13.5, weight: .medium, design: .monospaced))
                .foregroundStyle(AppDesign.preview)
                .textSelection(.enabled)
        }
    }

    private var variablesButton: some View {
        Button {
            showingVariables.toggle()
        } label: {
            Text("变量")
                .font(.system(size: 11.5))
                .foregroundStyle(showingVariables ? AppDesign.ink : AppDesign.muted)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: AppDesign.iconRadius, style: .continuous)
                        .fill(showingVariables ? AppDesign.iconSelected : Color.black.opacity(0.045))
                )
        }
        .buttonStyle(.plain)
        .help("变量")
    }

    private var submitButton: some View {
        Button(action: submit) {
            Image(systemName: "return")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(AppDesign.ink, in: RoundedRectangle(cornerRadius: AppDesign.iconRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("保存")
    }

    private func previewLabel(_ preview: CalculatorPreview) -> String {
        let value = NumberDisplay.string(preview.value)
        if let assignment = preview.assignment {
            return "\(assignment) = \(value)"
        }
        return "= \(value)"
    }

    private func handleReorderDrag(lineID: UUID, value: DragGesture.Value?) {
        guard let value else {
            commitReorder()
            return
        }
        if draggingLineID == nil {
            draggingLineID = lineID
            dragStartOrder = store.lines.map(\.id)
            dragStartFrames = rowFrames
            dragInsertionIndex = dragStartOrder.firstIndex(of: lineID) ?? 0
        }
        dragTranslation = value.translation.height
        let nextIndex = insertionIndex(for: value.location.y)
        if nextIndex != dragInsertionIndex {
            dragInsertionIndex = nextIndex
        }
    }

    private func insertionIndex(for currentY: CGFloat) -> Int {
        guard let draggingLineID else { return 0 }
        return dragStartOrder
            .filter { $0 != draggingLineID }
            .filter { (dragStartFrames[$0]?.midY ?? 0) < currentY }
            .count
    }

    private func liftOffset(for id: UUID) -> CGFloat {
        guard let draggingLineID else { return 0 }
        if id == draggingLineID { return dragTranslation }
        guard
            let from = dragStartOrder.firstIndex(of: draggingLineID),
            let selfIndex = dragStartOrder.firstIndex(of: id)
        else { return 0 }
        let height = dragStartFrames[draggingLineID]?.height ?? 0
        let to = dragInsertionIndex
        if from < to, selfIndex > from, selfIndex <= to { return -height }
        if from > to, selfIndex >= to, selfIndex < from { return height }
        return 0
    }

    private func slotTranslation() -> CGFloat {
        guard
            let draggingLineID,
            let startY = dragStartFrames[draggingLineID]?.minY,
            let firstID = dragStartOrder.first,
            let baseY = dragStartFrames[firstID]?.minY
        else { return 0 }
        let before = dragStartOrder
            .filter { $0 != draggingLineID }
            .prefix(dragInsertionIndex)
        let targetY = before.reduce(baseY) { $0 + (dragStartFrames[$1]?.height ?? 0) }
        return targetY - startY
    }

    private func commitReorder() {
        guard let id = draggingLineID else {
            resetDragState()
            return
        }
        let remaining = dragTranslation - slotTranslation()
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            store.moveLine(id: id, toIndex: dragInsertionIndex)
            dragStartOrder = []
            dragStartFrames = [:]
            dragInsertionIndex = 0
            dragTranslation = remaining
        }
        if abs(remaining) < 0.5 {
            resetDragState()
            return
        }
        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.9), completionCriteria: .logicallyComplete) {
            dragTranslation = 0
        } completion: {
            resetDragState()
        }
    }

    private func resetDragState() {
        draggingLineID = nil
        dragTranslation = 0
        dragInsertionIndex = 0
        dragStartOrder = []
        dragStartFrames = [:]
    }

    private func submit() {
        guard store.evaluate(input) != nil else { return }
        input = ""
        livePreview = nil
        inputFocused = true
    }
}

private struct HistoryRowFrameKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct CalculatorLineRow: View {
    let line: CalculatorLine
    let isSelected: Bool
    let isDragging: Bool
    let onSelect: () -> Void
    let onEdit: (String) -> Bool
    let onPin: () -> Void
    let onAlias: () -> Void
    let onSaveVariable: () -> Void
    let onDelete: () -> Void
    let onReorderDrag: (DragGesture.Value?) -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var draftExpression: String
    @State private var editError = ""
    @State private var isHovering = false
    @State private var isEditingExpression = false
    @FocusState private var expressionFocused: Bool

    private var isCompact: Bool { AppLayout.isCompact(sizeClass) }

    init(
        line: CalculatorLine,
        isSelected: Bool,
        isDragging: Bool,
        onSelect: @escaping () -> Void,
        onEdit: @escaping (String) -> Bool,
        onPin: @escaping () -> Void,
        onAlias: @escaping () -> Void,
        onSaveVariable: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onReorderDrag: @escaping (DragGesture.Value?) -> Void
    ) {
        self.line = line
        self.isSelected = isSelected
        self.isDragging = isDragging
        self.onSelect = onSelect
        self.onEdit = onEdit
        self.onPin = onPin
        self.onAlias = onAlias
        self.onSaveVariable = onSaveVariable
        self.onDelete = onDelete
        self.onReorderDrag = onReorderDrag
        _draftExpression = State(initialValue: line.expression)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 8) {
                WindowDragDisabled {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppDesign.faint)
                        .frame(width: 20, height: 28)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                                .onChanged { value in
                                    onReorderDrag(value)
                                }
                                .onEnded { _ in
                                    onReorderDrag(nil)
                                }
                        )
                }
                .frame(width: 20, height: 28)
                .opacity(isCompact || isHovering || isDragging ? 1 : 0)
                .help("拖拽排序")

                expressionEditor

                Spacer(minLength: 12)

                HStack(spacing: 4) {
                    if !isCompact {
                        HStack(spacing: 4) {
                            AppIconButton(
                                systemName: line.isPinned ? "pin.fill" : "pin",
                                help: line.isPinned ? "取消置顶" : "置顶",
                                tint: line.isPinned ? AppDesign.ink : AppDesign.muted,
                                showsHoverCaption: true,
                                action: onPin
                            )
                            AppIconButton(systemName: "square.and.pencil", help: "备注", showsHoverCaption: true, action: onAlias)
                            AppIconButton(systemName: "equal", help: "存为变量", showsHoverCaption: true, action: onSaveVariable)
                            AppIconButton(systemName: "trash", help: "删除", showsHoverCaption: true, action: onDelete)
                        }
                        .opacity(isHovering || isSelected ? 1 : 0)
                        .allowsHitTesting(isHovering || isSelected)
                        .zIndex(1)
                    }

                    Text(NumberDisplay.string(line.result))
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppDesign.ink)
                        .textSelection(.enabled)
                }
            }
            .frame(minHeight: 28)

            if !editError.isEmpty || !line.alias.isEmpty || line.assignedVariable != nil {
                HStack(spacing: 8) {
                    Color.clear.frame(width: 20)
                    if !editError.isEmpty {
                        Text(editError)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                    if !line.alias.isEmpty {
                        Text(line.alias)
                            .font(.system(size: 11))
                            .foregroundStyle(AppDesign.muted)
                    }
                    if let assignedVariable = line.assignedVariable {
                        Text(assignedVariable)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(AppDesign.muted)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.iconRadius, style: .continuous)
                .fill(isDragging ? AppDesign.iconSelected : (isHovering || isSelected ? AppDesign.rowHover : Color.clear))
        )
        .scaleEffect(isDragging ? 1.012 : 1)
        .shadow(color: isDragging ? Color.black.opacity(0.10) : .clear, radius: 12, y: 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu { lineActionsMenu }
        .onChange(of: line.expression) { _, newValue in
            if draftExpression != newValue { draftExpression = newValue }
        }
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var expressionEditor: some View {
        if isCompact && !isEditingExpression {
            Text(draftExpression)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(AppDesign.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    isEditingExpression = true
                    expressionFocused = true
                }
        } else {
            TextField("输入公式", text: $draftExpression, axis: .vertical)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(AppDesign.secondary)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .formulaKeyboard()
                .focused($expressionFocused)
                .onChange(of: draftExpression) { _, newValue in
                    applyDraft(newValue)
                }
                .onChange(of: line.expression) { _, newValue in
                    if draftExpression != newValue { draftExpression = newValue }
                }
                .onChange(of: expressionFocused) { _, focused in
                    if !focused { isEditingExpression = false }
                }
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var lineActionsMenu: some View {
        Button {
            onPin()
        } label: {
            Label(line.isPinned ? "取消置顶" : "置顶", systemImage: line.isPinned ? "pin.slash" : "pin")
        }
        Button {
            onAlias()
        } label: {
            Label("备注", systemImage: "square.and.pencil")
        }
        Button {
            onSaveVariable()
        } label: {
            Label("存为变量", systemImage: "equal")
        }
        Divider()
        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private func applyDraft(_ newValue: String) {
        if onEdit(newValue) {
            editError = ""
        } else if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            editError = "公式暂时无法计算"
        }
    }
}

private struct EmptyCalculatorState: View {
    let onStart: () -> Void

    var body: some View {
        Text("从一行公式开始")
            .font(.system(size: 13))
            .foregroundStyle(AppDesign.muted)
            .frame(maxWidth: .infinity)
            .onTapGesture(perform: onStart)
    }
}

struct VariableInspector: View {
    @EnvironmentObject private var store: CalculatorStore
    @Binding var showingEditor: Bool
    var usesSheetChrome = false

    var body: some View {
        if usesSheetChrome {
            phoneInspector
        } else {
            desktopInspector
        }
    }

    private var phoneInspector: some View {
        List {
            if store.variables.isEmpty {
                Text("公式里直接写名字即可引用")
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
                    .contextMenu {
                        Button {
                            Clipboard.copy(variable.name)
                        } label: {
                            Label("复制变量名", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive) {
                            store.deleteVariable(variable)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("变量")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var desktopInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("变量")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppDesign.ink)
                Spacer()
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppDesign.muted)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("新建变量")
            }
            .padding(.bottom, 8)

            if store.variables.isEmpty {
                Text("公式里直接写名字即可引用")
                    .font(.system(size: 11))
                    .foregroundStyle(AppDesign.faint)
                    .padding(.top, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.variables) { variable in
                            VariableRow(variable: variable)
                                .environmentObject(store)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: AppDesign.inspectorWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.inspectorRadius, style: .continuous)
                .fill(AppDesign.paper)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppDesign.inspectorRadius, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 20, y: 8)
    }
}
