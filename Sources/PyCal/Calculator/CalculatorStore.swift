import Foundation
import SwiftUI

@MainActor
final class CalculatorStore: ObservableObject {
    @Published private(set) var lines: [CalculatorLine] = []
    @Published private(set) var variables: [CalculatorVariable] = []
    @Published var historyLimit: Int = 100

    @Published var lastError: String?

    private let persistence: CalculatorPersistence?

    init() {
        let persistence = CalculatorPersistence()
        self.persistence = persistence
        let state = persistence.load()
        lines = state.lines
        variables = state.variables
        historyLimit = min(max(state.historyLimit, 10), 500)
        trimHistory()
    }

    /// Creates an in-memory store. This is useful for previews and tests, and
    /// deliberately never touches the user's on-disk calculator history.
    init(initialState: CalculatorState) {
        persistence = nil
        lines = initialState.lines
        variables = initialState.variables
        historyLimit = min(max(initialState.historyLimit, 10), 500)
        trimHistory()
    }

    func updateHistoryLimit(_ limit: Int) {
        historyLimit = min(max(limit, 10), 500)
        trimHistory()
        save()
    }

    var variableMap: [String: Double] {
        variables.reduce(into: [:]) { result, variable in
            result[variable.name] = variable.value
        }
    }

    var previousResult: Double? {
        lines.sorted { $0.createdAt > $1.createdAt }.first?.result
    }

