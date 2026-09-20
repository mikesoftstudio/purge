import 'package:flutter/material.dart';

import '../engine/types.dart';
import '../state/purge_controller.dart';

class SettingsStrings {
  SettingsStrings._();

  static const title = 'Preferences';
  static const tryScanning = 'Scan again to see changes';
  static const autoSection = 'Automatic';
  static const autoScanLabel = 'Auto-scan on launch & on a schedule';
  static const autoScanSubtitle = 'Refreshes results so Free is always current.';
  static const intervalLabel = 'Re-scan interval';
  static const notifyLabel = 'Notify me when reclaimable space is at least';
  static const notifyOff = 'Off';
  static const trackSection = 'Custom folders';
  static const trackHint = 'Track an extra folder (build, cache, node_modules…)';
  static const trackAdd = 'Track';
  static const trackEmpty = 'No custom folders tracked';
  static const trackNote = 'Folders appear in the scan as their own card and are'
      ' cleaned with a right-click delete.';
  static const trackMissing =
      'That folder was not found. Only existing folders can be tracked.';
  static const trackDuplicate = 'Already tracked.';
  static const excludeSection = 'Never clean';
  static const excludeHint = 'Folders in these categories are never touched.';
  static const excludeCustom = 'Custom folders';
  static const blockSection = 'Blocklist paths';
  static const blockHint = 'Never delete anything here (or nested inside it),'
      ' even when it is inside a category.';
  static const blockAdd = 'Block';
  static const blockEmpty = 'No blocklisted paths';
  static const blockHome = 'You cannot block your entire Home folder.';
}

Future<void> showSettingsDialog(
  BuildContext context,
  PurgeController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SettingsDialog(controller: controller),
  );
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.controller});

  final PurgeController controller;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final TextEditingController _trackInput;
  late final TextEditingController _blockInput;
  String? _trackError;
  String? _blockError;

  PurgeController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _trackInput = TextEditingController();
    _blockInput = TextEditingController();
  }

  @override
  void dispose() {
    _trackInput.dispose();
    _blockInput.dispose();
    super.dispose();
  }

  Future<void> _addTrack() async {
    final raw = _trackInput.text;
    final added = await controller.addCustomRoot(raw);
    if (mounted) {
      setState(() {
        if (added) {
          _trackError = null;
          _trackInput.clear();
        } else {
          _trackError = controller.customRoots.contains(
                  controller.customRoots.isNotEmpty
                      ? controller.customRoots.first
                      : raw)
              ? SettingsStrings.trackDuplicate
              : SettingsStrings.trackMissing;
        }
      });
    }
  }

  Future<void> _addBlock() async {
    final raw = _blockInput.text;
    final added = await controller.addExcludedPath(raw);
    if (mounted) {
      setState(() {
        _blockError = SettingsStrings.blockHome;
        if (added) {
          _blockError = null;
          _blockInput.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(SettingsStrings.title),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final scheme = Theme.of(context).colorScheme;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(scheme, SettingsStrings.autoSection,
                      Icons.timelapse),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(SettingsStrings.autoScanLabel),
                    subtitle: const Text(SettingsStrings.autoScanSubtitle),
                    value: controller.autoScanEnabled,
                    onChanged: (v) => controller.setAutoScanEnabled(v),
                  ),
                  _dropdownRow<int>(
                    scheme,
                    SettingsStrings.intervalLabel,
                    controller.autoScanMinutes,
                    const {
                      15: '15 min',
                      30: '30 min',
                      60: '1 hour',
                      120: '2 hours',
                      240: '4 hours',
                    },
                    (v) => controller.setAutoScanMinutes(v),
                  ),
                  _dropdownRow<int>(
                    scheme,
                    SettingsStrings.notifyLabel,
                    controller.notifyThresholdBytes,
                    const {
                      0: SettingsStrings.notifyOff,
                      1 << 29: '512 MB',
                      1 << 30: '1 GB',
                      1 << 31: '2 GB',
                      5 << 30: '5 GB',
                    },
                    (v) => controller.setNotifyThresholdBytes(v),
                  ),
                  const Divider(),
                  _sectionHeader(scheme, SettingsStrings.trackSection,
                      Icons.folder_copy_outlined),
                  TextField(
                    controller: _trackInput,
                    decoration: InputDecoration(
                      hintText: SettingsStrings.trackHint,
                      errorText: _trackError,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _addTrack(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _addTrack,
                      child: const Text(SettingsStrings.trackAdd),
                    ),
                  ),
                  if (controller.customRoots.isEmpty)
                    _emptyNote(scheme, SettingsStrings.trackEmpty)
                  else
                    for (final root in controller.customRoots)
                      _pathRow(
                        scheme,
                        root,
                        () => controller.removeCustomRoot(root),
                      ),
                  const SizedBox(height: 4),
                  Text(
                    SettingsStrings.trackNote,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                  const Divider(),
                  _sectionHeader(scheme, SettingsStrings.excludeSection,
                      Icons.block),
                  Text(
                    SettingsStrings.excludeHint,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                  for (final category in controller.availableCategories)
                    _excludeTile(category),
                  for (final category in controller.dynamicCategories)
                    _excludeTile(category),
                  const Divider(),
                  _sectionHeader(scheme, SettingsStrings.blockSection,
                      Icons.do_not_disturb_on_outlined),
                  TextField(
                    controller: _blockInput,
                    decoration: InputDecoration(
                      hintText: SettingsStrings.blockHint,
                      errorText: _blockError,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _addBlock(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _addBlock,
                      child: const Text(SettingsStrings.blockAdd),
                    ),
                  ),
                  if (controller.excludedPaths.isEmpty)
                    _emptyNote(scheme, SettingsStrings.blockEmpty)
                  else
                    for (final path in controller.excludedPaths)
                      _pathRow(
                        scheme,
                        path,
                        () => controller.removeExcludedPath(path),
                      ),
                  const SizedBox(height: 4),
                  Text(
                    SettingsStrings.tryScanning,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _sectionHeader(ColorScheme scheme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface)),
        ],
      ),
    );
  }

  Widget _emptyNote(ColorScheme scheme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
    );
  }

  Widget _pathRow(ColorScheme scheme, String path, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(path,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: Icon(Icons.close,
                size: 16, color: scheme.onSurfaceVariant),
            tooltip: path,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  Widget _excludeTile(CategoryDefinition category) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(category.name),
      value: controller.excludedCategoryIds.contains(category.id),
      onChanged: (_) => controller.toggleExcludedCategory(category.id),
    );
  }

  Widget _dropdownRow<T>(
    ColorScheme scheme,
    String label,
    T value,
    Map<T, String> options,
    ValueChanged<T> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13.5)),
          ),
          DropdownButton<T>(
            value: value,
            underline: const SizedBox.shrink(),
            items: [
              for (final entry in options.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}