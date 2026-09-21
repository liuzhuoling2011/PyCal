import 'dart:async';

import 'package:flutter/foundation.dart';

import 'calculator_models.dart';
import 'calculator_persistence.dart';
import 'expression_evaluator.dart';

class CalculatorStore extends ChangeNotifier {
  CalculatorStore._({
    required CalculatorState initialState,
    this._persistence,
  }) {
    lines = List<CalculatorLine>.from(initialState.lines);
    variables = List<CalculatorVariable>.from(initialState.variables);
    historyLimit = _clampHistoryLimit(initialState.historyLimit);
    if (initialState.schemaVersion < 1) {
      lines = _migratedDisplayOrder(lines, initialState.schemaVersion);
      _trimHistory();
      _save(schemaVersion: 1);
    } else {
      _trimHistory();
    }
  }

  /// Creates an in-memory store. Useful for tests and previews; never touches disk.
  factory CalculatorStore.memory([CalculatorState? initialState]) {
    return CalculatorStore._(
      initialState: initialState ?? CalculatorState(),
    );
  }

  static Future<CalculatorStore> load(CalculatorPersistence persistence) async {
    final state = await persistence.load();
    return CalculatorStore._(initialState: state, persistence: persistence);
  }

  final CalculatorPersistence? _persistence;

  List<CalculatorLine> lines = [];
  List<CalculatorVariable> variables = [];
  int historyLimit = 100;
  String? lastError;

  Map<String, double> get variableMap => {
        for (final variable in variables) variable.name: variable.value,
      };

  double? get previousResult {
    if (lines.isEmpty) return null;
    final sorted = [...lines]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first.result;
  }

  CalculatorState get currentState => CalculatorState(
        lines: lines,
        variables: variables,
        historyLimit: historyLimit,
        schemaVersion: 1,
      );

  void updateHistoryLimit(int limit) {
    historyLimit = _clampHistoryLimit(limit);
    _trimHistory();
    _save();
    notifyListeners();
  }

  CalculatorLine? evaluate(String expression) {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) {
      lastError = ExpressionError.emptyExpression().message;
      notifyListeners();
      return null;
    }

    final context = Map<String, double>.from(variableMap);
    final previous = previousResult;
    if (previous != null) context['ans'] = previous;

