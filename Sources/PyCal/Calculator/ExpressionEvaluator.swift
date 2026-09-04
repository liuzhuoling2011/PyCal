import Foundation

struct EvaluationResult: Equatable {
    let value: Double
    let assignment: String?
}

enum ExpressionError: LocalizedError, Equatable {
    case emptyExpression
    case invalidCharacter(Character, Int)
    case invalidNumber(String)
    case unexpectedToken(String)
    case missingClosingParenthesis
    case unknownVariable(String)
    case unknownFunction(String)
    case wrongArgumentCount(name: String, expected: String)
    case divisionByZero
    case invalidAssignment
    case nonFiniteResult

    var errorDescription: String? {
        switch self {
        case .emptyExpression:
            "请输入计算公式"
        case let .invalidCharacter(character, position):
            "第 \(position + 1) 个字符“\(character)”无法识别"
        case let .invalidNumber(number):
            "“\(number)”不是有效数字"
        case let .unexpectedToken(token):
            "“\(token)”出现在了不正确的位置"
        case .missingClosingParenthesis:
            "缺少右括号 )"
        case let .unknownVariable(name):
            "变量“\(name)”尚未定义"
        case let .unknownFunction(name):
            "函数“\(name)”暂不支持"
        case let .wrongArgumentCount(name, expected):
            "函数 \(name) 需要\(expected)个参数"
        case .divisionByZero:
            "不能除以 0"
        case .invalidAssignment:
            "赋值左侧必须是变量名，例如 tax = 0.06"
        case .nonFiniteResult:
            "计算结果超出可表示范围"
        }
    }
}

/// A small, deterministic Python-style numeric expression evaluator.
///
/// Supported operators: `+ - * / // % **`, parentheses, assignments and a
/// focused set of math functions. `^` is accepted as a calculator-friendly
/// alias for exponentiation.
struct ExpressionEvaluator {
    private let variables: [String: Double]

    init(variables: [String: Double] = [:]) {
        self.variables = variables
    }

    func evaluate(_ source: String) throws -> EvaluationResult {
        let normalized = source
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "，", with: ",")

        var lexer = Lexer(normalized)
        let tokens = try lexer.tokenize()
        var parser = Parser(tokens: tokens, variables: variables)
        return try parser.parse()
    }
}

private enum Token: Equatable, CustomStringConvertible {
    case number(Double)
    case identifier(String)
    case plus
    case minus
    case multiply
    case divide
    case floorDivide
    case modulo
    case power
    case leftParen
    case rightParen
    case comma
    case assign
    case end

    var description: String {
        switch self {
        case let .number(value): String(value)
        case let .identifier(name): name
        case .plus: "+"
        case .minus: "-"
        case .multiply: "*"
        case .divide: "/"
        case .floorDivide: "//"
        case .modulo: "%"
        case .power: "**"
        case .leftParen: "("
        case .rightParen: ")"
        case .comma: ","
        case .assign: "="
        case .end: "公式末尾"
        }
    }
}

private struct Lexer {
    let characters: [Character]
    var index = 0

    init(_ source: String) {
        characters = Array(source)
    }

    mutating func tokenize() throws -> [Token] {
        var tokens: [Token] = []

        while index < characters.count {
            let character = characters[index]

            if character.isWhitespace {
                index += 1
                continue
            }

            if character.isNumber || character == "." {
                tokens.append(try readNumber())
                continue
            }

            if character.isLetter || character == "_" {
                tokens.append(readIdentifier())
                continue
            }

            switch character {
            case "+":
                tokens.append(.plus)
            case "-":
                tokens.append(.minus)
            case "*":
                if peekNext() == "*" {
                    index += 1
                    tokens.append(.power)
                } else {
                    tokens.append(.multiply)
                }
            case "/":
                if peekNext() == "/" {
                    index += 1
                    tokens.append(.floorDivide)
                } else {
                    tokens.append(.divide)
                }
            case "%":
                tokens.append(.modulo)
            case "^":
                tokens.append(.power)
            case "(":
                tokens.append(.leftParen)
            case ")":
                tokens.append(.rightParen)
            case ",":
                tokens.append(.comma)
            case "=":
                tokens.append(.assign)
            default:
                throw ExpressionError.invalidCharacter(character, index)
            }
            index += 1
        }

        tokens.append(.end)
        return tokens
    }

