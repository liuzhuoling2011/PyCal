import 'calculator_models.dart';
import 'calculator_persistence_pref.dart'
    if (dart.library.io) 'calculator_persistence_io.dart' as impl;

abstract class CalculatorPersistence {
  Future<CalculatorState> load();
  Future<void> save(CalculatorState state);
}

/// In-memory persistence used by tests and previews.
class MemoryCalculatorPersistence implements CalculatorPersistence {
  MemoryCalculatorPersistence([CalculatorState? state])
      : state = state ?? CalculatorState();

  CalculatorState state;

  @override
  Future<CalculatorState> load() async => state;

  @override
  Future<void> save(CalculatorState next) async {
    state = next;
  }
}

Future<CalculatorPersistence> openCalculatorPersistence() =>
    impl.openCalculatorPersistenceImpl();
