import 'package:flutter/material.dart';

import '../engine/bytes.dart';
import '../engine/types.dart';
import '../state/purge_controller.dart';
import 'category_card.dart';
import 'confirm_dialog.dart';
import 'safety_badge.dart';

class CleanConfirmStrings {
  CleanConfirmStrings._();

  static const title = 'Delete selected items?';
  static const descriptionPrefix = 'This will delete ';
  static const itemSingular = ' item';
  static const itemPlural = ' items';
  static const andFree = ' and free ';
  static const confirmPrefix = 'Clean ';
  static const acknowledge = 'I understand this cannot be undone';
  static const trashWarning = 'Trash items are permanently deleted and cannot be restored.';
  static const advancedWarning =
      'Advanced items (like Docker) must be rebuilt or re-downloaded after cleaning.';
}

/// Shows the "delete selected items" confirmation dialog listing the currently
/// selected results on [c]. Returns `true` when the user confirmed.
Future<bool> showCleanConfirmDialog(
  BuildContext context,
  PurgeController c,
) async {
  final items = c.selectedItems;
  if (items.isEmpty) return false;
  final hasAdvanced = items.any((r) => r.safety == SafetyTier.advanced);
  final hasTrash = items.any((r) => r.id == 'trash');
  final ok = await showConfirmDialog(
    context: context,
    title: CleanConfirmStrings.title,
    description:
        '${CleanConfirmStrings.descriptionPrefix}${items.length}${items.length == 1 ? CleanConfirmStrings.itemSingular : CleanConfirmStrings.itemPlural}${CleanConfirmStrings.andFree}${formatBytes(c.selectedBytes)}.',
    confirmLabel:
        '${CleanConfirmStrings.confirmPrefix}${items.length}${items.length == 1 ? CleanConfirmStrings.itemSingular : CleanConfirmStrings.itemPlural}',
    destructive: true,
    acknowledgeLabel: (hasAdvanced || hasTrash) ? CleanConfirmStrings.acknowledge : null,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final r in items)
                ListTile(
                  dense: true,
                  leading: Icon(categoryIcon(r.id), size: 20),
                  title: Text(r.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SafetyBadge(tier: r.safety),
                      const SizedBox(width: 8),
                      Text(formatBytes(r.totalSizeBytes)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (hasTrash)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              CleanConfirmStrings.trashWarning,
              style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
            ),
          ),
        if (hasAdvanced)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              CleanConfirmStrings.advancedWarning,
              style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
            ),
          ),
      ],
    ),
  );
  return ok;
}