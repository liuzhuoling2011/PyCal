import 'package:flutter_test/flutter_test.dart';
import 'package:pycal/time_converter/time_converter_store.dart';

void main() {
  setUpAll(TimeConverterStore.ensureTimeZonesInitialized);

  test('date to timestamp across units', () {
    final store = TimeConverterStore(timezoneIdentifier: 'UTC');
    store.dateValue = DateTime.fromMicrosecondsSinceEpoch(
      1735790147250000,
      isUtc: true,
    );

    store.unit = TimestampUnit.seconds;
    store.convertDateToTimestamp();
    expect(store.dateOutput, '1735790147.25');

    store.unit = TimestampUnit.milliseconds;
    store.convertDateToTimestamp();
    expect(store.dateOutput, '1735790147250');

    store.unit = TimestampUnit.nanoseconds;
    store.convertDateToTimestamp();
    expect(store.dateOutput.contains(','), isFalse);
    expect(store.dateOutput.contains(' '), isFalse);
    expect(RegExp(r'^\d+$').hasMatch(store.dateOutput), isTrue);
  });

  test('timestamp to date uses selected timezone', () {
    final store = TimeConverterStore();
    store.unit = TimestampUnit.seconds;
    store.setTimezone('Asia/Shanghai');
    store.timestampInput = '0';
    store.convertTimestampToDate();
    expect(store.timestampOutput, '1970-01-01 08:00:00');
    expect(store.timestampError, isNull);
  });

  test('date input accepts slash and optional seconds', () {
    final store = TimeConverterStore();
    store.setTimezone('Asia/Shanghai');
    store.dateInput = '1970/01/01 08:00';
    store.convertDateInput();
    expect(store.dateOutput, '0');
    expect(store.dateError, isNull);
  });

  test('midnight and end of day stay in the selected timezone', () {
    final store = TimeConverterStore(timezoneIdentifier: 'Asia/Shanghai');
    store.dateInput = '2024-01-15 15:30:00';
    store.convertDateInput();
    store.setDateToStartOfDay();
    expect(store.dateInput, '2024-01-15 00:00:00');
    store.setDateToEndOfDay();
    expect(store.dateInput, '2024-01-15 23:59:59');
  });
}
