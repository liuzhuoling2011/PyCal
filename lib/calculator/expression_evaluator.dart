import 'dart:math' as math;

/// Result of evaluating a numeric expression, with an optional assignment target.
class EvaluationResult {
  const EvaluationResult({required this.value, this.assignment});

  final double value;
  final String? assignment;

  @override
  bool operator ==(Object other) =>
      other is EvaluationResult &&
      other.value == value &&
      other.assignment == assignment;

  @override
  int get hashCode => Object.hash(value, assignment);
}

/// Deterministic errors that match the Swift evaluator's messages.
class ExpressionError implements Exception {
  const ExpressionError._(this.kind, this.message, [this.details]);

  final String kind;
  final String message;
  final Object? details;

  factory ExpressionError.emptyExpression() =>
      const ExpressionError._('emptyExpression', '请输入计算公式');

  factory ExpressionError.invalidCharacter(String character, int position) =>
      ExpressionError._(
        'invalidCharacter',
        '第 ${position + 1} 个字符“$character”无法识别',
        (character, position),
      );

  factory ExpressionError.invalidNumber(String number) =>
      ExpressionError._('invalidNumber', '“$number”不是有效数字', number);

  factory ExpressionError.unexpectedToken(String token) =>
      ExpressionError._('unexpectedToken', '“$token”出现在了不正确的位置', token);

  factory ExpressionError.missingClosingParenthesis() =>
      const ExpressionError._('missingClosingParenthesis', '缺少右括号 )');

  factory ExpressionError.unknownVariable(String name) =>
      ExpressionError._('unknownVariable', '变量“$name”尚未定义', name);

  factory ExpressionError.unknownFunction(String name) =>
      ExpressionError._('unknownFunction', '函数“$name”暂不支持', name);

  factory ExpressionError.wrongArgumentCount(String name, String expected) =>
      ExpressionError._(
        'wrongArgumentCount',
        '函数 $name 需要$expected个参数',
        (name, expected),
      );

  factory ExpressionError.divisionByZero() =>
      const ExpressionError._('divisionByZero', '不能除以 0');

  factory ExpressionError.invalidAssignment() =>
      const ExpressionError._('invalidAssignment', '赋值左侧必须是变量名，例如 tax = 0.06');

  factory ExpressionError.nonFiniteResult() =>
      const ExpressionError._('nonFiniteResult', '计算结果超出可表示范围');

  @override
  String toString() => message;

  @override
  bool operator ==(Object other) =>
      other is ExpressionError && other.kind == kind && other.details == details;

  @override
  int get hashCode => Object.hash(kind, details);
}

bool isValidVariableName(String name) {
  if (name.isEmpty) return false;
  final chars = _chars(name);
  if (!_isIdentStart(chars.first)) return false;
  return chars.every(_isIdentContinue);
}

/// A small, deterministic Python-style numeric expression evaluator.
///
/// Supported operators: `+ - * / // % **`, parentheses, assignments and a
/// focused set of math functions. `^` is accepted as a calculator-friendly
/// alias for exponentiation.
class ExpressionEvaluator {
  const ExpressionEvaluator({this.variables = const {}});

  final Map<String, double> variables;

  EvaluationResult evaluate(String source) {
    final normalized = source
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('，', ',');

    final tokens = _Lexer(normalized).tokenize();
    return _Parser(tokens: tokens, variables: variables).parse();
  }
}

enum _TokenKind {
  number,
  identifier,
  plus,
  minus,
  multiply,
  divide,
  floorDivide,
  modulo,
  power,
  leftParen,
  rightParen,
  comma,
  assign,
  end,
}

class _Token {
  const _Token(this.kind, {this.number, this.identifier});

  final _TokenKind kind;
  final double? number;
  final String? identifier;

