import 'package:flutter/material.dart';

import 'calculator/calculator_page.dart';
import 'calculator/calculator_store.dart';
import 'settings/settings_view.dart';
import 'theme/app_design.dart';
import 'time_converter/time_converter_page.dart';
import 'time_converter/time_converter_store.dart';

enum ToolboxItem { calculator, timeConverter, settings }

class PyCalApp extends StatelessWidget {
  const PyCalApp({super.key, required this.calculatorStore});

  final CalculatorStore calculatorStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PyCal',
      debugShowCheckedModeBanner: false,
      theme: AppDesign.theme(),
      home: AppShell(calculatorStore: calculatorStore),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.calculatorStore});

  final CalculatorStore calculatorStore;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ToolboxItem _selection = ToolboxItem.calculator;
  late final TimeConverterStore _timeStore;

  @override
  void initState() {
    super.initState();
    _timeStore = TimeConverterStore();
    _timeStore.convertDateToTimestamp();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = isCompactLayout(constraints);
        final page = switch (_selection) {
          ToolboxItem.calculator => CalculatorPage(
              store: widget.calculatorStore,
              compact: compact,
            ),
          ToolboxItem.timeConverter => TimeConverterPage(
              store: _timeStore,
              compact: compact,
            ),
          ToolboxItem.settings => SettingsPage(store: widget.calculatorStore),
        };

        if (compact) {
          return Scaffold(
            backgroundColor: AppDesign.canvas,
            body: SafeArea(child: page),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selection.index,
              onDestinationSelected: (index) {
                setState(() => _selection = ToolboxItem.values[index]);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.calculate_outlined),
                  selectedIcon: Icon(Icons.calculate),
                  label: '稿纸计算',
                ),
                NavigationDestination(
                  icon: Icon(Icons.schedule_outlined),
                  selectedIcon: Icon(Icons.schedule),
                  label: '时间换算',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '设置',
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppDesign.canvas,
          body: Row(
            children: [
              ColoredBox(
                color: AppDesign.rail,
                child: SizedBox(
                  width: AppDesign.railWidth,
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _railButton(
                        icon: Icons.calculate_outlined,
                        label: '稿纸计算',
                        selected: _selection == ToolboxItem.calculator,
                        onTap: () => setState(() => _selection = ToolboxItem.calculator),
                      ),
                      _railButton(
                        icon: Icons.schedule_outlined,
                        label: '时间换算',
                        selected: _selection == ToolboxItem.timeConverter,
                        onTap: () => setState(() => _selection = ToolboxItem.timeConverter),
                      ),
                      const Spacer(),
                      _railButton(
                        icon: Icons.settings_outlined,
                        label: '设置',
                        selected: _selection == ToolboxItem.settings,
                        onTap: () => setState(() => _selection = ToolboxItem.settings),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1, color: AppDesign.hairline),
              Expanded(child: page),
            ],
          ),
        );
      },
    );
  }

  Widget _railButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? AppDesign.iconSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? AppDesign.ink : AppDesign.muted),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    color: selected ? AppDesign.ink : AppDesign.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
