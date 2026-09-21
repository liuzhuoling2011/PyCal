import 'package:flutter/material.dart';

import 'app.dart';
import 'calculator/calculator_persistence.dart';
import 'calculator/calculator_store.dart';
import 'time_converter/time_converter_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TimeConverterStore.ensureTimeZonesInitialized();
  final persistence = await openCalculatorPersistence();
  final store = await CalculatorStore.load(persistence);
  runApp(PyCalApp(calculatorStore: store));
}
