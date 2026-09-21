import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pycal/app.dart';
import 'package:pycal/calculator/calculator_store.dart';

void main() {
  testWidgets('desktop shell shows the paper calculator', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(PyCalApp(calculatorStore: CalculatorStore.memory()));

    expect(find.text('稿纸计算'), findsWidgets);
    expect(find.text('从一行公式开始'), findsOneWidget);
    expect(find.text('时间换算'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '6 * 7');
    await tester.pump();
    expect(find.text('= 42'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('42'), findsWidgets);
  });
}