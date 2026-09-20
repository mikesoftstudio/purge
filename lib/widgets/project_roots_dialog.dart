import 'dart:io';

import 'package:flutter/material.dart';

import '../engine/projects.dart';
import '../state/purge_controller.dart';
import '../ui/strings.dart';

class ProjectRootsStrings {
  ProjectRootsStrings._();

  static const title = 'Project cache folders';
  static const description = 'Purge finds your projects in these folders and lets you clean '
      'their build outputs and dependency folders.';
  static const hint = 'Add a folder, e.g. ~/dev';
  static const add = 'Add';
  static const empty = 'No projects found yet. Add a folder above.';
  static const defaultLabel = 'Default';
  static const added = 'Added';
  static const forgetFolder = 'Forget folder';
  static const folderNotFound = 'Folder not found: ';
  static const done = 'Done';
}

Future<void> showProjectRootsDialog(BuildContext context, PurgeController controller) {
  return showDialog(
    context: context,
    builder: (context) => _ProjectRootsDialog(controller: controller),
  );
}

class _ProjectRootsDialog extends StatefulWidget {
  const _ProjectRootsDialog({required this.controller});

  final PurgeController controller;

  @override
  State<_ProjectRootsDialog> createState() => _ProjectRootsDialogState();
}

class _ProjectRootsDialogState extends State<_ProjectRootsDialog> {
  final TextEditingController _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  PurgeController get c => widget.controller;

  Future<void> _add() async {
    final raw = _input.text.trim();
    if (raw.isEmpty) return;
    final path = normalize(raw);
    if (!Directory(path).existsSync()) {
      setState(() => _error = '${ProjectRootsStrings.folderNotFound}$path');
      return;
    }
    setState(() => _error = null);
    await c.addProjectRoot(path);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final defaults = c.defaultProjectRootsList;
    final roots = c.projectRoots;

    return AlertDialog(
      title: const Text(ProjectRootsStrings.title),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ProjectRootsStrings.description,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      hintText: ProjectRootsStrings.hint,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      errorText: _error,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text(ProjectRootsStrings.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (roots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        ProjectRootsStrings.empty,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    for (final root in roots)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.folder,
                            color: defaults.contains(root) ? scheme.primary : scheme.onSurfaceVariant),
                        title: Text(
                          root,
                          style: TextStyle(fontFamily: Strings.monospace, fontSize: 13),
                        ),
                        subtitle: Text(defaults.contains(root)
                            ? ProjectRootsStrings.defaultLabel
                            : ProjectRootsStrings.added),
                        trailing: defaults.contains(root)
                            ? null
                            : IconButton(
                                tooltip: ProjectRootsStrings.forgetFolder,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => c.removeProjectRoot(root),
                              ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(ProjectRootsStrings.done),
        ),
      ],
    );
  }
}