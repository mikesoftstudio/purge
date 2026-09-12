import 'package:flutter/material.dart';

import '../engine/bytes.dart';
import '../engine/types.dart';
import '../state/purge_controller.dart';
import '../theme.dart';
import '../widgets/category_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/safety_badge.dart';
import '../widgets/scanning_indicator.dart';

enum _SortKey { sizeDesc, sizeAsc, nameAsc, nameDesc, safety }

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.controller,
    required this.onClean,
  });

  final PurgeController controller;
  final VoidCallback onClean;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  _SortKey sort = _SortKey.sizeDesc;
  SafetyTier? filterSafety;
  String filterStatus = 'all';
  String query = '';
  final TextEditingController _search = TextEditingController();

  PurgeController get c => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ScanResult> get filtered {
    var list = [...c.results];
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) => r.name.toLowerCase().contains(q)).toList();
    }
    if (filterSafety != null) {
      list = list.where((r) => r.safety == filterSafety).toList();
    }
    if (filterStatus == 'detected') {
      list = list.where((r) => r.detected).toList();
    } else if (filterStatus == 'empty') {
      list = list.where((r) => !r.detected).toList();
    }
    list.sort((a, b) {
      switch (sort) {
        case _SortKey.sizeDesc:
          return b.totalSizeBytes.compareTo(a.totalSizeBytes);
        case _SortKey.sizeAsc:
          return a.totalSizeBytes.compareTo(b.totalSizeBytes);
        case _SortKey.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SortKey.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case _SortKey.safety:
          return a.safety.index.compareTo(b.safety.index);
      }
    });
    return list;
  }

  bool get _hasActiveFilters =>
      filterSafety != null || filterStatus != 'all' || query.isNotEmpty;

  void _resetFilters() {
    setState(() {
      filterSafety = null;
      filterStatus = 'all';
      query = '';
      _search.clear();
    });
  }

  Future<void> _confirmClean() async {
    final items = c.selectedItems;
    if (items.isEmpty) return;
    final hasAdvanced = items.any((r) => r.safety == SafetyTier.advanced);
    final hasTrash = items.any((r) => r.id == 'trash');
    final ok = await showConfirmDialog(
      context: context,
      title: 'Clean these caches?',
      description:
          'This will delete ${items.length} item${items.length == 1 ? '' : 's'} and free ${formatBytes(c.selectedBytes)}.',
      confirmLabel: 'Clean ${items.length} item${items.length == 1 ? '' : 's'}',
      destructive: true,
      acknowledgeLabel: (hasAdvanced || hasTrash) ? 'I understand this cannot be undone' : null,
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
                'Trash items are permanently deleted and cannot be restored.',
                style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
              ),
            ),
          if (hasAdvanced)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Advanced items (like Docker) must be rebuilt or re-downloaded after cleaning.',
                style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
              ),
            ),
        ],
      ),
    );
    if (ok) widget.onClean();
  }

  Future<void> _showDetails(ScanResult result) async {
    final disabled = !result.applicable || (!result.detected && result.totalSizeBytes == 0);
    final selected = c.selected.contains(result.id);
    final ok = await showConfirmDialog(
      context: context,
      title: result.name,
      description: result.description,
      confirmLabel: selected ? 'Deselect' : 'Select',
      confirmDisabled: !selected && disabled,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Reclaimable'),
              const Spacer(),
              Text(
                formatBytes(result.totalSizeBytes),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SafetyBadge(tier: result.safety),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Trade-off: ${result.tradeoff}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (result.paths.where((p) => p.exists).isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Existing paths:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final path in result.paths.where((p) => p.exists))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(path.path, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    if (ok) c.toggle(result.id);
  }

  // --------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    if (c.scanning && c.results.isEmpty && c.scanError == null) {
      return _ScanningView(controller: c);
    }

    if (c.scanError != null && c.results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Scan failed',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Something went wrong while measuring your caches. Nothing was changed on your device.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 16),
              Text(
                c.scanError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: c.scan,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (c.results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: purgeGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.radar, size: 32, color: purgeGreen),
              ),
              const SizedBox(height: 20),
              Text(
                'See what you can clean',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Purge looks for regenerable caches, logs and build artifacts '
                'from the tools on your ${c.noun}. It only reads your disk — '
                'nothing is deleted until you choose it and confirm.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: c.scanning ? null : c.scan,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.radar),
                label: Text(c.scanning ? 'Scanning…' : 'Start scan'),
              ),
            ],
          ),
        ),
      );
    }

    return _ResultsView(
      controller: c,
      sort: sort,
      onSort: (v) => setState(() => sort = v),
      filterSafety: filterSafety,
      onFilterSafety: (v) => setState(() => filterSafety = v),
      filterStatus: filterStatus,
      onFilterStatus: (v) => setState(() => filterStatus = v),
      onSearchChanged: (v) => setState(() => query = v),
      searchController: _search,
      items: filtered,
      hasActiveFilters: _hasActiveFilters,
      onResetFilters: _resetFilters,
      onConfirmClean: _confirmClean,
      onDetails: _showDetails,
    );
  }
}