  String get description {
    switch (kind) {
      case _TokenKind.number:
        return '$number';
      case _TokenKind.identifier:
        return identifier ?? '';
      case _TokenKind.plus:
        return '+';
      case _TokenKind.minus:
        return '-';
      case _TokenKind.multiply:
        return '*';
      case _TokenKind.divide:
        return '/';
      case _TokenKind.floorDivide:
        return '//';
      case _TokenKind.modulo:
        return '%';
      case _TokenKind.power:
        return '**';
      case _TokenKind.leftParen:
        return '(';
      case _TokenKind.rightParen:
        return ')';
      case _TokenKind.comma:
        return ',';
      case _TokenKind.assign:
        return '=';
      case _TokenKind.end:
        return '公式末尾';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _Token &&
      other.kind == kind &&
      other.number == number &&
      other.identifier == identifier;

  @override
  int get hashCode => Object.hash(kind, number, identifier);
}

class _Lexer {
  _Lexer(String source) : characters = _chars(source);

  final List<String> characters;
  var index = 0;

  List<_Token> tokenize() {
    final tokens = <_Token>[];

    while (index < characters.length) {
      final character = characters[index];

      if (_isWhitespace(character)) {
        index += 1;
        continue;
      }

      if (_isDigit(character) || character == '.') {
        tokens.add(_readNumber());
        continue;
      }

      if (_isIdentStart(character)) {
        tokens.add(_readIdentifier());
        continue;
      }

      switch (character) {
        case '+':
          tokens.add(const _Token(_TokenKind.plus));
        case '-':
          tokens.add(const _Token(_TokenKind.minus));
        case '*':
          if (_peekNext() == '*') {
            index += 1;
            tokens.add(const _Token(_TokenKind.power));
          } else {
            tokens.add(const _Token(_TokenKind.multiply));
          }
        case '/':
          if (_peekNext() == '/') {
            index += 1;
            tokens.add(const _Token(_TokenKind.floorDivide));
          } else {
            tokens.add(const _Token(_TokenKind.divide));
          }
        case '%':
          tokens.add(const _Token(_TokenKind.modulo));
        case '^':
          tokens.add(const _Token(_TokenKind.power));
        case '(':
          tokens.add(const _Token(_TokenKind.leftParen));
        case ')':
          tokens.add(const _Token(_TokenKind.rightParen));
        case ',':
          tokens.add(const _Token(_TokenKind.comma));
        case '=':
          tokens.add(const _Token(_TokenKind.assign));
        default:
          throw ExpressionError.invalidCharacter(character, index);
      }
      index += 1;
    }

    tokens.add(const _Token(_TokenKind.end));
    return tokens;
  }

  _Token _readNumber() {
    final start = index;
    var sawDot = false;
    var sawExponent = false;

    while (index < characters.length) {
      final current = characters[index];
      if (_isDigit(current) || current == '_') {
        index += 1;
      } else if (current == '.' && !sawDot && !sawExponent) {
        sawDot = true;
        index += 1;
      } else if ((current == 'e' || current == 'E') && !sawExponent) {
        sawExponent = true;
        index += 1;
        if (index < characters.length &&
            (characters[index] == '+' || characters[index] == '-')) {
          index += 1;
        }
      } else {
        break;
      }
    }

    final raw = characters.sublist(start, index).join();
    final cleaned = raw.replaceAll('_', '');
    final value = double.tryParse(cleaned);
    if (cleaned == '.' || value == null) {
      throw ExpressionError.invalidNumber(raw);
    }
    return _Token(_TokenKind.number, number: value);
  }

  _Token _readIdentifier() {
    final start = index;
    while (index < characters.length) {
      final current = characters[index];
      if (!_isIdentContinue(current)) break;
      index += 1;
    }
    return _Token(
      _TokenKind.identifier,
      identifier: characters.sublist(start, index).join(),
    );
  }

  String? _peekNext() {
    final next = index + 1;
    return next < characters.length ? characters[next] : null;
  }
}

class _Parser {
  _Parser({required this.tokens, required this.variables});

  final List<_Token> tokens;
  final Map<String, double> variables;
  var index = 0;

  EvaluationResult parse() {
    if (current.kind == _TokenKind.end) {
      throw ExpressionError.emptyExpression();
    }

    String? assignment;
    if (current.kind == _TokenKind.identifier && peek.kind == _TokenKind.assign) {
      final name = current.identifier!;
      if (!isValidVariableName(name)) {
        throw ExpressionError.invalidAssignment();
      }
      assignment = name;
      advance();
      advance();
    } else if (tokens
        .take(tokens.length - 1)
        .any((token) => token.kind == _TokenKind.assign)) {
      throw ExpressionError.invalidAssignment();
    }

    final value = parseAdditive();
    if (current.kind != _TokenKind.end) {
      if (current.kind == _TokenKind.rightParen) {
        throw ExpressionError.unexpectedToken(')');
      }
      throw ExpressionError.unexpectedToken(current.description);
    }
    if (!value.isFinite) {
      throw ExpressionError.nonFiniteResult();
    }
    return EvaluationResult(value: value, assignment: assignment);
  }

  double parseAdditive() {
    var value = parseMultiplicative();
    while (true) {
      if (match(_TokenKind.plus)) {
        value += parseMultiplicative();
      } else if (match(_TokenKind.minus)) {
        value -= parseMultiplicative();
      } else {
        return value;
      }
    }
  }

  double parseMultiplicative() {
    var value = parseUnary();
    while (true) {
      if (match(_TokenKind.multiply)) {
        value *= parseUnary();
      } else if (match(_TokenKind.divide)) {
        final divisor = parseUnary();
        if (divisor == 0) throw ExpressionError.divisionByZero();
        value /= divisor;
      } else if (match(_TokenKind.floorDivide)) {
        final divisor = parseUnary();
        if (divisor == 0) throw ExpressionError.divisionByZero();
        value = (value / divisor).floorToDouble();
      } else if (match(_TokenKind.modulo)) {
        final divisor = parseUnary();
        if (divisor == 0) throw ExpressionError.divisionByZero();
        value = value - (value / divisor).floorToDouble() * divisor;
      } else {
        return value;
      }
    }
  }

  // Python gives exponentiation higher precedence than unary minus:
  // -2**2 == -(2**2), while 2**-2 is valid.
  double parseUnary() {
    if (match(_TokenKind.plus)) return parseUnary();
    if (match(_TokenKind.minus)) return -parseUnary();
    return parsePower();
  }

  double parsePower() {
    final base = parsePrimary();
    if (match(_TokenKind.power)) {
      return math.pow(base, parseUnary()).toDouble();
    }
    return base;
  }

  double parsePrimary() {
    switch (current.kind) {
      case _TokenKind.number:
        final value = current.number!;
        advance();
        return value;
      case _TokenKind.identifier:
        final name = current.identifier!;
        advance();
        if (match(_TokenKind.leftParen)) {
          return parseFunction(name);
        }
        final variable = variables[name];
        if (variable != null) return variable;
        switch (name.toLowerCase()) {
          case 'pi':
            return math.pi;
          case 'e':
            return math.e;
          case 'tau':
            return 2 * math.pi;
          default:
            throw ExpressionError.unknownVariable(name);
        }
      case _TokenKind.leftParen:
        advance();
        final value = parseAdditive();
        if (!match(_TokenKind.rightParen)) {
          throw ExpressionError.missingClosingParenthesis();
        }
        return value;
      default:
        throw ExpressionError.unexpectedToken(current.description);
    }
  }

  double parseFunction(String name) {
    final arguments = <double>[];
    if (current.kind != _TokenKind.rightParen) {
      do {
        arguments.add(parseAdditive());
      } while (match(_TokenKind.comma));
    }
    if (!match(_TokenKind.rightParen)) {
      throw ExpressionError.missingClosingParenthesis();
    }

    final lowered = name.toLowerCase();
    switch (lowered) {
      case 'abs':
        return _unaryFunction(name, arguments, (x) => x.abs());
      case 'sqrt':
        return _unaryFunction(name, arguments, math.sqrt);
      case 'sin':
        return _unaryFunction(name, arguments, math.sin);
      case 'cos':
        return _unaryFunction(name, arguments, math.cos);
      case 'tan':
        return _unaryFunction(name, arguments, math.tan);
      case 'asin':
        return _unaryFunction(name, arguments, math.asin);
      case 'acos':
        return _unaryFunction(name, arguments, math.acos);
      case 'atan':
        return _unaryFunction(name, arguments, math.atan);
      case 'exp':
        return _unaryFunction(name, arguments, math.exp);
      case 'ln':
        return _unaryFunction(name, arguments, math.log);
      case 'log10':
        return _unaryFunction(name, arguments, (x) => math.log(x) / math.ln10);
      case 'floor':
        return _unaryFunction(name, arguments, (x) => x.floorToDouble());
      case 'ceil':
        return _unaryFunction(name, arguments, (x) => x.ceilToDouble());
      case 'round':
        if (arguments.length != 1 && arguments.length != 2) {
          throw ExpressionError.wrongArgumentCount(name, ' 1 或 2 ');
        }
        if (arguments.length == 1) {
          return _roundToNearestEven(arguments[0]);
        }
        final places = arguments[1];
        if (!places.isFinite ||
            places.roundToDouble() != places ||
            places.abs() > 308) {
          throw ExpressionError.wrongArgumentCount(name, '第二个参数需为整数位数');
        }
        final factor = math.pow(10, places).toDouble();
        return _roundToNearestEven(arguments[0] * factor) / factor;
      case 'pow':
        if (arguments.length != 2) {
          throw ExpressionError.wrongArgumentCount(name, ' 2 ');
        }
        return math.pow(arguments[0], arguments[1]).toDouble();
      case 'log':
        if (arguments.length != 1 && arguments.length != 2) {
          throw ExpressionError.wrongArgumentCount(name, ' 1 或 2 ');
        }
        return arguments.length == 1
            ? math.log(arguments[0])
            : math.log(arguments[0]) / math.log(arguments[1]);
      case 'min':
        if (arguments.isEmpty) {
          throw ExpressionError.wrongArgumentCount(name, '至少 1 ');
        }
        return arguments.reduce(math.min);
      case 'max':
        if (arguments.isEmpty) {
          throw ExpressionError.wrongArgumentCount(name, '至少 1 ');
        }
        return arguments.reduce(math.max);
      default:
        throw ExpressionError.unknownFunction(name);
    }
  }

  double _unaryFunction(
    String name,
    List<double> arguments,
    double Function(double) operation,
  ) {
    if (arguments.length != 1) {
      throw ExpressionError.wrongArgumentCount(name, ' 1 ');
    }
    return operation(arguments[0]);
  }

  _Token get current => tokens[index];
  _Token get peek => tokens[math.min(index + 1, tokens.length - 1)];

  void advance() {
    if (index < tokens.length - 1) index += 1;
  }

  bool match(_TokenKind kind) {
    if (current.kind != kind) return false;
    advance();
    return true;
  }
}

double _roundToNearestEven(double value) {
  if (!value.isFinite) return value;
  final sign = value.isNegative ? -1.0 : 1.0;
  final magnitude = value.abs();
  final integer = magnitude.floorToDouble();
  final fraction = magnitude - integer;
  double rounded;
  if (fraction > 0.5) {
    rounded = integer + 1;
  } else if (fraction < 0.5) {
    rounded = integer;
  } else {
    rounded = integer % 2 == 0 ? integer : integer + 1;
  }
  return rounded * sign;
}

List<String> _chars(String source) =>
    source.runes.map(String.fromCharCode).toList(growable: false);

bool _isWhitespace(String character) => RegExp(r'^\s$').hasMatch(character);

bool _isDigit(String character) => RegExp(r'^\p{Nd}$', unicode: true).hasMatch(character);

bool _isIdentStart(String character) =>
    character == '_' || RegExp(r'^\p{L}$', unicode: true).hasMatch(character);

bool _isIdentContinue(String character) =>
    _isIdentStart(character) || _isDigit(character);
