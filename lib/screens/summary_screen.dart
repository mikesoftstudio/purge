import 'package:flutter/material.dart';

import '../engine/bytes.dart';
import '../engine/categories.dart';
import '../engine/types.dart';
import '../state/purge_controller.dart';
import '../theme.dart';
import '../widgets/safety_badge.dart';

class SummaryScreenStrings {
  SummaryScreenStrings._();

  static const freed = ' freed';
  static const roomMessage =
      'Your device has more room. Everything that was cleaned regenerates on next use.';
  static const whatHappened = 'What happened';
  static const skippedDuringClean = 'skipped during clean job';
  static const erroredPrefix =
      ' item(s) could not be cleaned — you can retry them from the scan page.';
  static const scanAgain = 'Scan again';
  static const backToDashboard = 'Back to dashboard';
}

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({
    super.key,
    required this.controller,
    required this.onScanAgain,
    required this.onHome,
  });

  final PurgeController controller;
  final VoidCallback onScanAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      children: [
        const Icon(Icons.check_circle, size: 64, color: purgeGreen),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: formatBytes(summary?.totalFreedBytes ?? 0),
                style: const TextStyle(color: purgeGreen, fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: SummaryScreenStrings.freed),
            ],
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          SummaryScreenStrings.roomMessage,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (summary != null &&
            (summary.cleaned.isNotEmpty || summary.skipped.isNotEmpty || summary.errored.isNotEmpty)) ...[
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(SummaryScreenStrings.whatHappened,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  for (final id in summary.cleaned)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.circle, size: 10, color: purgeGreen),
                      title: Text(getCategory(id)?.name ?? id),
                      trailing: SafetyBadge(tier: getCategory(id)?.safety ?? SafetyTier.safe),
                    ),
                  for (final id in summary.skipped)
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.circle, size: 10, color: Theme.of(context).colorScheme.outline),
                      title: Text(getCategory(id)?.name ?? id),
                      trailing: Text(
                        SummaryScreenStrings.skippedDuringClean,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (summary.errored.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${summary.errored.length}${SummaryScreenStrings.erroredPrefix}',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            FilledButton(
                onPressed: onScanAgain, child: const Text(SummaryScreenStrings.scanAgain)),
            OutlinedButton(
                onPressed: onHome, child: const Text(SummaryScreenStrings.backToDashboard)),
          ],
        ),
      ],
    );
  }
}
