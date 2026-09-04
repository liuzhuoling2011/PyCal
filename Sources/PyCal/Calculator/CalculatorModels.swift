import Foundation

struct CalculatorLine: Codable, Identifiable, Equatable {
    let id: UUID
    var expression: String
    var result: Double
    var alias: String
    var isPinned: Bool
    var createdAt: Date
    var assignedVariable: String?

    init(
        id: UUID = UUID(),
        expression: String,
        result: Double,
        alias: String = "",
        isPinned: Bool = false,
        createdAt: Date = .now,
        assignedVariable: String? = nil
    ) {
        self.id = id
        self.expression = expression
        self.result = result
        self.alias = alias
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.assignedVariable = assignedVariable
    }
}

struct CalculatorVariable: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var value: Double
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, value: Double, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.value = value
        self.updatedAt = updatedAt
    }
}

struct CalculatorState: Codable {
    var lines: [CalculatorLine] = []
    var variables: [CalculatorVariable] = []
    var historyLimit: Int = 100
}
