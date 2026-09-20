import 'package:flutter/material.dart';

import '../engine/bytes.dart';
import '../engine/types.dart';
import '../theme.dart';
import '../ui/strings.dart';
import 'safety_badge.dart';
import 'safety_info.dart';

class CategoryCardStrings {
  CategoryCardStrings._();

  static const detailsFor = 'Details for ';
  static const details = 'Details';
  static const select = 'Select';
  static const deselect = 'Deselect';
  static const needs = 'needs ';
  static const notAvailable = 'not available on this device';
  static const nothingToClean = 'nothing to clean';
  static const locationSingular = ' location';
  static const locationPlural = ' locations';
}

enum _MenuAction { details, select, safety }

IconData categoryIcon(String id) {
  return switch (id) {
    'trash' => Icons.delete_outline,
    'system-caches' => Icons.speed_outlined,
    'app-caches' => Icons.phonelink_erase_outlined,
    'homebrew-cache' => Icons.local_drink_outlined,
    'npm-cache' => Icons.inventory_2_outlined,
    'pnpm-cache' => Icons.layers_outlined,
    'yarn-cache' => Icons.smart_toy_outlined,
    'pip-cache' => Icons.code_outlined,
    'cocoapods-cache' => Icons.description_outlined,
    'flutter-pub-cache' => Icons.flutter_dash,
    'flutter-sdk-cache' => Icons.download_done_outlined,
    'xcode-deriveddata' => Icons.developer_mode_outlined,
    'xcode-devicesupport' => Icons.phone_iphone_outlined,
    'xcode-simulator-caches' => Icons.rectangle_outlined,
    'ios-simulators' => Icons.sim_card_outlined,
    'gradle-build-caches' => Icons.build_circle_outlined,
    'gradle-wrapper-dists' => Icons.downloading_outlined,
    'docker' => Icons.widgets_outlined,
    'go-build-cache' => Icons.terminal_outlined,
    'cargo-registry-cache' => Icons.extension_outlined,
    'dotnet-nuget' => Icons.view_module_outlined,
    'chocolatey-cache' => Icons.bakery_dining_outlined,
    'scoop-cache' => Icons.icecream_outlined,
    'large-files' => Icons.insert_drive_file_outlined,
    _ => Icons.folder_outlined,
  };
}

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.result,
    required this.maxSize,
    required this.selected,
    required this.onToggle,
    required this.onDetails,
  });

  final ScanResult result;
  final int maxSize;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final disabled = !result.applicable || (!result.detected && result.totalSizeBytes == 0);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratio = result.totalSizeBytes / (maxSize == 0 ? 1 : maxSize);
    final barColor = ratio > 0.4
        ? purgeRed
        : ratio > 0.15
            ? purgeAmber
            : purgeGreen;
    final iconColor = isDark ? purgeGreenDark : purgeGreen;

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected && !disabled ? scheme.primary : scheme.outlineVariant,
              width: selected && !disabled ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: disabled ? onDetails : onToggle,
            onSecondaryTapDown: (d) => _openMenu(context, d.globalPosition),
            onLongPress: () => _openMenu(context, null),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selected && !disabled
                                ? scheme.primaryContainer
                                : iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            categoryIcon(result.id),
                            size: 21,
                            color: selected && !disabled ? scheme.primary : iconColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                result.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12.5,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SafetyBadge(tier: result.safety),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatBytes(result.totalSizeBytes),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: _statusLabel(result, scheme),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (result.applicable && result.totalSizeBytes > 0)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 6,
                          color: barColor,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      )
                    else
                      const SizedBox(height: 6),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            result.tradeoff,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onDetails,
                          tooltip: '${CategoryCardStrings.detailsFor}${result.name}',
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(32, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          icon: Icon(
                            selected ? Icons.info : Icons.info_outline,
                            size: 17,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (selected && !disabled)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 14, color: scheme.onPrimary),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context, Offset? position) async {
    final scheme = Theme.of(context).colorScheme;
    final disabled = !result.applicable || (!result.detected && result.totalSizeBytes == 0);
    final selected = this.selected;

    final anchor = position ??
        (context.findRenderObject() as RenderBox?)?.localToGlobal(
              (context.findRenderObject() as RenderBox).size.center(Offset.zero),
            ) ??
        Offset.zero;

    final action = await showMenu<_MenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(anchor.dx, anchor.dy, anchor.dx, anchor.dy),
      color: scheme.surfaceContainerLow,
      items: [
        PopupMenuItem(
          value: _MenuAction.details,
          child: _MenuItem(icon: Icons.info_outline, label: CategoryCardStrings.details),
        ),
        if (!disabled)
          PopupMenuItem(
            value: _MenuAction.select,
            child: _MenuItem(
              icon: selected ? Icons.check_box_outlined : Icons.check_box_outline_blank,
              label: selected ? CategoryCardStrings.deselect : CategoryCardStrings.select,
            ),
          ),
        PopupMenuItem(
          value: _MenuAction.safety,
          child: _MenuItem(
            icon: Icons.shield_outlined,
            label: 'What does "${_tierLabel(result.safety)}" mean?',
          ),
        ),
      ],
    );

    switch (action) {
      case _MenuAction.details:
        onDetails();
      case _MenuAction.select:
        onToggle();
      case _MenuAction.safety:
        if (context.mounted) {
          await showSafetyTierInfo(context, result.safety);
        }
      case null:
        break;
    }
  }

  String _tierLabel(SafetyTier tier) => switch (tier) {
        SafetyTier.safe => Strings.safe,
        SafetyTier.moderate => Strings.moderate,
        SafetyTier.advanced => Strings.advanced,
      };

  Widget _statusLabel(ScanResult result, ColorScheme scheme) {
    if (result.toolMissing) {
      return Text(
        '${CategoryCardStrings.needs}${result.category.toolRequirement}',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
      );
    }
    if (!result.applicable) {
      return Text(
        CategoryCardStrings.notAvailable,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
      );
    }
    if (!result.detected && result.scanHint != null) {
      return Text(
        result.scanHint!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.amber.shade700, fontSize: 11.5),
      );
    }
    if (!result.detected) {
      return Text(
        CategoryCardStrings.nothingToClean,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
      );
    }
    return Text(
      '${result.paths.length}${result.paths.length == 1 ? CategoryCardStrings.locationSingular : CategoryCardStrings.locationPlural}',
      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}