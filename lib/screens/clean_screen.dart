import 'package:flutter/material.dart';

import '../engine/bytes.dart';
import '../engine/types.dart';
import '../state/purge_controller.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';

class CleanScreen extends StatelessWidget {
  const CleanScreen({
    super.key,
    required this.controller,
    required this.ids,
    required this.onStop,
  });

  final PurgeController controller;
  final List<String> ids;
  final VoidCallback onStop;

  String _nameOf(String id) {
    for (final r in controller.results) {
      if (r.id == id) return r.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final events = controller.events;
    final percent = ids.isEmpty ? 0 : ((events.length / ids.length) * 100).round().clamp(0, 100);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(
          'Cleaning your device',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          controller.cleaning ? 'Working through the selected items…' : 'All done.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('$percent%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(999),
                  color: purgeGreen,
                ),
                if (controller.cleaning) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final ok = await showConfirmDialog(
                        context: context,
                        title: 'Stop cleaning?',
                        description:
                            'Items already cleaned stay deleted. Anything still pending will be skipped.',
                        confirmLabel: 'Stop cleaning',
                        destructive: true,
                      );
                      if (ok) onStop();
                    },
                    child: const Text('Stop cleaning'),
                  ),
                ],
                const SizedBox(height: 8),
                for (final id in ids)
                  _CleanRow(
                    name: _nameOf(id),
                    event: events.where((e) => e.categoryId == id).firstOrNull,
                    expected: controller.results
                        .where((r) => r.id == id)
                        .map((r) => r.totalSizeBytes)
                        .firstOrNull,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CleanRow extends StatelessWidget {
  const _CleanRow({
    required this.name,
    required this.event,
    required this.expected,
  });

  final String name;
  final CleanProgressEvent? event;
  final int? expected;

  @override
  Widget build(BuildContext context) {
    final status = event?.status;
    final color = switch (status) {
      'done' => purgeGreen,
      'cleaning' => Theme.of(context).colorScheme.primary,
      'error' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.outlineVariant,
    };
    final trailing = switch (status) {
      'done' => Text(
          '${formatBytes(event?.freedBytes ?? 0)} freed',
          style: const TextStyle(color: purgeGreen, fontWeight: FontWeight.w600),
        ),
      'skipped' => Text(
          event?.label != null && event!.label != 'Cancelled' ? event!.label! : 'skipped',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      'error' => Text('could not clean', style: TextStyle(color: Theme.of(context).colorScheme.error)),
      'cleaning' => Text(
          'cleaning…${expected != null ? ' (up to ${formatBytes(expected!)})' : ''}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      _ => Text('pending', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (event?.label != null && status == 'cleaning')
                  Text(
                    event!.label!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
