import 'package:flutter/material.dart';

abstract final class AppDesign {
  static const canvas = Color(0xFFF6F6F4);
  static const rail = Color(0xFFECECE8);
  static const paper = Colors.white;
  static const ink = Color(0xFF1D1D1F);
  static const secondary = Color(0xFF3A3A38);
  static const muted = Color(0xFF8A8A86);
  static const faint = Color(0xFFB4B4AE);
  static const preview = Color(0xFF3D6B66);
  static const hairline = Color(0x12000000);
  static const rowHover = Color(0x09000000);
  static const iconSelected = Color(0x14000000);
  static const composerBorder = Color(0x1A000000);

  static const railWidth = 176.0;
  static const inspectorWidth = 232.0;
  static const compactBreakpoint = 720.0;

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: preview,
        brightness: Brightness.light,
        surface: canvas,
        primary: ink,
      ),
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Roboto',
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        isDense: true,
      ),
    );
  }
}

abstract final class NumberDisplay {
  static String string(double value, {bool grouping = true}) {
    if (value.isNaN) return 'nan';
    if (value.isInfinite) return value.isNegative ? '-inf' : 'inf';
    if (value == 0) return '0';

    final magnitude = value.abs();
    if (magnitude >= 1e15 || magnitude < 1e-9) {
      return _trimScientific(value);
    }

    final formatted = value.toStringAsFixed(12);
    final trimmed = formatted.contains('.')
        ? formatted.replaceFirst(RegExp(r'\.?0+$'), '')
        : formatted;
    if (!grouping) return trimmed == '-0' ? '0' : trimmed;

    final parts = trimmed.split('.');
    final negative = parts[0].startsWith('-');
    final digits = negative ? parts[0].substring(1) : parts[0];
    final grouped = _group(digits);
    final sign = negative ? '-' : '';
    if (parts.length == 1) return '$sign$grouped';
    return '$sign$grouped.${parts[1]}';
  }

  static String _group(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }

  static String _trimScientific(double value) {
    var text = value.toString();
    if (text.contains('e')) return text;
    return value.toStringAsExponential(10).replaceFirst(RegExp(r'\.?0+e'), 'e');
  }
}

bool isCompactLayout(BoxConstraints constraints) =>
    constraints.maxWidth < AppDesign.compactBreakpoint;
