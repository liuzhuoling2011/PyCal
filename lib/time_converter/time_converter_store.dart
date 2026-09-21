import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

enum TimestampUnit {
  nanoseconds,
  milliseconds,
  seconds;

  String get label => switch (this) {
        TimestampUnit.nanoseconds => '纳秒',
        TimestampUnit.milliseconds => '毫秒',
        TimestampUnit.seconds => '秒',
      };

  String get symbol => switch (this) {
        TimestampUnit.nanoseconds => 'ns',
        TimestampUnit.milliseconds => 'ms',
        TimestampUnit.seconds => 's',
      };

  double get multiplier => switch (this) {
        TimestampUnit.nanoseconds => 1000000000,
        TimestampUnit.milliseconds => 1000,
        TimestampUnit.seconds => 1,
      };
}

class TimeConverterStore {
  TimeConverterStore({
    String? timezoneIdentifier,
    DateTime Function()? clock,
    DateTime? initialDate,
  })  : _clock = clock ?? DateTime.now,
        timezoneIdentifier = timezoneIdentifier ?? guessLocalTimezone() {
    ensureTimeZonesInitialized();
    dateValue = initialDate ?? _clock();
    dateInput = formatDate(dateValue, timezone);
  }

  static const commonTimezones = <(String, String)>[
    ('Asia/Shanghai', '中国标准时间 (UTC+8)'),
    ('Asia/Tokyo', '日本标准时间 (UTC+9)'),
    ('Asia/Singapore', '新加坡时间 (UTC+8)'),
    ('Asia/Kolkata', '印度标准时间 (UTC+5:30)'),
    ('Europe/London', '英国时间'),
    ('Europe/Berlin', '中欧时间'),
    ('America/Los_Angeles', '太平洋时间'),
    ('America/New_York', '东部时间'),
    ('UTC', '协调世界时 (UTC)'),
  ];

  static bool _timeZonesReady = false;

  static void ensureTimeZonesInitialized() {
    if (_timeZonesReady) return;
    tzdata.initializeTimeZones();
    _timeZonesReady = true;
  }

  static String guessLocalTimezone() {
    ensureTimeZonesInitialized();
    final offset = DateTime.now().timeZoneOffset;
    for (final entry in commonTimezones) {
      try {
        final now = tz.TZDateTime.now(tz.getLocation(entry.$1));
        if (now.timeZoneOffset == offset) return entry.$1;
      } catch (_) {}
    }
    return 'UTC';
  }

  static String formatDate(DateTime date, tz.Location timezone) {
    final local = tz.TZDateTime.from(date, timezone);
    return _padDate(local);
  }