    try {
      final evaluated = ExpressionEvaluator(variables: context).evaluate(trimmed);
      final line = CalculatorLine(
        expression: trimmed,
        result: evaluated.value,
        assignedVariable: evaluated.assignment,
      );
      lines.insert(0, line);
      if (evaluated.assignment != null) {
        upsertVariable(
          name: evaluated.assignment!,
          value: evaluated.value,
          shouldSave: false,
        );
      }
      recalculateHistory();
      _trimHistory();
      lastError = null;
      _save();
      notifyListeners();
      return line;
    } on ExpressionError catch (error) {
      lastError = error.message;
      notifyListeners();
      return null;
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      return null;
    }
  }

  /// Transient preview while the composer is being edited. Never writes history.
  double? preview(String expression) => previewEvaluation(expression)?.value;

  CalculatorPreview? previewEvaluation(String expression) {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) return null;
    final context = Map<String, double>.from(variableMap);
    final previous = previousResult;
    if (previous != null) context['ans'] = previous;
    try {
      final evaluated = ExpressionEvaluator(variables: context).evaluate(trimmed);
      return CalculatorPreview(
        value: evaluated.value,
        assignment: evaluated.assignment,
      );
    } catch (_) {
      return null;
    }
  }

  void togglePin(CalculatorLine line) {
    final index = lines.indexWhere((item) => item.id == line.id);
    if (index < 0) return;
    lines[index].isPinned = !lines[index].isPinned;
    _save();
    notifyListeners();
  }

  void setAlias(String alias, CalculatorLine line) {
    final index = lines.indexWhere((item) => item.id == line.id);
    if (index < 0) return;
    lines[index].alias = alias.trim();
    _save();
    notifyListeners();
  }

  void remove(CalculatorLine line) {
    lines.removeWhere((item) => item.id == line.id);
    _save();
    notifyListeners();
  }

  void moveLine({required String id, String? before}) {
    final from = lines.indexWhere((item) => item.id == id);
    if (from < 0) return;
    final updated = [...lines];
    final item = updated.removeAt(from);
    if (before != null) {
      final destination = updated.indexWhere((item) => item.id == before);
      if (destination >= 0) {
        updated.insert(destination, item);
      } else {
        updated.add(item);
      }
    } else {
      updated.add(item);
    }
    _applyReorderedLines(updated);
  }

  void moveLineToIndex({required String id, required int toIndex}) {
    final from = lines.indexWhere((item) => item.id == id);
    if (from < 0) return;
    final updated = [...lines];
    final item = updated.removeAt(from);
    updated.insert(toIndex.clamp(0, updated.length), item);
    _applyReorderedLines(updated);
  }

  void _applyReorderedLines(List<CalculatorLine> updated) {
    final same = updated.length == lines.length &&
        List.generate(updated.length, (i) => updated[i].id == lines[i].id)
            .every((value) => value);
    if (same) return;
    lines = updated;
    _save();
    notifyListeners();
  }

  /// Keep the draft exactly as typed. Invalid rows retain their last result.
  bool updateExpression(String expression, CalculatorLine line) {
    final index = lines.indexWhere((item) => item.id == line.id);
    if (index < 0) return false;
    lines[index].expression = expression;
    final failedRows = recalculateHistory();
    lastError = null;
    _save();
    notifyListeners();
    return !failedRows.contains(line.id);
  }

  void clearUnpinnedHistory() {
    lines.removeWhere((line) => !line.isPinned);
    _save();
    notifyListeners();
  }

  bool saveResultAsVariable(CalculatorLine line, String name) {
    final clean = name.trim();
    if (!isValidVariableName(clean)) {
      lastError = '变量名只能包含字母、数字和下划线，且不能以数字开头';
      notifyListeners();
      return false;
    }
    upsertVariable(name: clean, value: line.result, shouldSave: false);
    final index = lines.indexWhere((item) => item.id == line.id);
    if (index >= 0) {
      lines[index].assignedVariable = clean;
    }
    recalculateHistory();
    lastError = null;
    _save();
    notifyListeners();
    return true;
  }

  bool upsertVariable({
    required String name,
    required double value,
    bool shouldSave = true,
  }) {
    final clean = name.trim();
    if (!isValidVariableName(clean) || !value.isFinite) {
      lastError = '请输入有效的变量名和有限数字';
      if (shouldSave) notifyListeners();
      return false;
    }
    final index = variables.indexWhere((item) => item.name == clean);
    if (index >= 0) {
      variables[index].value = value;
      variables[index].updatedAt = DateTime.now();
    } else {
      variables.add(CalculatorVariable(name: clean, value: value));
    }
    if (shouldSave) {
      recalculateHistory();
      _save();
      notifyListeners();
    }
    return true;
  }

  void deleteVariable(CalculatorVariable variable) {
    variables.removeWhere((item) => item.id == variable.id);
    _save();
    notifyListeners();
  }

  bool renameVariable(CalculatorVariable variable, String name) {
    final clean = name.trim();
    if (!isValidVariableName(clean) ||
        variables.any((item) => item.name == clean && item.id != variable.id)) {
      lastError = '变量名无效或已经存在';
      notifyListeners();
      return false;
    }
    final index = variables.indexWhere((item) => item.id == variable.id);
    if (index < 0) return false;
    variables[index].name = clean;
    variables[index].updatedAt = DateTime.now();
    _save();
    notifyListeners();
    return true;
  }

  void _trimHistory() {
    if (lines.length <= historyLimit) return;
    final pinned = lines.where((line) => line.isPinned).toList();
    final unpinned = lines.where((line) => !line.isPinned).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final remainingCount = (historyLimit - pinned.length).clamp(0, unpinned.length);
    lines = [...pinned, ...unpinned.take(remainingCount)];
  }

  /// Recalculates history in chronological order so assignment edits cascade.
  Set<String> recalculateHistory() {
    final chronological = [...lines]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final context = Map<String, double>.from(variableMap);
    final ownedVariables = chronological
        .map((line) => line.assignedVariable)
        .whereType<String>()
        .toSet();
    for (final name in ownedVariables) {
      context.remove(name);
    }
    context.remove('ans');
    final failedRows = <String>{};

    for (final row in chronological) {
      final index = lines.indexWhere((item) => item.id == row.id);
      if (index < 0) continue;
      try {
        final evaluated =
            ExpressionEvaluator(variables: context).evaluate(lines[index].expression);
        lines[index].result = evaluated.value;
        final linkedVariable = evaluated.assignment ?? lines[index].assignedVariable;
        lines[index].assignedVariable = linkedVariable;
        if (linkedVariable != null) {
          ownedVariables.add(linkedVariable);
          context[linkedVariable] = evaluated.value;
        }
        context['ans'] = evaluated.value;
      } catch (_) {
        failedRows.add(row.id);
        final linkedVariable = lines[index].assignedVariable;
        if (linkedVariable != null) {
          ownedVariables.add(linkedVariable);
          context[linkedVariable] = lines[index].result;
        }
        context['ans'] = lines[index].result;
      }
    }

    for (final name in ownedVariables) {
      final value = context[name];
      if (value == null || !value.isFinite) continue;
      final index = variables.indexWhere((item) => item.name == name);
      if (index >= 0) {
        variables[index].value = value;
        variables[index].updatedAt = DateTime.now();
      } else {
        variables.add(CalculatorVariable(name: name, value: value));
      }
    }
    return failedRows;
  }

  void _save({int schemaVersion = 1}) {
    final persistence = _persistence;
    if (persistence == null) return;
    unawaited(
      persistence.save(
        CalculatorState(
          lines: lines,
          variables: variables,
          historyLimit: historyLimit,
          schemaVersion: schemaVersion,
        ),
      ),
    );
  }

  static int _clampHistoryLimit(int limit) => limit.clamp(10, 500);

  static List<CalculatorLine> _migratedDisplayOrder(
    List<CalculatorLine> lines,
    int schemaVersion,
  ) {
    if (schemaVersion >= 1) return lines;
    final copy = [...lines];
    copy.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }
}
