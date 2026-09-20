import 'package:flutter/material.dart';

class CommandPaletteStrings {
  CommandPaletteStrings._();

  static const title = 'Commands';
  static const hint = 'Type to filter actions…';
  static const noResults = 'No matching commands';
}

class PaletteAction {
  const PaletteAction({
    required this.label,
    required this.onSelect,
    this.icon,
    this.shortcut,
  });

  final String label;
  final VoidCallback onSelect;
  final IconData? icon;
  final String? shortcut;
}

/// Opens the ⌘K command palette. Each action is filtered by typing and runs the
/// currently selected action on Enter or tap.
Future<void> showCommandPalette(
  BuildContext context,
  List<PaletteAction> actions,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CommandPalette(actions: actions),
  );
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({required this.actions});

  final List<PaletteAction> actions;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final TextEditingController _input = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  List<PaletteAction> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.actions;
    return widget.actions
        .where((a) => a.label.toLowerCase().contains(q))
        .toList();
  }

  void _run(PaletteAction action) {
    Navigator.pop(context);
    action.onSelect();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return AlertDialog(
      title: const Text(CommandPaletteStrings.title),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _input,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (_) {
                if (filtered.isNotEmpty) _run(filtered.first);
              },
              decoration: InputDecoration(
                hintText: CommandPaletteStrings.hint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: filtered.isEmpty
                  ? const SizedBox.shrink()
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final action in filtered)
                          ListTile(
                            dense: true,
                            leading: action.icon == null
                                ? null
                                : Icon(action.icon, size: 18),
                            title: Text(action.label),
                            trailing: action.shortcut == null
                                ? null
                                : Text(
                                    action.shortcut!,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 11.5,
                                    ),
                                  ),
                            onTap: () => _run(action),
                          ),
                      ],
                    ),
            ),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  CommandPaletteStrings.noResults,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}