// ------------------------------------------------------- Scanning state

class _ScanningView extends StatelessWidget {
  const _ScanningView({required this.controller});

  final PurgeController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = controller.scanTotal;
    final done = controller.scanDone;
    final current = controller.scanCurrent;
    final known = total > 0;
    final progress = known ? (done / total).clamp(0.0, 1.0) : null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const ScanningIndicator(size: 140),
              const SizedBox(height: 28),
              Text(
                'Scanning your ${controller.platformName}…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Reading caches and build artifacts. This only measures — '
                'nothing is deleted.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: purgeGreen,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (known)
                    Text(
                      'Checked $done of $total categories',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    )
                  else
                    Text(
                      'Measuring categories…',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                ],
              ),
              if (current != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Currently: $current',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_outlined, color: purgeGreen, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Caches are made to rebuild — that’s why they are safe to remove. '
                        'Your code and personal files are never touched.',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------- Results view

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.controller,
    required this.sort,
    required this.onSort,
    required this.filterSafety,
    required this.onFilterSafety,
    required this.filterStatus,
    required this.onFilterStatus,
    required this.onSearchChanged,
    required this.searchController,
    required this.items,
    required this.hasActiveFilters,
    required this.onResetFilters,
    required this.onConfirmClean,
    required this.onDetails,
  });

  final PurgeController controller;
  final _SortKey sort;
  final ValueChanged<_SortKey> onSort;
  final SafetyTier? filterSafety;
  final ValueChanged<SafetyTier?> onFilterSafety;
  final String filterStatus;
  final ValueChanged<String> onFilterStatus;
  final ValueChanged<String> onSearchChanged;
  final TextEditingController searchController;
  final List<ScanResult> items;
  final bool hasActiveFilters;
  final VoidCallback onResetFilters;
  final VoidCallback onConfirmClean;
  final void Function(ScanResult) onDetails;

  PurgeController get c => controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxSize = c.results.fold<int>(1, (m, r) => r.totalSizeBytes > m ? r.totalSizeBytes : m);
    final detectedCount = c.results.where((r) => r.detected).length;
    final emptyCount = c.results.length - detectedCount;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: purgeGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.delete_sweep_outlined, color: purgeGreen, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatBytes(c.totalReclaimableBytes),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                'reclaimable',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${c.platformName} · $detectedCount categorie${detectedCount == 1 ? 'y' : 's'} with recoverable caches',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: c.scanning ? null : c.scan,
                    icon: Icon(c.scanning ? Icons.hourglass_top : Icons.refresh),
                    label: Text(c.scanning ? 'Rescanning…' : 'Rescan'),
                  ),
                ],
              ),
              if (c.scanning) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: c.scanTotal > 0 ? (c.scanDone / c.scanTotal).clamp(0.0, 1.0) : null,
                    minHeight: 4,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _FiltersRow(
                sort: sort,
                onSort: onSort,
                filterSafety: filterSafety,
                onFilterSafety: onFilterSafety,
                filterStatus: filterStatus,
                onFilterStatus: onFilterStatus,
                onSearchChanged: onSearchChanged,
                searchController: searchController,
              ),
              const SizedBox(height: 12),
              _SelectionRow(
                controllers: c,
                detectedCount: detectedCount,
                emptyCount: emptyCount,
                shownCount: items.length,
                hasActiveFilters: hasActiveFilters,
                onResetFilters: onResetFilters,
              ),
              const SizedBox(height: 8),
              _SafetyExplainLink(),
              const SizedBox(height: 16),
              if (items.isEmpty)
                _EmptyFiltered(onReset: onResetFilters)
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 1000
                        ? 3
                        : constraints.maxWidth >= 640
                            ? 2
                            : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisExtent: 214,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, i) {
                        final r = items[i];
                        return CategoryCard(
                          result: r,
                          maxSize: maxSize,
                          selected: c.selected.contains(r.id),
                          onToggle: () => c.toggle(r.id),
                          onDetails: () => onDetails(r),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
        _SelectionBar(
          controller: c,
          onConfirmClean: onConfirmClean,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------- Filters row

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.sort,
    required this.onSort,
    required this.filterSafety,
    required this.onFilterSafety,
    required this.filterStatus,
    required this.onFilterStatus,
    required this.onSearchChanged,
    required this.searchController,
  });

  final _SortKey sort;
  final ValueChanged<_SortKey> onSort;
  final SafetyTier? filterSafety;
  final ValueChanged<SafetyTier?> onFilterSafety;
  final String filterStatus;
  final ValueChanged<String> onFilterStatus;
  final ValueChanged<String> onSearchChanged;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safetyDots = {
      SafetyTier.safe: purgeGreen,
      SafetyTier.moderate: purgeAmber,
      SafetyTier.advanced: purgeRed,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final search = SizedBox(
          width: constraints.maxWidth >= 900 ? 240 : double.infinity,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search categories',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

        final statusChips = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in [
              ('all', 'All', null),
              ('detected', 'Detected', null),
              ('empty', 'Empty', null),
            ])
              _FilterChip(
                label: entry.$2,
                selected: filterStatus == entry.$1,
                onSelected: () => onFilterStatus(entry.$1),
              ),
          ],
        );

        final safetyChips = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in [
              (null, 'Any level', null),
              (SafetyTier.safe, 'Safe', safetyDots[SafetyTier.safe]),
              (SafetyTier.moderate, 'Moderate', safetyDots[SafetyTier.moderate]),
              (SafetyTier.advanced, 'Advanced', safetyDots[SafetyTier.advanced]),
            ])
              _FilterChip(
                label: entry.$2,
                dotColor: entry.$3,
                selected: filterSafety == entry.$1,
                onSelected: () => onFilterSafety(entry.$1),
              ),
          ],
        );

        final sortMenu = PopupMenuButton<_SortKey>(
          initialValue: sort,
          onSelected: onSort,
          tooltip: 'Sort results',
          itemBuilder: (context) => const [
            PopupMenuItem(value: _SortKey.sizeDesc, child: _SortItem(Icons.south_west, 'Largest first')),
            PopupMenuItem(value: _SortKey.sizeAsc, child: _SortItem(Icons.north_east, 'Smallest first')),
            PopupMenuItem(value: _SortKey.nameAsc, child: _SortItem(Icons.sort_by_alpha, 'Name A → Z')),
            PopupMenuItem(value: _SortKey.nameDesc, child: _SortItem(Icons.sort_by_alpha, 'Name Z → A')),
            PopupMenuItem(value: _SortKey.safety, child: _SortItem(Icons.verified_user_outlined, 'Safety level')),
          ],
          color: scheme.surfaceContainerLow,
          child: _FilterChip(
            label: switch (sort) {
              _SortKey.sizeDesc => 'Largest first',
              _SortKey.sizeAsc => 'Smallest first',
              _SortKey.nameAsc => 'Name A → Z',
              _SortKey.nameDesc => 'Name Z → A',
              _SortKey.safety => 'Safety level',
            },
            icon: Icons.swap_vert,
            selected: false,
            onSelected: () {},
          ),
        );

        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              search,
              const SizedBox(height: 12),
              statusChips,
              const SizedBox(height: 8),
              safetyChips,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: sortMenu),
            ],
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            search,
            const SizedBox(width: 4),
            statusChips,
            safetyChips,
            sortMenu,
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.dotColor,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? dotColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      avatar: icon != null
          ? Icon(
              icon,
              size: 15,
              color: selected
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : (dotColor != null
              ? Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                )
              : null),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _SortItem extends StatelessWidget {
  const _SortItem(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

// ------------------------------------------------------- Selection row

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    required this.controllers,
    required this.detectedCount,
    required this.emptyCount,
    required this.shownCount,
    required this.hasActiveFilters,
    required this.onResetFilters,
  });

  final PurgeController controllers;
  final int detectedCount;
  final int emptyCount;
  final int shownCount;
  final bool hasActiveFilters;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = controllers.selected;
    final total = controllers.results.length;
    final recommendedSelected = controllers.selectable
        .where((r) => r.safety != SafetyTier.advanced)
        .every((r) => selected.contains(r.id));

    final label = Text(
      hasActiveFilters
          ? 'Showing $shownCount of $total categories'
          : 'Select what to clean',
      style: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );

    final recommended = Tooltip(
      message: recommendedSelected
          ? 'Clear your selection'
          : 'Pick Safe & Moderate items only (skips Advanced like Docker)',
      child: TextButton.icon(
        onPressed: recommendedSelected
            ? controllers.clearSelection
            : controllers.selectRecommended,
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        icon: Icon(
          recommendedSelected ? Icons.close : Icons.auto_awesome,
          size: 16,
        ),
        label: Text(recommendedSelected ? 'Clear' : 'Recommended'),
      ),
    );

    final selectAll = Tooltip(
      message: 'Select every available category',
      child: TextButton(
        onPressed: controllers.selectAll,
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        child: const Text('Select all'),
      ),
    );

    final reset = hasActiveFilters
        ? TextButton(
            onPressed: onResetFilters,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Reset filters'),
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  recommended,
                  selectAll,
                  ?reset,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            recommended,
            selectAll,
            ?reset,
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------ Safety explainer

class _SafetyExplainLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _showSafetyTiers(context),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        icon: Icon(
          Icons.help_outline,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        label: Text(
          'What do Safe, Moderate and Advanced mean?',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

Future<void> _showSafetyTiers(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const Text('Safety levels'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Every item Purge finds is a regenerable cache, log or build '
                'artifact — never a project or personal file. The level tells '
                'you how much re-downloading or rebuilding you can expect.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              _TierRow(tier: SafetyTier.safe, body: 'Pure caches and Trash. Removed instantly, rebuilt automatically.'),
              const SizedBox(height: 12),
              _TierRow(tier: SafetyTier.moderate, body: 'Caches that involve a slower one-time rebuild, like Flutter engine artifacts.'),
              const SizedBox(height: 12),
              _TierRow(tier: SafetyTier.advanced, body: 'Heavy items like Docker images and containers that you must re-pull or rebuild.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.tier, required this.body});

  final SafetyTier tier;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SafetyBadge(tier: tier),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(body, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }
}

// ------------------------------------------------------- Empty filtered

class _EmptyFiltered extends StatelessWidget {
  const _EmptyFiltered({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 40, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            'Nothing matches those filters',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different term or reset the filters to see everything.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onReset,
            child: const Text('Reset filters'),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------- Selection bar

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.controller,
    required this.onConfirmClean,
  });

  final PurgeController controller;
  final VoidCallback onConfirmClean;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedCount = controller.selected.length;
    final selectedBytes = controller.selectedBytes;

    final safe = controller.selectedItems.where((r) => r.safety == SafetyTier.safe).length;
    final moderate = controller.selectedItems.where((r) => r.safety == SafetyTier.moderate).length;
    final advanced = controller.selectedItems.where((r) => r.safety == SafetyTier.advanced).length;

    Widget tierBadge(int n, Color color, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(
              '$n $label',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Card(
          color: scheme.surfaceContainerLow,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final summary = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        selectedCount > 0
                            ? Text(
                                '$selectedCount selected',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              )
                            : const Text(
                                'Select categories to free space',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                        if (selectedCount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '· freed',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                    if (selectedCount > 0) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (safe > 0) tierBadge(safe, purgeGreen, 'safe'),
                          if (moderate > 0) tierBadge(moderate, purgeAmber, 'moderate'),
                          if (advanced > 0) tierBadge(advanced, purgeRed, 'advanced'),
                        ],
                      ),
                    ],
                  ],
                );

                final free = Container(
                  margin: const EdgeInsets.only(right: 6),
                  child: Text(
                    formatBytes(selectedBytes),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                );

                final cleanBtn = FilledButton.icon(
                  onPressed: selectedCount == 0 ? null : onConfirmClean,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: Text(
                    selectedCount == 0 ? 'Clean' : 'Clean $selectedCount',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );

                if (constraints.maxWidth < 420) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      summary,
                      const SizedBox(height: 10),
                      Row(
                        children: [free, const Spacer(), cleanBtn],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 12),
                    free,
                    const SizedBox(width: 12),
                    cleanBtn,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}