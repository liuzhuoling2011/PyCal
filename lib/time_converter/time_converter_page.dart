import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_design.dart';
import 'time_converter_store.dart';

class TimeConverterPage extends StatefulWidget {
  const TimeConverterPage({
    super.key,
    required this.store,
    this.compact = false,
  });

  final TimeConverterStore store;
  final bool compact;

  @override
  State<TimeConverterPage> createState() => _TimeConverterPageState();
}

class _TimeConverterPageState extends State<TimeConverterPage> {
  Timer? _timer;

  TimeConverterStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.syncDateInput();
    store.convertDateToTimestamp();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!store.isPaused && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.compact
        ? ListView(
            children: [
              _DateColumn(store: store, compact: true, onChanged: _refresh),
              const Divider(color: AppDesign.hairline, height: 24),
              _TimestampColumn(store: store, compact: true, onChanged: _refresh),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DateColumn(store: store, compact: false, onChanged: _refresh),
              ),
              const VerticalDivider(width: 1, color: AppDesign.hairline),
              Expanded(
                child: _TimestampColumn(store: store, compact: false, onChanged: _refresh),
              ),
            ],
          );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(widget.compact ? 16 : 28, 16, widget.compact ? 16 : 28, 4),
          child: Row(
            children: [
              _UnitSegment(store: store, onChanged: _refresh),
              const Spacer(),
              _TimezonePicker(store: store, onChanged: _refresh),
            ],
          ),
        ),
        Expanded(child: content),
        _LiveTimestampBar(
          store: store,
          compact: widget.compact,
          onChanged: _refresh,
        ),
      ],
    );
  }

  void _refresh() => setState(() {});
}

class _UnitSegment extends StatelessWidget {
  const _UnitSegment({required this.store, required this.onChanged});

  final TimeConverterStore store;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x0C000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final unit in TimestampUnit.values)
              TextButton(
                onPressed: () {
                  store.setUnit(unit);
                  onChanged();
                },
                style: TextButton.styleFrom(
                  foregroundColor: store.unit == unit ? AppDesign.ink : AppDesign.muted,
                  backgroundColor: store.unit == unit ? AppDesign.paper : Colors.transparent,
                  minimumSize: const Size(36, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                ),
                child: Text(
                  unit.symbol,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimezonePicker extends StatelessWidget {
  const _TimezonePicker({required this.store, required this.onChanged});

  final TimeConverterStore store;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final label = TimeConverterStore.commonTimezones
            .where((item) => item.$1 == store.timezoneIdentifier)
            .map((item) => item.$2)
            .firstOrNull ??
        store.timezoneIdentifier;

    return PopupMenuButton<String>(
      tooltip: '时区',
      onSelected: (value) {
        store.setTimezone(value);
        onChanged();
      },
      itemBuilder: (context) => [
        for (final timezone in TimeConverterStore.commonTimezones)
          PopupMenuItem(
            value: timezone.$1,
            child: Text(
              timezone.$1 == store.timezoneIdentifier ? '✓ ${timezone.$2}' : timezone.$2,
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppDesign.muted),
            ),
          ),
          const Icon(Icons.expand_more, size: 16, color: AppDesign.muted),
        ],
      ),
    );
  }
}

class _DateColumn extends StatefulWidget {
  const _DateColumn({
    required this.store,
    required this.compact,
    required this.onChanged,
  });

  final TimeConverterStore store;
  final bool compact;
  final VoidCallback onChanged;

  @override
  State<_DateColumn> createState() => _DateColumnState();
}

class _DateColumnState extends State<_DateColumn> {
  late final TextEditingController _controller;

  TimeConverterStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: store.dateInput);
  }

  @override
  void didUpdateWidget(covariant _DateColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != store.dateInput) {
      _controller.value = TextEditingValue(
        text: store.dateInput,
        selection: TextSelection.collapsed(offset: store.dateInput.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(widget.compact ? 16 : 28, 18, widget.compact ? 16 : 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('日期', style: TextStyle(fontSize: 11, color: AppDesign.muted)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'YYYY-MM-DD HH:mm:ss',
                  ),
                  onChanged: (value) {
                    store.dateInput = value;
                    store.convertDateInput(showError: false);
                    widget.onChanged();
                  },
                  onSubmitted: (_) {
                    store.convertDateInput();
                    widget.onChanged();
                  },
                ),
              ),
              IconButton(
                tooltip: '选择日期',
                onPressed: () => _pickDate(context),
                icon: const Icon(Icons.calendar_today_outlined, size: 18, color: AppDesign.muted),
              ),
            ],
          ),
          const Divider(color: AppDesign.composerBorder, height: 1),
          const SizedBox(height: 18),
          SelectableText(
            store.dateOutput.isEmpty ? ' ' : store.dateOutput,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: [
              _quietButton('此刻', () {
                store.setDateToNow();
                widget.onChanged();
              }),
              _quietButton('零点', () {
                store.setDateToStartOfDay();
                widget.onChanged();
              }),
              _quietButton('每日末', () {
                store.setDateToEndOfDay();
                widget.onChanged();
              }),
              if (store.dateOutput.isNotEmpty)
                _quietButton('复制', () {
                  Clipboard.setData(ClipboardData(text: store.dateOutput));
                }),
            ],
          ),
          if (store.dateError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                store.dateError!,
                style: const TextStyle(fontSize: 11, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final local = store.dateValueInTimezone;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(local.year, local.month, local.day),
      firstDate: DateTime(1970),
      lastDate: DateTime(9999),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: local.hour, minute: local.minute),
    );
    if (!context.mounted) return;
    store.applyPickedDateTime(
      DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? local.hour,
        time?.minute ?? local.minute,
        local.second,
      ),
    );
    widget.onChanged();
  }
}

class _TimestampColumn extends StatefulWidget {
  const _TimestampColumn({
    required this.store,
    required this.compact,
    required this.onChanged,
  });

  final TimeConverterStore store;
  final bool compact;
  final VoidCallback onChanged;

  @override
  State<_TimestampColumn> createState() => _TimestampColumnState();
}

class _TimestampColumnState extends State<_TimestampColumn> {
  late final TextEditingController _controller;

  TimeConverterStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: store.timestampInput);
  }

  @override
  void didUpdateWidget(covariant _TimestampColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != store.timestampInput) {
      _controller.value = TextEditingValue(
        text: store.timestampInput,
        selection: TextSelection.collapsed(offset: store.timestampInput.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(widget.compact ? 16 : 28, 18, widget.compact ? 16 : 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unix 时间戳', style: TextStyle(fontSize: 11, color: AppDesign.muted)),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
            decoration: const InputDecoration(hintText: '输入时间戳'),
            onChanged: (value) {
              store.timestampInput = value;
              store.convertTimestampToDate(showError: false);
              widget.onChanged();
            },
            onSubmitted: (_) {
              store.convertTimestampToDate();
              widget.onChanged();
            },
          ),
          const Divider(color: AppDesign.composerBorder, height: 1),
          const SizedBox(height: 18),
          SelectableText(
            store.timestampOutput.isEmpty ? ' ' : store.timestampOutput,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: [
              _quietButton('使用当前', () {
                store.timestampInput = store.currentTimestamp;
                store.convertTimestampToDate();
                widget.onChanged();
              }),
              if (store.timestampOutput.isNotEmpty)
                _quietButton('复制', () {
                  Clipboard.setData(ClipboardData(text: store.timestampOutput));
                }),
            ],
          ),
          if (store.timestampError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                store.timestampError!,
                style: const TextStyle(fontSize: 11, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveTimestampBar extends StatelessWidget {
  const _LiveTimestampBar({
    required this.store,
    required this.compact,
    required this.onChanged,
  });

  final TimeConverterStore store;
  final bool compact;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final live = store.timestampStringFor(store.currentDate);
    final indicator = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: store.isPaused ? Colors.orange : AppDesign.preview,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          store.isPaused ? '已暂停' : '实时',
          style: const TextStyle(fontSize: 12.5, color: AppDesign.muted),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _quietButton('复制', () {
          Clipboard.setData(ClipboardData(text: live));
        }),
        const SizedBox(width: 16),
        _quietButton(store.isPaused ? '继续' : '暂停', () {
          store.togglePause();
          onChanged();
        }),
        const SizedBox(width: 16),
        _quietButton('重置', () {
          store.resetLiveClock();
          onChanged();
        }),
      ],
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppDesign.hairline)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 28, vertical: compact ? 12 : 14),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      indicator,
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          live,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  actions,
                ],
              )
            : Row(
                children: [
                  indicator,
                  const SizedBox(width: 14),
                  SelectableText(
                    live,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5),
                  ),
                  const Spacer(),
                  actions,
                ],
              ),
      ),
    );
  }
}

Widget _quietButton(String title, VoidCallback onPressed) {
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: AppDesign.muted,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      minimumSize: const Size(32, 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(title, style: const TextStyle(fontSize: 12)),
  );
}