    private mutating func readNumber() throws -> Token {
        let start = index
        var sawDot = false
        var sawExponent = false

        while index < characters.count {
            let current = characters[index]
            if current.isNumber || current == "_" {
                index += 1
            } else if current == ".", !sawDot, !sawExponent {
                sawDot = true
                index += 1
            } else if (current == "e" || current == "E"), !sawExponent {
                sawExponent = true
                index += 1
                if index < characters.count, characters[index] == "+" || characters[index] == "-" {
                    index += 1
                }
            } else {
                break
            }
        }

        let raw = String(characters[start..<index])
        let cleaned = raw.replacingOccurrences(of: "_", with: "")
        guard cleaned != ".", let value = Double(cleaned) else {
            throw ExpressionError.invalidNumber(raw)
        }
        return .number(value)
    }

    private mutating func readIdentifier() -> Token {
        let start = index
        while index < characters.count {
            let current = characters[index]
            guard current.isLetter || current.isNumber || current == "_" else { break }
            index += 1
        }
        return .identifier(String(characters[start..<index]))
    }

    private func peekNext() -> Character? {
        let next = index + 1
        return next < characters.count ? characters[next] : nil
    }
}

private struct Parser {
    let tokens: [Token]
    let variables: [String: Double]
    var index = 0

    mutating func parse() throws -> EvaluationResult {
        guard current != .end else { throw ExpressionError.emptyExpression }

        var assignment: String?
        if case let .identifier(name) = current, peek == .assign {
            guard Self.isValidVariableName(name) else { throw ExpressionError.invalidAssignment }
            assignment = name
            advance()
            advance()
        } else if tokens.dropLast().contains(.assign) {
            throw ExpressionError.invalidAssignment
        }

        let value = try parseAdditive()
        guard current == .end else {
            if current == .rightParen { throw ExpressionError.unexpectedToken(")") }
            throw ExpressionError.unexpectedToken(current.description)
        }
        guard value.isFinite else { throw ExpressionError.nonFiniteResult }
        return EvaluationResult(value: value, assignment: assignment)
    }

    private mutating func parseAdditive() throws -> Double {
        var value = try parseMultiplicative()
        while true {
            if match(.plus) {
                value += try parseMultiplicative()
            } else if match(.minus) {
                value -= try parseMultiplicative()
            } else {
                return value
            }
        }
    }

    private mutating func parseMultiplicative() throws -> Double {
        var value = try parseUnary()
        while true {
            if match(.multiply) {
                value *= try parseUnary()
            } else if match(.divide) {
                let divisor = try parseUnary()
                guard divisor != 0 else { throw ExpressionError.divisionByZero }
                value /= divisor
            } else if match(.floorDivide) {
                let divisor = try parseUnary()
                guard divisor != 0 else { throw ExpressionError.divisionByZero }
                value = floor(value / divisor)
            } else if match(.modulo) {
                let divisor = try parseUnary()
                guard divisor != 0 else { throw ExpressionError.divisionByZero }
                value = value - floor(value / divisor) * divisor
            } else {
                return value
            }
        }
    }

    // Python gives exponentiation higher precedence than unary minus:
    // -2**2 == -(2**2), while 2**-2 is valid.
    private mutating func parseUnary() throws -> Double {
        if match(.plus) { return try parseUnary() }
        if match(.minus) { return -(try parseUnary()) }
        return try parsePower()
    }

    private mutating func parsePower() throws -> Double {
        let base = try parsePrimary()
        if match(.power) {
            return pow(base, try parseUnary())
        }
        return base
    }