    @discardableResult
    func evaluate(_ expression: String) -> CalculatorLine? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = ExpressionError.emptyExpression.localizedDescription
            return nil
        }

        var context = variableMap
        if let previousResult { context["ans"] = previousResult }

        do {
            let evaluated = try ExpressionEvaluator(variables: context).evaluate(trimmed)
            let line = CalculatorLine(
                expression: trimmed,
                result: evaluated.value,
                assignedVariable: evaluated.assignment
            )
            lines.append(line)
            if let assignment = evaluated.assignment {
                upsertVariable(name: assignment, value: evaluated.value, shouldSave: false)
            }
            _ = recalculateHistory()
            trimHistory()
            lastError = nil
            save()
            return line
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    /// Calculates a transient value while the main input is being edited.
    /// It never writes history or surfaces an error, so incomplete formulas
    /// such as `12 * (` are safe to type naturally.
    func preview(_ expression: String) -> Double? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var context = variableMap
        if let previousResult { context["ans"] = previousResult }
        return try? ExpressionEvaluator(variables: context).evaluate(trimmed).value
    }

    func togglePin(_ line: CalculatorLine) {
        guard let index = lines.firstIndex(where: { $0.id == line.id }) else { return }
        lines[index].isPinned.toggle()
        save()
    }

    func setAlias(_ alias: String, for line: CalculatorLine) {
        guard let index = lines.firstIndex(where: { $0.id == line.id }) else { return }
        lines[index].alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    func remove(_ line: CalculatorLine) {
        lines.removeAll { $0.id == line.id }
        save()
    }

    @discardableResult
    func updateExpression(_ expression: String, for line: CalculatorLine) -> Bool {
        guard let index = lines.firstIndex(where: { $0.id == line.id }) else {
            return false
        }

        // Keep the draft exactly as typed, including an empty or incomplete
        // intermediate state. SwiftUI calls this method for every keystroke;
        // rejecting `a = 1 + ` here would immediately overwrite the user's
        // draft and make natural editing impossible.
        lines[index].expression = expression

        // Re-run the paper from top to bottom. This updates the edited row,
        // its linked variable, and every later row that depends on that value.
        let failedRows = recalculateHistory()

        lastError = nil
        save()
        // An invalid draft is still retained so the user can finish typing;
        // the row's previous numeric result remains in place until it becomes
        // valid. Callers may use the return value only to show a soft hint.
        return !failedRows.contains(line.id)
    }

    func clearUnpinnedHistory() {
        lines.removeAll { !$0.isPinned }
        save()
    }

    func saveResultAsVariable(_ line: CalculatorLine, name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidVariableName(clean) else {
            lastError = "变量名只能包含字母、数字和下划线，且不能以数字开头"
            return false
        }
        upsertVariable(name: clean, value: line.result)
        if let index = lines.firstIndex(where: { $0.id == line.id }) {
            lines[index].assignedVariable = clean
        }
        _ = recalculateHistory()
        lastError = nil
        save()
        return true
    }

    @discardableResult
    func upsertVariable(name: String, value: Double, shouldSave: Bool = true) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidVariableName(clean), value.isFinite else {
            lastError = "请输入有效的变量名和有限数字"
            return false
        }
        if let index = variables.firstIndex(where: { $0.name == clean }) {
            variables[index].value = value
            variables[index].updatedAt = .now
        } else {
            variables.append(CalculatorVariable(name: clean, value: value))
        }
        if shouldSave {
            // A manually changed standalone variable should immediately flow
            // through dependent history rows. Linked variables are recomputed
            // from their owning row by recalculateHistory(), so they remain
            // authoritative as well.
            _ = recalculateHistory()
            save()
        }
        return true
    }

    func deleteVariable(_ variable: CalculatorVariable) {
        variables.removeAll { $0.id == variable.id }
        save()
    }

    func renameVariable(_ variable: CalculatorVariable, to name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidVariableName(clean), !variables.contains(where: { $0.name == clean && $0.id != variable.id }) else {
            lastError = "变量名无效或已经存在"
            return false
        }
        guard let index = variables.firstIndex(where: { $0.id == variable.id }) else { return false }
        variables[index].name = clean
        variables[index].updatedAt = .now
        save()
        return true
    }

    private func trimHistory() {
        guard lines.count > historyLimit else { return }
        let pinned = lines.filter(\.isPinned)
        let unpinned = lines.filter { !$0.isPinned }.sorted { $0.createdAt > $1.createdAt }
        let remainingCount = max(historyLimit - pinned.count, 0)
        lines = pinned + Array(unpinned.prefix(remainingCount))
    }

    /// Recalculates all history rows in chronological order. A row's linked
    /// variable is treated as being assigned at that row, which makes edits to
    /// an earlier assignment cascade naturally through later calculations.
    /// Rows that become invalid keep their previous result so one typo does not
    /// destroy the rest of the paper; the returned IDs let the editor show a
    /// soft validation hint while the user continues typing.
    @discardableResult
    private func recalculateHistory() -> Set<UUID> {
        let chronological = lines.sorted { $0.createdAt < $1.createdAt }
        var context = variableMap
        var ownedVariables = Set(chronological.compactMap(\.assignedVariable))
        ownedVariables.forEach { context.removeValue(forKey: $0) }
        context.removeValue(forKey: "ans")
        var failedRows = Set<UUID>()

        for row in chronological {
            guard let index = lines.firstIndex(where: { $0.id == row.id }) else { continue }
            do {
                let evaluated = try ExpressionEvaluator(variables: context).evaluate(lines[index].expression)
                lines[index].result = evaluated.value
                let linkedVariable = evaluated.assignment ?? lines[index].assignedVariable
                lines[index].assignedVariable = linkedVariable
                if let linkedVariable {
                    ownedVariables.insert(linkedVariable)
                    context[linkedVariable] = evaluated.value
                }
                context["ans"] = evaluated.value
            } catch {
                failedRows.insert(row.id)
                if let linkedVariable = lines[index].assignedVariable {
                    ownedVariables.insert(linkedVariable)
                    context[linkedVariable] = lines[index].result
                }
                context["ans"] = lines[index].result
            }
        }

        // Only linked variables are written back. Standalone variables remain
        // untouched, while a changed history assignment gets its new value.
        for name in ownedVariables {
            guard let value = context[name], value.isFinite else { continue }
            if let index = variables.firstIndex(where: { $0.name == name }) {
                variables[index].value = value
                variables[index].updatedAt = .now
            } else {
                variables.append(CalculatorVariable(name: name, value: value))
            }
        }
        return failedRows
    }

    private func isValidVariableName(_ name: String) -> Bool {
        guard let first = name.first, first.isLetter || first == "_" else { return false }
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private func save() {
        persistence?.save(CalculatorState(lines: lines, variables: variables, historyLimit: historyLimit))
    }
}

private struct CalculatorPersistence {
    private let fileURL: URL

    init() {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("PyCal", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("calculator.json")
    }

    func load() -> CalculatorState {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(CalculatorState.self, from: data) else {
            return CalculatorState()
        }
        return state
    }

    func save(_ state: CalculatorState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