  static DateTime? parseDate(String value, tz.Location timezone) {
    final match = RegExp(
      r'^(\d{4})[-/](\d{2})[-/](\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$',
    ).firstMatch(value.trim());
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6) ?? '0');
    try {
      final parsed = tz.TZDateTime(timezone, year, month, day, hour, minute, second);
      if (parsed.year != year ||
          parsed.month != month ||
          parsed.day != day ||
          parsed.hour != hour ||
          parsed.minute != minute ||
          parsed.second != second) {
        return null;
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  final DateTime Function() _clock;

  TimestampUnit unit = TimestampUnit.seconds;
  String timezoneIdentifier;
  late DateTime dateValue;
  late String dateInput;
  String dateOutput = '';
  String timestampInput = '';
  String timestampOutput = '';
  String? dateError;
  String? timestampError;
  bool isPaused = false;
  DateTime pausedDate = DateTime.fromMillisecondsSinceEpoch(0);

  tz.Location get timezone {
    ensureTimeZonesInitialized();
    try {
      return tz.getLocation(timezoneIdentifier);
    } catch (_) {
      return tz.UTC;
    }
  }

  DateTime get currentDate => isPaused ? pausedDate : _clock();

  String get currentTimestamp => timestampStringFor(currentDate);

  String get currentDateString => formatDate(currentDate, timezone);

  void convertDateToTimestamp() {
    final timestamp = dateValue.toUtc().difference(DateTime.utc(1970)).inMicroseconds /
        1000000 *
        unit.multiplier;
    if (!timestamp.isFinite) {
      dateError = '日期超出时间戳可表示范围';
      dateOutput = '';
      return;
    }
    dateOutput = _timestampString(timestamp);
    dateError = null;
  }

  void convertTimestampToDate({bool showError = true}) {
    final clean = timestampInput.trim();
    final seconds = _parseTimestampSeconds(clean);
    if (seconds == null) {
      timestampError = showError ? '请输入有效的 ${unit.symbol} 时间戳' : null;
      timestampOutput = '';
      return;
    }
    if (!seconds.isFinite || seconds.abs() > 253402300799) {
      timestampError = showError ? '时间戳超出日期范围' : null;
      timestampOutput = '';
      return;
    }
    final date = DateTime.fromMicrosecondsSinceEpoch(
      (seconds * 1000000).round(),
      isUtc: true,
    );
    timestampOutput = formatDate(date, timezone);
    timestampError = null;
  }

  void setDateToNow() {
    dateValue = _clock();
    syncDateInput();
    convertDateToTimestamp();
  }

  void setDateToEpoch() {
    dateValue = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    syncDateInput();
    convertDateToTimestamp();
  }

  /// Midnight of the currently selected calendar day in [timezone].
  void setDateToStartOfDay() {
    final local = tz.TZDateTime.from(dateValue, timezone);
    dateValue = tz.TZDateTime(timezone, local.year, local.month, local.day);
    syncDateInput();
    convertDateToTimestamp();
  }

  void setDateToEndOfDay() {
    final local = tz.TZDateTime.from(dateValue, timezone);
    dateValue = tz.TZDateTime(timezone, local.year, local.month, local.day, 23, 59, 59);
    syncDateInput();
    convertDateToTimestamp();
  }

  void convertDateInput({bool showError = true}) {
    final clean = dateInput.trim();
    final date = parseDate(clean, timezone);
    if (date == null) {
      dateError = showError ? '日期格式应为 YYYY-MM-DD HH:mm:ss（也支持斜杠）' : null;
      dateOutput = '';
      return;
    }
    dateValue = date;
    convertDateToTimestamp();
  }

  void syncDateInput() {
    dateInput = formatDate(dateValue, timezone);
  }

  void setTimezone(String identifier) {
    timezoneIdentifier = identifier;
    syncDateInput();
    convertDateToTimestamp();
    if (timestampInput.isNotEmpty) convertTimestampToDate();
  }

  void setUnit(TimestampUnit next) {
    unit = next;
    convertDateToTimestamp();
    if (timestampInput.isNotEmpty) convertTimestampToDate();
  }

  void togglePause() {
    if (isPaused) {
      isPaused = false;
    } else {
      pausedDate = _clock();
      isPaused = true;
    }
  }

  void resetLiveClock() {
    pausedDate = _clock();
    isPaused = false;
  }

  String timestampStringFor(DateTime date) {
    final seconds = date.toUtc().difference(DateTime.utc(1970)).inMicroseconds / 1000000;
    return _timestampString(seconds * unit.multiplier);
  }

  DateTime get dateValueInTimezone {
    final local = tz.TZDateTime.from(dateValue, timezone);
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
  }

  void applyPickedDateTime(DateTime localPicked) {
    dateValue = tz.TZDateTime(
      timezone,
      localPicked.year,
      localPicked.month,
      localPicked.day,
      localPicked.hour,
      localPicked.minute,
      localPicked.second,
    );
    syncDateInput();
    convertDateToTimestamp();
  }

  String _timestampString(double value) {
    switch (unit) {
      case TimestampUnit.seconds:
        return value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
      case TimestampUnit.milliseconds:
      case TimestampUnit.nanoseconds:
        return value.truncate().toString();
    }
  }

  double? _parseTimestampSeconds(String clean) {
    if (clean.isEmpty) return null;
    final integer = BigInt.tryParse(clean);
    if (integer != null) {
      return integer.toDouble() / unit.multiplier;
    }
    final decimal = double.tryParse(clean);
    if (decimal == null) return null;
    return decimal / unit.multiplier;
  }
}

String _padDate(tz.TZDateTime local) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
