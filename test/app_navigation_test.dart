import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pycal/app.dart';
import 'package:pycal/calculator/calculator_store.dart';
import 'package:pycal/time_converter/time_converter_store.dart';

void main() {
  setUpAll(TimeConverterStore.ensureTimeZonesInitialized);

  testWidgets('time converter page is reachable from the desktop rail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(PyCalApp(calculatorStore: CalculatorStore.memory()));
    await tester.tap(find.text('时间换算'));
    await tester.pumpAndSettle();

    expect(find.text('日期'), findsOneWidget);
    expect(find.text('Unix 时间戳'), findsOneWidget);
    expect(find.text('ns'), findsOneWidget);
    expect(find.text('此刻'), findsOneWidget);
    expect(find.text('实时'), findsOneWidget);
  });
}