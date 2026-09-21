import 'package:flutter_test/flutter_test.dart';
import 'package:pycal/calculator/calculator_models.dart';
import 'package:pycal/calculator/calculator_store.dart';
import 'package:pycal/calculator/expression_evaluator.dart';

void main() {
  test('Python precedence and calculator exponent alias', () {
    const evaluator = ExpressionEvaluator();
    expect(evaluator.evaluate('-2**2').value, -4);
    expect(evaluator.evaluate('2**-2').value, closeTo(0.25, 0.000001));
    expect(evaluator.evaluate('2^5 + 3').value, 35);
  });

  test('functions and floor division', () {
    const evaluator = ExpressionEvaluator(variables: {'tax': 0.06});
    expect(evaluator.evaluate('round(1200 * (1 + tax))').value, 1272);
    expect(evaluator.evaluate('round(3.14159, 2)').value, closeTo(3.14, 0.000001));
    expect(evaluator.evaluate('-7 // 3').value, -3);
    expect(evaluator.evaluate('-7 % 3').value, 2);
  });

  test('assignment is returned separately', () {
    final result = const ExpressionEvaluator().evaluate('total = 55 + 88');
    expect(result.assignment, 'total');
    expect(result.value, 143);
  });

  test('Python assignment creates variable', () {
    final store = CalculatorStore.memory();
    final line = store.evaluate('a = 3 * 6');
    expect(line?.result, 18);
    expect(line?.assignedVariable, 'a');
    expect(store.variables.where((item) => item.name == 'a').first.value, 18);
    expect(store.previewEvaluation('b = 2 + 2')?.assignment, 'b');
    expect(store.previewEvaluation('b = 2 + 2')?.value, 4);
  });

  test('unknown variable has helpful error', () {
    expect(
      () => const ExpressionEvaluator().evaluate('subtotal + tax'),
      throwsA(ExpressionError.unknownVariable('subtotal')),
    );
  });

  test('preview does not persist incomplete input', () {
    final store = CalculatorStore.memory();
    expect(store.preview('6 * 7'), 42);
    expect(store.preview('6 * ('), isNull);
  });

  test('editing assignment cascades to dependent history', () {
    final start = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);
    final assignment = CalculatorLine(
      expression: 'a = 1 + 2',
      result: 3,
      createdAt: start,
      assignedVariable: 'a',
    );
    final dependent = CalculatorLine(
      expression: 'a * 10',
      result: 30,
      createdAt: start.add(const Duration(seconds: 1)),
    );
    final store = CalculatorStore.memory(
      CalculatorState(
        lines: [assignment, dependent],
        variables: [CalculatorVariable(name: 'a', value: 3)],
        historyLimit: 100,
      ),
    );

    expect(store.updateExpression('a = 1 + 22', assignment), isTrue);
    expect(store.variables.where((item) => item.name == 'a').first.value, 23);
    expect(store.lines.where((item) => item.id == assignment.id).first.result, 23);
    expect(store.lines.where((item) => item.id == dependent.id).first.result, 230);
  });

  test('saved history result becomes live variable for dependent rows', () {
    final start = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);
    final source = CalculatorLine(expression: '1 + 2', result: 3, createdAt: start);
    final dependent = CalculatorLine(
      expression: 'a * 10',
      result: 0,
      createdAt: start.add(const Duration(seconds: 1)),
    );
    final store = CalculatorStore.memory(
      CalculatorState(lines: [source, dependent]),
    );

    expect(store.saveResultAsVariable(source, 'a'), isTrue);
    expect(store.lines.where((item) => item.id == dependent.id).first.result, 30);

    expect(store.updateExpression('1 + 22', source), isTrue);
    expect(store.variables.where((item) => item.name == 'a').first.value, 23);
    expect(store.lines.where((item) => item.id == dependent.id).first.result, 230);
  });

  test('history editing keeps incomplete draft until it becomes valid', () {
    final row = CalculatorLine(
      expression: 'a = 1 + 2',
      result: 3,
      assignedVariable: 'a',
    );
    final store = CalculatorStore.memory(
      CalculatorState(
        lines: [row],
        variables: [CalculatorVariable(name: 'a', value: 3)],
      ),
    );

    expect(store.updateExpression('a = 1 + ', row), isFalse);
    expect(store.lines.first.expression, 'a = 1 + ');
    expect(store.lines.first.result, 3);
    expect(store.updateExpression('a = 1 + 22', row), isTrue);
    expect(store.variables.where((item) => item.name == 'a').first.value, 23);
  });

  test('new calculation is inserted at top', () {
    final older = CalculatorLine(
      expression: '1 + 1',
      result: 2,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
    );
    final store = CalculatorStore.memory(CalculatorState(lines: [older]));
    final newer = store.evaluate('2 + 2');
    expect(store.lines.first.id, newer?.id);
    expect(store.lines.last.id, older.id);
  });

  test('history can be reordered by dragging', () {
    final first = CalculatorLine(
      expression: '1',
      result: 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final second = CalculatorLine(
      expression: '2',
      result: 2,
      createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
    );
    final third = CalculatorLine(
      expression: '3',
      result: 3,
      createdAt: DateTime.fromMillisecondsSinceEpoch(3000),
    );
    final store = CalculatorStore.memory(
      CalculatorState(lines: [first, second, third]),
    );

    store.moveLine(id: third.id, before: first.id);
    expect(store.lines.map((line) => line.expression).toList(), ['3', '1', '2']);

    store.moveLine(id: first.id);
    expect(store.lines.map((line) => line.expression).toList(), ['3', '2', '1']);

    store.moveLineToIndex(id: third.id, toIndex: 1);
    expect(store.lines.map((line) => line.expression).toList(), ['2', '3', '1']);
  });

  test('round uses banker’s rounding like Python and the Swift port', () {
    const evaluator = ExpressionEvaluator();
    expect(evaluator.evaluate('round(2.5)').value, 2);
    expect(evaluator.evaluate('round(3.5)').value, 4);
    expect(evaluator.evaluate('round(-2.5)').value, -2);
  });

  test('ans uses the most recently created history result', () {
    final store = CalculatorStore.memory();
    store.evaluate('10');
    store.evaluate('ans + 5');
    expect(store.lines.first.result, 15);
  });
}
