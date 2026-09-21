import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class CalculatorLine {
  CalculatorLine({
    String? id,
    required this.expression,
    required this.result,
    this.alias = '',
    this.isPinned = false,
    DateTime? createdAt,
    this.assignedVariable,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String expression;
  double result;
  String alias;
  bool isPinned;
  DateTime createdAt;
  String? assignedVariable;

  CalculatorLine copyWith({
    String? expression,
    double? result,
    String? alias,
    bool? isPinned,
    DateTime? createdAt,
    String? assignedVariable,
    bool clearAssignedVariable = false,
  }) {
    return CalculatorLine(
      id: id,
      expression: expression ?? this.expression,
      result: result ?? this.result,
      alias: alias ?? this.alias,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      assignedVariable:
          clearAssignedVariable ? null : (assignedVariable ?? this.assignedVariable),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'expression': expression,
        'result': result,
        'alias': alias,
        'isPinned': isPinned,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'assignedVariable': assignedVariable,
      };

  factory CalculatorLine.fromJson(Map<String, Object?> json) {
    return CalculatorLine(
      id: json['id'] as String? ?? _uuid.v4(),
      expression: json['expression'] as String? ?? '',
      result: (json['result'] as num?)?.toDouble() ?? 0,
      alias: json['alias'] as String? ?? '',
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      assignedVariable: json['assignedVariable'] as String?,
    );
  }
}

class CalculatorVariable {
  CalculatorVariable({
    String? id,
    required this.name,
    required this.value,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  double value;
  DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'value': value,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory CalculatorVariable.fromJson(Map<String, Object?> json) {
    return CalculatorVariable(
      id: json['id'] as String? ?? _uuid.v4(),
      name: json['name'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class CalculatorState {
  CalculatorState({
    List<CalculatorLine>? lines,
    List<CalculatorVariable>? variables,
    this.historyLimit = 100,
    this.schemaVersion = 1,
  })  : lines = lines ?? <CalculatorLine>[],
        variables = variables ?? <CalculatorVariable>[];

  List<CalculatorLine> lines;
  List<CalculatorVariable> variables;
  int historyLimit;
  int schemaVersion;

  Map<String, Object?> toJson() => {
        'lines': lines.map((line) => line.toJson()).toList(),
        'variables': variables.map((variable) => variable.toJson()).toList(),
        'historyLimit': historyLimit,
        'schemaVersion': schemaVersion,
      };

  factory CalculatorState.fromJson(Map<String, Object?> json) {
    return CalculatorState(
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => CalculatorLine.fromJson(item.cast<String, Object?>()))
          .toList(),
      variables: (json['variables'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => CalculatorVariable.fromJson(item.cast<String, Object?>()))
          .toList(),
      historyLimit: json['historyLimit'] as int? ?? 100,
      schemaVersion: json['schemaVersion'] as int? ?? 0,
    );
  }
}

class CalculatorPreview {
  const CalculatorPreview({required this.value, this.assignment});

  final double value;
  final String? assignment;

  @override
  bool operator ==(Object other) =>
      other is CalculatorPreview &&
      other.value == value &&
      other.assignment == assignment;

  @override
  int get hashCode => Object.hash(value, assignment);
}

DateTime? _parseDate(Object? value) {
  if (value is String) return DateTime.tryParse(value);
  if (value is num) {
    // Compatibility with possible Swift-style seconds-since-1970 dumps.
    return DateTime.fromMillisecondsSinceEpoch((value * 1000).round(), isUtc: true);
  }
  return null;
}
