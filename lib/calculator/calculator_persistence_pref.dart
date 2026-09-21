import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'calculator_models.dart';
import 'calculator_persistence.dart';

const calculatorPrefsKey = 'pycal.calculator.json';

class SharedPrefsCalculatorPersistence implements CalculatorPersistence {
  SharedPrefsCalculatorPersistence(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<CalculatorState> load() async {
    final raw = _prefs.getString(calculatorPrefsKey);
    if (raw == null || raw.isEmpty) return CalculatorState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CalculatorState.fromJson(decoded.cast<String, Object?>());
      }
      if (decoded is Map) {
        return CalculatorState.fromJson(decoded.cast<String, Object?>());
      }
    } catch (_) {}
    return CalculatorState();
  }

  @override
  Future<void> save(CalculatorState state) async {
    await _prefs.setString(calculatorPrefsKey, jsonEncode(state.toJson()));
  }
}

Future<CalculatorPersistence> openCalculatorPersistenceImpl() async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPrefsCalculatorPersistence(prefs);
}
