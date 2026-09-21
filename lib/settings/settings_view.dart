import 'package:flutter/material.dart';

import '../calculator/calculator_store.dart';
import '../theme/app_design.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.store,
    this.showsDoneButton = false,
    this.onDismiss,
  });

  final CalculatorStore store;
  final bool showsDoneButton;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('保存历史行数'),
                const Spacer(),
                Text(
                  '${store.historyLimit}',
                  style: const TextStyle(color: AppDesign.muted),
                ),
              ],
            ),
            Slider(
              value: store.historyLimit.toDouble(),
              min: 10,
              max: 500,
              divisions: 49,
              label: '${store.historyLimit}',
              onChanged: (value) => store.updateHistoryLimit(value.round()),
            ),
            const Text(
              '置顶记录不会被普通历史清理。',
              style: TextStyle(fontSize: 12, color: AppDesign.muted),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppDesign.hairline, height: 1),
            const SizedBox(height: 12),
            TextButton(
              onPressed: store.clearUnpinnedHistory,
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text('清除未置顶历史'),
            ),
            if (showsDoneButton && onDismiss != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: onDismiss,
                  style: FilledButton.styleFrom(backgroundColor: AppDesign.ink),
                  child: const Text('完成'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store});

  final CalculatorStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(title: const Text('设置')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SettingsView(store: store),
      ),
    );
  }
}
