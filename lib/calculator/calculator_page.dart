import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_design.dart';
import 'calculator_models.dart';
import 'calculator_store.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key, required this.store, this.compact = false});

  final CalculatorStore store;
  final bool compact;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  CalculatorPreview? _livePreview;
  String? _selectedLineId;
  bool _showingVariables = false;

  CalculatorStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _inputController
      ..removeListener(_refreshPreview)
      ..dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    setState(() {
      _livePreview = store.previewEvaluation(_inputController.text);
    });
  }

  void _submit() {
    if (store.evaluate(_inputController.text) == null) {
      setState(() {});
      return;
    }
    _inputController.clear();
    _livePreview = null;
    _inputFocus.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Stack(
          children: [
            Column(
              children: [
                Expanded(child: _historyPane()),
                _composer(),
              ],
            ),
            if (!widget.compact && _showingVariables)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showingVariables = false),
                        child: const ColoredBox(color: Colors.transparent),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height - 24,
                        ),
                        child: VariableInspector(
                          store: store,
                          onAdd: () => _openVariableManager(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _historyPane() {
    if (store.lines.isEmpty) {
      return GestureDetector(
        onTap: () => _inputFocus.requestFocus(),
        child: const Center(
          child: Text(
            '从一行公式开始',
            style: TextStyle(fontSize: 13, color: AppDesign.muted),
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(widget.compact ? 12 : 20, 12, widget.compact ? 12 : 20, 8),
      buildDefaultDragHandles: false,
      itemCount: store.lines.length,
      onReorderItem: (oldIndex, newIndex) {
        store.moveLineToIndex(id: store.lines[oldIndex].id, toIndex: newIndex);
      },
      itemBuilder: (context, index) {
        final line = store.lines[index];
        return ReorderableDragStartListener(
          key: ValueKey(line.id),
          index: index,
          child: CalculatorLineRow(
            line: line,
            compact: widget.compact,
            selected: _selectedLineId == line.id,
            onSelect: () => setState(() => _selectedLineId = line.id),
            onEdit: (expression) => store.updateExpression(expression, line),
            onPin: () => store.togglePin(line),
            onAlias: () => _editAlias(line),
            onSaveVariable: () => _saveVariable(line),
            onDelete: () => store.remove(line),
          ),
        );
      },
    );
  }

  Widget _composer() {
    final preview = _livePreview;
    final inputField = TextField(
      controller: _inputController,
      focusNode: _inputFocus,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
      decoration: const InputDecoration(
        hintText: '直接输入计算公式，比如: 5 * (7 + 8)',
        hintStyle: TextStyle(color: AppDesign.faint, fontSize: 14),
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
    );

    final previewLabel = preview == null
        ? const SizedBox.shrink()
        : Text(
            preview.assignment == null
                ? '= ${NumberDisplay.string(preview.value)}'
                : '${preview.assignment} = ${NumberDisplay.string(preview.value)}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppDesign.preview,
            ),
          );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () async {
            if (widget.compact) {
              await _openVariableSheet();
            } else {
              setState(() => _showingVariables = !_showingVariables);
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: _showingVariables ? AppDesign.ink : AppDesign.muted,
          ),
          child: const Text('变量'),
        ),
        const SizedBox(width: 4),
        IconButton.filled(
          onPressed: _submit,
          style: IconButton.styleFrom(
            backgroundColor: AppDesign.ink,
            foregroundColor: Colors.white,
            minimumSize: const Size(36, 36),
          ),
          tooltip: '保存',
          icon: const Icon(Icons.keyboard_return, size: 18),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(widget.compact ? 12 : 18, 4, widget.compact ? 12 : 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (store.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Text(
                store.lastError!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppDesign.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppDesign.composerBorder),
              boxShadow: const [
                BoxShadow(color: Color(0x0C000000), blurRadius: 14, offset: Offset(0, 6)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: widget.compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        inputField,
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: previewLabel),
                            actions,
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: inputField),
                        const SizedBox(width: 10),
                        previewLabel,
                        const SizedBox(width: 10),
                        actions,
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editAlias(CalculatorLine line) async {
    final controller = TextEditingController(text: line.alias);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置备注'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line.expression, style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '例如：本月预算',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: FilledButton.styleFrom(backgroundColor: AppDesign.ink),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved != null) store.setAlias(saved, line);
  }

  Future<void> _saveVariable(CalculatorLine line) async {
    final controller = TextEditingController(text: line.assignedVariable ?? '');
    var error = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('存为变量'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '= ${NumberDisplay.string(line.result)}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '变量名',
                      hintText: '例如：tax_rate',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      if (store.saveResultAsVariable(line, controller.text)) {
                        Navigator.pop(context, true);
                      } else {
                        setDialogState(() => error = '变量名无效或已经存在');
                      }
                    },
                  ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                FilledButton(
                  onPressed: () {
                    if (store.saveResultAsVariable(line, controller.text)) {
                      Navigator.pop(context, true);
                    } else {
                      setDialogState(() => error = '变量名无效或已经存在');
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppDesign.ink),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _openVariableSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('变量', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openVariableManager();
                      },
                      icon: const Icon(Icons.add),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('完成'),
                    ),
                  ],
                ),
                VariableInspector(
                  store: store,
                  embedded: true,
                  onAdd: () {
                    Navigator.pop(context);
                    _openVariableManager();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openVariableManager() async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        var error = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('管理变量'),
              content: SizedBox(
                width: 420,
                child: ListenableBuilder(
                  listenable: store,
                  builder: (context, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: '变量名',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 110,
                              child: TextField(
                                controller: valueController,
                                decoration: const InputDecoration(
                                  labelText: '数值',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                final value = double.tryParse(valueController.text);
                                if (value == null ||
                                    !store.upsertVariable(
                                      name: nameController.text,
                                      value: value,
                                    )) {
                                  setDialogState(() => error = '变量名或数值无效');
                                  return;
                                }
                                nameController.clear();
                                valueController.clear();
                                setDialogState(() => error = '');
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        if (error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(error, style: const TextStyle(color: Colors.red)),
                          ),
                        const SizedBox(height: 12),
                        if (store.variables.isEmpty)
                          const Text(
                            '暂无变量。可以直接写在公式里：total = 1200 * (1 + tax)。',
                            style: TextStyle(color: AppDesign.muted),
                          )
                        else
                          Flexible(
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                for (final variable in store.variables)
                                  ListTile(
                                    dense: true,
                                    title: Text(
                                      variable.name,
                                      style: const TextStyle(fontFamily: 'monospace'),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          NumberDisplay.string(variable.value),
                                          style: const TextStyle(fontFamily: 'monospace'),
                                        ),
                                        IconButton(
                                          tooltip: '复制变量名',
                                          onPressed: () =>
                                              Clipboard.setData(ClipboardData(text: variable.name)),
                                          icon: const Icon(Icons.copy, size: 18),
                                        ),
                                        IconButton(
                                          tooltip: '删除',
                                          onPressed: () => store.deleteVariable(variable),
                                          icon: const Icon(Icons.delete_outline, size: 18),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(backgroundColor: AppDesign.ink),
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    valueController.dispose();
  }
}

class CalculatorLineRow extends StatefulWidget {
  const CalculatorLineRow({
    super.key,
    required this.line,
    required this.compact,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onPin,
    required this.onAlias,
    required this.onSaveVariable,
    required this.onDelete,
  });

  final CalculatorLine line;
  final bool compact;
  final bool selected;
  final VoidCallback onSelect;
  final bool Function(String) onEdit;
  final VoidCallback onPin;
  final VoidCallback onAlias;
  final VoidCallback onSaveVariable;
  final VoidCallback onDelete;

  @override
  State<CalculatorLineRow> createState() => _CalculatorLineRowState();
}

class _CalculatorLineRowState extends State<CalculatorLineRow> {
  late final TextEditingController _controller;
  var _hovering = false;
  var _editError = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.line.expression);
  }

  @override
  void didUpdateWidget(covariant CalculatorLineRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.line.expression != _controller.text &&
        widget.line.expression != oldWidget.line.expression) {
      _controller.text = widget.line.expression;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: widget.selected || _hovering ? AppDesign.rowHover : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: widget.onSelect,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.drag_handle,
                      size: 16,
                      color: widget.compact || _hovering ? AppDesign.faint : Colors.transparent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: AppDesign.secondary,
                        ),
                        decoration: const InputDecoration(hintText: '输入公式'),
                        onChanged: (value) {
                          setState(() {
                            _editError = widget.onEdit(value) || value.trim().isEmpty
                                ? ''
                                : '公式暂时无法计算';
                          });
                        },
                      ),
                    ),
                    if (!widget.compact && (_hovering || widget.selected)) ...[
                      IconButton(
                        tooltip: line.isPinned ? '取消置顶' : '置顶',
                        onPressed: widget.onPin,
                        icon: Icon(
                          line.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          size: 18,
                          color: line.isPinned ? AppDesign.ink : AppDesign.muted,
                        ),
                      ),
                      IconButton(
                        tooltip: '备注',
                        onPressed: widget.onAlias,
                        icon: const Icon(Icons.edit_note, size: 18, color: AppDesign.muted),
                      ),
                      IconButton(
                        tooltip: '存为变量',
                        onPressed: widget.onSaveVariable,
                        icon: const Icon(Icons.iso, size: 18, color: AppDesign.muted),
                      ),
                      IconButton(
                        tooltip: '删除',
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppDesign.muted),
                      ),
                    ],
                    if (widget.compact)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'pin':
                              widget.onPin();
                            case 'alias':
                              widget.onAlias();
                            case 'variable':
                              widget.onSaveVariable();
                            case 'delete':
                              widget.onDelete();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(line.isPinned ? '取消置顶' : '置顶'),
                          ),
                          const PopupMenuItem(value: 'alias', child: Text('备注')),
                          const PopupMenuItem(value: 'variable', child: Text('存为变量')),
                          const PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                      ),
                    const SizedBox(width: 8),
                    Text(
                      NumberDisplay.string(line.result),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (_editError.isNotEmpty || line.alias.isNotEmpty || line.assignedVariable != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 28, top: 4),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (_editError.isNotEmpty)
                          Text(
                            _editError,
                            style: const TextStyle(fontSize: 11, color: Colors.red),
                          ),
                        if (line.alias.isNotEmpty)
                          Text(
                            line.alias,
                            style: const TextStyle(fontSize: 11, color: AppDesign.muted),
                          ),
                        if (line.assignedVariable != null)
                          Text(
                            line.assignedVariable!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: AppDesign.muted,
                            ),
                          ),
                      ],
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

class VariableInspector extends StatelessWidget {
  const VariableInspector({
    super.key,
    required this.store,
    required this.onAdd,
    this.embedded = false,
  });

  final CalculatorStore store;
  final VoidCallback onAdd;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!embedded)
              Row(
                children: [
                  const Text('变量', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    tooltip: '新建变量',
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 18, color: AppDesign.muted),
                  ),
                ],
              ),
            if (store.variables.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '公式里直接写名字即可引用',
                  style: TextStyle(fontSize: 11, color: AppDesign.faint),
                ),
              )
            else if (embedded)
              ListView(
                shrinkWrap: true,
                children: [
                  for (final variable in store.variables) _variableTile(variable),
                ],
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    for (final variable in store.variables) _variableTile(variable),
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (embedded) return body;
    return Material(
      elevation: 8,
      color: AppDesign.paper,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: AppDesign.inspectorWidth,
        height: MediaQuery.sizeOf(context).height - 24,
        child: Padding(padding: const EdgeInsets.all(14), child: body),
      ),
    );
  }

  Widget _variableTile(CalculatorVariable variable) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        variable.name,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
      ),
      trailing: Text(
        NumberDisplay.string(variable.value),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          color: AppDesign.muted,
        ),
      ),
      onLongPress: () => Clipboard.setData(ClipboardData(text: variable.name)),
    );
  }
}