    private mutating func parsePrimary() throws -> Double {
        switch current {
        case let .number(value):
            advance()
            return value
        case let .identifier(name):
            advance()
            if match(.leftParen) {
                return try parseFunction(name)
            }
            if let value = variables[name] { return value }
            switch name.lowercased() {
            case "pi": return .pi
            case "e": return M_E
            case "tau": return 2 * .pi
            default: throw ExpressionError.unknownVariable(name)
            }
        case .leftParen:
            advance()
            let value = try parseAdditive()
            guard match(.rightParen) else { throw ExpressionError.missingClosingParenthesis }
            return value
        default:
            throw ExpressionError.unexpectedToken(current.description)
        }
    }

    private mutating func parseFunction(_ name: String) throws -> Double {
        var arguments: [Double] = []
        if current != .rightParen {
            repeat {
                arguments.append(try parseAdditive())
            } while match(.comma)
        }
        guard match(.rightParen) else { throw ExpressionError.missingClosingParenthesis }

        let lowered = name.lowercased()
        switch lowered {
        case "abs": return try unaryFunction(name, arguments, abs)
        case "sqrt": return try unaryFunction(name, arguments, sqrt)
        case "sin": return try unaryFunction(name, arguments, sin)
        case "cos": return try unaryFunction(name, arguments, cos)
        case "tan": return try unaryFunction(name, arguments, tan)
        case "asin": return try unaryFunction(name, arguments, asin)
        case "acos": return try unaryFunction(name, arguments, acos)
        case "atan": return try unaryFunction(name, arguments, atan)
        case "exp": return try unaryFunction(name, arguments, exp)
        case "ln": return try unaryFunction(name, arguments, log)
        case "log10": return try unaryFunction(name, arguments, log10)
        case "floor": return try unaryFunction(name, arguments, floor)
        case "ceil": return try unaryFunction(name, arguments, ceil)
        case "round":
            guard arguments.count == 1 || arguments.count == 2 else {
                throw ExpressionError.wrongArgumentCount(name: name, expected: " 1 或 2 ")
            }
            if arguments.count == 1 { return arguments[0].rounded(.toNearestOrEven) }
            let places = arguments[1]
            guard places.isFinite, places.rounded() == places, abs(places) <= 308 else {
                throw ExpressionError.wrongArgumentCount(name: name, expected: "第二个参数需为整数位数")
            }
            let factor = pow(10, places)
            return (arguments[0] * factor).rounded(.toNearestOrEven) / factor
        case "pow":
            guard arguments.count == 2 else {
                throw ExpressionError.wrongArgumentCount(name: name, expected: " 2 ")
            }
            return pow(arguments[0], arguments[1])
        case "log":
            guard arguments.count == 1 || arguments.count == 2 else {
                throw ExpressionError.wrongArgumentCount(name: name, expected: " 1 或 2 ")
            }
            return arguments.count == 1 ? log(arguments[0]) : log(arguments[0]) / log(arguments[1])
        case "min":
            guard !arguments.isEmpty else {
                throw ExpressionError.wrongArgumentCount(name: name, expected: "至少 1 ")
            }
            return arguments.min()!
        case "max":
            guard !arguments.isEmpty else {
                throw ExpressionError.wrongArgumentCount(name: name, expected: "至少 1 ")
            }
            return arguments.max()!
        default:
            throw ExpressionError.unknownFunction(name)
        }
    }

    private func unaryFunction(
        _ name: String,
        _ arguments: [Double],
        _ operation: (Double) -> Double
    ) throws -> Double {
        guard arguments.count == 1 else {
            throw ExpressionError.wrongArgumentCount(name: name, expected: " 1 ")
        }
        return operation(arguments[0])
    }

    private static func isValidVariableName(_ name: String) -> Bool {
        guard let first = name.first, first.isLetter || first == "_" else { return false }
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private var current: Token { tokens[index] }
    private var peek: Token { tokens[min(index + 1, tokens.count - 1)] }

    private mutating func advance() {
        if index < tokens.count - 1 { index += 1 }
    }

    private mutating func match(_ token: Token) -> Bool {
        guard current == token else { return false }
        advance()
        return true
    }
}
