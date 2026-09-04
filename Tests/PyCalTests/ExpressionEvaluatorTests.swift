import XCTest
@testable import PyCal

final class ExpressionEvaluatorTests: XCTestCase {
    func testPythonPrecedenceAndCalculatorExponentAlias() throws {
        let evaluator = ExpressionEvaluator()
        XCTAssertEqual(try evaluator.evaluate("-2**2").value, -4)
        XCTAssertEqual(try evaluator.evaluate("2**-2").value, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(try evaluator.evaluate("2^5 + 3").value, 35)
    }

    func testFunctionsAndFloorDivision() throws {
        let evaluator = ExpressionEvaluator(variables: ["tax": 0.06])
        XCTAssertEqual(try evaluator.evaluate("round(1200 * (1 + tax))").value, 1272)
        XCTAssertEqual(try evaluator.evaluate("round(3.14159, 2)").value, 3.14, accuracy: 0.000_001)
        XCTAssertEqual(try evaluator.evaluate("-7 // 3").value, -3)
        XCTAssertEqual(try evaluator.evaluate("-7 % 3").value, 2)
    }

    func testAssignmentIsReturnedSeparately() throws {
        let result = try ExpressionEvaluator().evaluate("total = 55 + 88")
        XCTAssertEqual(result.assignment, "total")
        XCTAssertEqual(result.value, 143)
    }

    func testUnknownVariableHasHelpfulError() {
        XCTAssertThrowsError(try ExpressionEvaluator().evaluate("subtotal + tax")) { error in
            XCTAssertEqual(error as? ExpressionError, .unknownVariable("subtotal"))
        }
    }

    @MainActor
    func testPreviewDoesNotPersistIncompleteInput() {
        let store = CalculatorStore()
        XCTAssertEqual(store.preview("6 * 7"), 42)
        XCTAssertNil(store.preview("6 * ("))
    }

    @MainActor
    func testEditingAssignmentCascadesToDependentHistory() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let assignment = CalculatorLine(
            expression: "a = 1 + 2",
            result: 3,
            createdAt: start,
            assignedVariable: "a"
        )
        let dependent = CalculatorLine(
            expression: "a * 10",
            result: 30,
            createdAt: start.addingTimeInterval(1)
        )
        let state = CalculatorState(
            lines: [assignment, dependent],
            variables: [CalculatorVariable(name: "a", value: 3)],
            historyLimit: 100
        )
        let store = CalculatorStore(initialState: state)

        XCTAssertTrue(store.updateExpression("a = 1 + 22", for: assignment))
        XCTAssertEqual(store.variables.first(where: { $0.name == "a" })?.value, 23)
        XCTAssertEqual(store.lines.first(where: { $0.id == assignment.id })?.result, 23)
        XCTAssertEqual(store.lines.first(where: { $0.id == dependent.id })?.result, 230)
    }

    @MainActor
    func testSavedHistoryResultBecomesLiveVariableForDependentRows() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let source = CalculatorLine(expression: "1 + 2", result: 3, createdAt: start)
        let dependent = CalculatorLine(
            expression: "a * 10",
            result: 0,
            createdAt: start.addingTimeInterval(1)
        )
        let store = CalculatorStore(initialState: CalculatorState(lines: [source, dependent]))

        XCTAssertTrue(store.saveResultAsVariable(source, name: "a"))
        XCTAssertEqual(store.lines.first(where: { $0.id == dependent.id })?.result, 30)

        XCTAssertTrue(store.updateExpression("1 + 22", for: source))
        XCTAssertEqual(store.variables.first(where: { $0.name == "a" })?.value, 23)
        XCTAssertEqual(store.lines.first(where: { $0.id == dependent.id })?.result, 230)
    }

    @MainActor
    func testHistoryEditingKeepsIncompleteDraftUntilItBecomesValid() {
        let row = CalculatorLine(expression: "a = 1 + 2", result: 3, assignedVariable: "a")
        let store = CalculatorStore(initialState: CalculatorState(
            lines: [row],
            variables: [CalculatorVariable(name: "a", value: 3)]
        ))

        XCTAssertFalse(store.updateExpression("a = 1 + ", for: row))
        XCTAssertEqual(store.lines.first?.expression, "a = 1 + ")
        XCTAssertEqual(store.lines.first?.result, 3)
        XCTAssertTrue(store.updateExpression("a = 1 + 22", for: row))
        XCTAssertEqual(store.variables.first(where: { $0.name == "a" })?.value, 23)
    }
}
