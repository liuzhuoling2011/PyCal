import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'calculator_models.dart';
import 'calculator_persistence.dart';

class FileCalculatorPersistence implements CalculatorPersistence {
  FileCalculatorPersistence(this.file);

  final File file;

  static Future<FileCalculatorPersistence> open() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory(p.join(base.path, 'PyCal'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return FileCalculatorPersistence(File(p.join(directory.path, 'calculator.json')));
  }

  @override
  Future<CalculatorState> load() async {
    try {
      if (!await file.exists()) return CalculatorState();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        return CalculatorState.fromJson(decoded.cast<String, Object?>());
      }
    } catch (_) {}
    return CalculatorState();
  }

  @override
  Future<void> save(CalculatorState state) async {
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(state.toJson()), flush: true);
  }
}

Future<CalculatorPersistence> openCalculatorPersistenceImpl() {
  return FileCalculatorPersistence.open();
}
