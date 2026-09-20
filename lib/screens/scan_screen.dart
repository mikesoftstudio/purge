import 'package:flutter/material.dart';

import '../engine/bytes.dart';
import '../engine/types.dart';
import '../state/purge_controller.dart';
import '../theme.dart';
import '../ui/strings.dart';
import '../widgets/category_card.dart';
import '../widgets/clean_confirm.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/project_roots_dialog.dart';
import '../widgets/safety_badge.dart';
import '../widgets/scanning_indicator.dart';
import '../widgets/settings_dialog.dart';

class ScanScreenStrings {
  ScanScreenStrings._();

  static const searchHint = 'Search categories';
  static const statusCaption = 'Status';
  static const safetyCaption = 'Safety';
  static const sortCaption = 'Sort';
  static const statusAll = 'All';
  static const statusDetected = 'Detected';
  static const statusEmpty = 'Empty';
  static const anyLevel = 'Any level';
  static const sortLargest = 'Largest first';
  static const sortSmallest = 'Smallest first';
  static const sortNameAsc = 'Name A → Z';
  static const sortNameDesc = 'Name Z → A';
  static const sortSafety = 'Safety level';

  static const cleanAgeCaption = 'Clean age';
  static const ageAny = 'Any age';
  static const age1 = 'Older than 1 day';
  static const age3 = 'Older than 3 days';
  static const age7 = 'Older than 7 days';
  static const age14 = 'Older than 14 days';
  static const age30 = 'Older than 30 days';
}

enum _SortKey { sizeDesc, sizeAsc, nameAsc, nameDesc, safety }

const _entriesDisplayedTotal = 150;

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.controller,
    required this.onClean,
    required this.onCleanItems,
  });

  final PurgeController controller;
  final VoidCallback onClean;
  final void Function(String categoryId, List<String> paths) onCleanItems;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  _SortKey sort = _SortKey.sizeDesc;
  SafetyTier? filterSafety;
  String filterStatus = 'detected';
  String query = '';
  CategoryKind tab = CategoryKind.caches;
  int _ageDays = 0;
  final TextEditingController _search = TextEditingController();

  PurgeController get c => widget.controller;

  static const _defaultStatus = 'detected';

  @override
  void initState() {
    super.initState();
    _ageDays = c.ageFilterDays;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ScanResult> get filtered {
    var list = c.results.where((r) => r.category.kind == tab).toList();
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
      filterSafety != null || filterStatus != _defaultStatus || query.isNotEmpty;

  void _resetFilters() {
    setState(() {
      filterSafety = null;
      filterStatus = _defaultStatus;
      query = '';
      _search.clear();
    });
  }

  Future<void> _confirmClean() async {
    final ok = await showCleanConfirmDialog(context, c);
    if (ok) widget.onClean();
  }

  Future<void> _showDetails(ScanResult result) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CategoryItemsDialog(
        result: result,
        controller: c,
        onCleanItems: widget.onCleanItems,
      ),
    );
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
                'from the apps and tools on your ${c.noun}. It only reads your '
                'disk — nothing is deleted until you choose it and confirm.',
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
              if (c.supportsProjects) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => showProjectRootsDialog(context, c),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Project folders…'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return _ResultsView(
      controller: c,
      tab: tab,
      onTabChanged: (v) => setState(() => tab = v),
      sort: sort,
      onSort: (v) => setState(() => sort = v),
      filterSafety: filterSafety,
      onFilterSafety: (v) => setState(() => filterSafety = v),
      filterStatus: filterStatus,
      onFilterStatus: (v) => setState(() => filterStatus = v),
      ageDays: _ageDays,
      onAgeDays: (v) {
        setState(() => _ageDays = v);
        c.setAgeFilterDays(v);
      },
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

// ------------------------------------------------------- Items dialog

class _CategoryItemsDialog extends StatefulWidget {
  const _CategoryItemsDialog({
    required this.result,
    required this.controller,
    required this.onCleanItems,
  });

  final ScanResult result;
  final PurgeController controller;
  final void Function(String categoryId, List<String> paths) onCleanItems;

  @override
  State<_CategoryItemsDialog> createState() => _CategoryItemsDialogState();
}

class _CategoryItemsDialogState extends State<_CategoryItemsDialog> {
  bool _loading = true;
  List<ScanEntry> _items = const [];
  bool _truncated = false;
  final Set<String> _checked = {};

  ScanResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final itemResult = await widget.controller.itemsFor(result);
    if (!mounted) return;
    setState(() {
      _items = itemResult.entries;
      _truncated = itemResult.truncated;
      _loading = false;
    });
  }

  void _toggle(ScanEntry entry, bool? value) {
    setState(() {
      if (value ?? false) {
        _checked.add(entry.id);
      } else {
        _checked.remove(entry.id);
      }
    });
  }

  void _selectAll() {
    setState(() => _checked..addAll(_items.map((e) => e.id)));
  }

  void _clear() {
    setState(() => _checked.clear());
  }

  int get _checkedBytes => _items
      .where((e) => _checked.contains(e.id))
      .fold<int>(0, (acc, e) => acc + finiteBytes(e.sizeBytes));

  Future<void> _toggleWholeCategory() async {
    widget.controller.toggle(result.id);
    Navigator.pop(context, true);
  }

  Future<void> _deleteSelected() async {
    final entries = _items.where((e) => _checked.contains(e.id)).toList();
    if (entries.isEmpty) return;
    final paths = entries.map((e) => e.path).toList();
    final ok = await showConfirmDialog(
      context: context,
      title: 'Delete ${paths.length} item${paths.length == 1 ? '' : 's'}?',
      description:
          'Only the ${paths.length} item${paths.length == 1 ? '' : 's'} you picked will be removed. '
          'This frees ${formatBytes(_checkedBytes)} — keep these values in mind when managing your disk.',
      confirmLabel: 'Delete selected item${paths.length == 1 ? '' : 's'}',
      destructive: true,
      acknowledgeLabel: 'I understand this cannot be undone',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 160),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  e.path,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
    if (!ok) return;
    if (!mounted) return;
    final id = result.id;
    Navigator.pop(context);
    widget.onCleanItems(id, paths);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              result.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SafetyBadge(tier: result.safety),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      content: SizedBox(
        width: 460,
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Trade-off: ${result.tradeoff}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 20),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No individual items could be listed for this category. '
                  'Use "Whole category" to clean it instead.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else ...[
              Row(
                children: [
                  Text(
                    '${_items.length} item${_items.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelLarge,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _checked.length == _items.length ? _clear : _selectAll,
                    child: Text(_checked.length == _items.length ? 'Clear' : 'Select all'),
                  ),
                ],
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in _items)
                      CheckboxListTile(
                        value: _checked.contains(entry.id),
                        onChanged: (value) => _toggle(entry, value),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: Transform.scale(
                          scale: 1.2,
                          child: Icon(
                            entry.kind == EntryKind.directory
                                ? Icons.folder_outlined
                                : Icons.description_outlined,
                            size: 22,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              formatBytes(entry.sizeBytes),
                              style: const TextStyle(
                                fontSize: 12,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          entry.path,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              if (_truncated) ...[
                const SizedBox(height: 4),
                Text(
                  'Showing the largest $_entriesDisplayedTotal items. '
                  'Use "Whole category" to clean everything.',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Done'),
        ),
        TextButton(
          onPressed: _toggleWholeCategory,
          child: Text(
            widget.controller.selected.contains(result.id)
                ? 'Deselect whole category'
                : 'Select whole category',
          ),
        ),
        if (_items.isNotEmpty)
          FilledButton(
            onPressed: _checked.isEmpty ? null : _deleteSelected,
            child: Text(
              _checked.isEmpty
                  ? 'Delete selected'
                  : 'Delete ${_checked.length} selected',
            ),
          ),
      ],
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
    required this.tab,
    required this.onTabChanged,
    required this.sort,
    required this.onSort,
    required this.filterSafety,
    required this.onFilterSafety,
    required this.filterStatus,
    required this.onFilterStatus,
    required this.ageDays,
    required this.onAgeDays,
    required this.onSearchChanged,
    required this.searchController,
    required this.items,
    required this.hasActiveFilters,
    required this.onResetFilters,
    required this.onConfirmClean,
    required this.onDetails,
  });

  final PurgeController controller;
  final CategoryKind tab;
  final ValueChanged<CategoryKind> onTabChanged;
  final _SortKey sort;
  final ValueChanged<_SortKey> onSort;
  final SafetyTier? filterSafety;
  final ValueChanged<SafetyTier?> onFilterSafety;
  final String filterStatus;
  final ValueChanged<String> onFilterStatus;
  final int ageDays;
  final ValueChanged<int> onAgeDays;
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
    final tabResults = c.results.where((r) => r.category.kind == tab).toList();
    final maxSize = tabResults.fold<int>(1, (m, r) => r.totalSizeBytes > m ? r.totalSizeBytes : m);
    final detectedCount = tabResults.where((r) => r.detected).length;
    final emptyCount = tabResults.length - detectedCount;
    final reclaimable = tabResults
        .where((r) => r.detected)
        .fold<int>(0, (acc, r) => acc + r.totalSizeBytes);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
            children: [
              _ResultsHeader(
                controller: c,
                tab: tab,
                reclaimable: reclaimable,
                detectedCount: detectedCount,
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
              const SizedBox(height: 16),
              _KindTabs(
                tab: tab,
                onTabChanged: onTabChanged,
                cacheCount: c.results.where((r) => r.category.kind == CategoryKind.caches && r.detected).length,
                fileCount: c.results.where((r) => r.category.kind == CategoryKind.files && r.detected).length,
              ),
              const SizedBox(height: 16),
              _FiltersRow(
                sort: sort,
                onSort: onSort,
                filterSafety: filterSafety,
                onFilterSafety: onFilterSafety,
                filterStatus: filterStatus,
                onFilterStatus: onFilterStatus,
                ageDays: ageDays,
                onAgeDays: onAgeDays,
                onSearchChanged: onSearchChanged,
                searchController: searchController,
              ),
              const SizedBox(height: 12),
              _SelectionRow(
                controllers: c,
                detectedCount: detectedCount,
                emptyCount: emptyCount,
                shownCount: items.length,
                totalCount: tabResults.length,
                hasActiveFilters: hasActiveFilters,
                onResetFilters: onResetFilters,
              ),
              const SizedBox(height: 8),
              _SafetyExplainLink(),
              const SizedBox(height: 16),
              if (items.isEmpty)
                _EmptyFiltered(
                  detectedCount: detectedCount,
                  onReset: onResetFilters,
                  onRescan: c.scan,
                )
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

// -------------------------------------------------------- Results header

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.controller,
    required this.tab,
    required this.reclaimable,
    required this.detectedCount,
  });

  final PurgeController controller;
  final CategoryKind tab;
  final int reclaimable;
  final int detectedCount;

  PurgeController get c => controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFiles = tab == CategoryKind.files;
    final subtitle = isFiles
        ? '${c.platformName} · $detectedCount large file${detectedCount == 1 ? '' : 's'} in your home folder'
        : '${c.platformName} · $detectedCount categorie${detectedCount == 1 ? 'y' : 's'} with recoverable caches';

    return Row(
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
                    formatBytes(reclaimable),
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
                      isFiles ? 'in large files' : 'reclaimable',
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
                subtitle,
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
        const SizedBox(width: 8),
        if (c.supportsProjects) ...[
          IconButton(
            tooltip: 'Project cache folders',
            onPressed: () => showProjectRootsDialog(context, c),
            icon: const Icon(Icons.folder_open),
          ),
          const SizedBox(width: 4),
        ],
        IconButton(
          tooltip: 'Preferences',
          onPressed: () => showSettingsDialog(context, c),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- Kind tabs

class _KindTabs extends StatelessWidget {
  const _KindTabs({
    required this.tab,
    required this.onTabChanged,
    required this.cacheCount,
    required this.fileCount,
  });

  final CategoryKind tab;
  final ValueChanged<CategoryKind> onTabChanged;
  final int cacheCount;
  final int fileCount;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CategoryKind>(
      segments: [
        ButtonSegment(
          value: CategoryKind.caches,
          icon: const Icon(Icons.inventory_2_outlined, size: 18),
          label: Text(cacheCount == 0 ? 'Caches' : 'Caches ($cacheCount)'),
        ),
        ButtonSegment(
          value: CategoryKind.files,
          icon: const Icon(Icons.insert_drive_file_outlined, size: 18),
          label: Text(fileCount == 0 ? 'Files' : 'Files ($fileCount)'),
        ),
      ],
      selected: {tab},
      onSelectionChanged: (s) => onTabChanged(s.first),
      showSelectedIcon: false,
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
    required this.ageDays,
    required this.onAgeDays,
    required this.onSearchChanged,
    required this.searchController,
  });

  final _SortKey sort;
  final ValueChanged<_SortKey> onSort;
  final SafetyTier? filterSafety;
  final ValueChanged<SafetyTier?> onFilterSafety;
  final String filterStatus;
  final ValueChanged<String> onFilterStatus;
  final int ageDays;
  final ValueChanged<int> onAgeDays;
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

    Widget dropdown(String caption, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              caption,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            child,
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final search = SizedBox(
          width: constraints.maxWidth >= 900 ? 240 : double.infinity,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: ScanScreenStrings.searchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

        final statusField = dropdown(
          ScanScreenStrings.statusCaption,
          _FilterDropdown<String>(
            value: filterStatus,
            onChanged: onFilterStatus,
            options: [
              const _DropdownOption(value: 'all', label: ScanScreenStrings.statusAll),
              const _DropdownOption(
                  value: 'detected', label: ScanScreenStrings.statusDetected),
              const _DropdownOption(value: 'empty', label: ScanScreenStrings.statusEmpty),
            ],
          ),
        );

        final safetyField = dropdown(
          ScanScreenStrings.safetyCaption,
          _FilterDropdown<SafetyTier?>(
            value: filterSafety,
            onChanged: onFilterSafety,
            options: [
              const _DropdownOption<SafetyTier?>(
                  value: null, label: ScanScreenStrings.anyLevel),
              _DropdownOption(
                value: SafetyTier.safe,
                label: Strings.safe,
                dotColor: safetyDots[SafetyTier.safe],
              ),
              _DropdownOption(
                value: SafetyTier.moderate,
                label: Strings.moderate,
                dotColor: safetyDots[SafetyTier.moderate],
              ),
              _DropdownOption(
                value: SafetyTier.advanced,
                label: Strings.advanced,
                dotColor: safetyDots[SafetyTier.advanced],
              ),
            ],
          ),
        );

        final sortField = dropdown(
          ScanScreenStrings.sortCaption,
          _FilterDropdown<_SortKey>(
            value: sort,
            onChanged: onSort,
            options: const [
              _DropdownOption(
                  value: _SortKey.sizeDesc,
                  label: ScanScreenStrings.sortLargest,
                  icon: Icons.south_west),
              _DropdownOption(
                  value: _SortKey.sizeAsc,
                  label: ScanScreenStrings.sortSmallest,
                  icon: Icons.north_east),
              _DropdownOption(
                  value: _SortKey.nameAsc,
                  label: ScanScreenStrings.sortNameAsc,
                  icon: Icons.sort_by_alpha),
              _DropdownOption(
                  value: _SortKey.nameDesc,
                  label: ScanScreenStrings.sortNameDesc,
                  icon: Icons.sort_by_alpha),
              _DropdownOption(
                  value: _SortKey.safety,
                  label: ScanScreenStrings.sortSafety,
                  icon: Icons.verified_user_outlined),
            ],
          ),
        );

        final ageField = dropdown(
          ScanScreenStrings.cleanAgeCaption,
          _FilterDropdown<int>(
            value: ageDays,
            onChanged: onAgeDays,
            options: const [
              _DropdownOption(value: 0, label: ScanScreenStrings.ageAny),
              _DropdownOption(value: 1, label: ScanScreenStrings.age1),
              _DropdownOption(value: 3, label: ScanScreenStrings.age3),
              _DropdownOption(value: 7, label: ScanScreenStrings.age7),
              _DropdownOption(value: 14, label: ScanScreenStrings.age14),
              _DropdownOption(value: 30, label: ScanScreenStrings.age30),
            ],
          ),
        );

        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              search,
              const SizedBox(height: 12),
              statusField,
              const SizedBox(height: 8),
              safetyField,
              const SizedBox(height: 8),
              sortField,
              const SizedBox(height: 8),
              ageField,
            ],
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            search,
            statusField,
            safetyField,
            sortField,
            ageField,
          ],
        );
      },
    );
  }
}

class _DropdownOption<T> {
  const _DropdownOption({
    required this.value,
    required this.label,
    this.dotColor,
    this.icon,
  });

  final T value;
  final String label;
  final Color? dotColor;
  final IconData? icon;
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.onChanged,
    required this.options,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<_DropdownOption<T>> options;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: scheme.surfaceContainerLow,
          style: TextStyle(color: scheme.onSurface, fontSize: 13),
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          items: [
            for (final o in options)
              DropdownMenuItem<T>(
                value: o.value,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (o.dotColor != null) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: o.dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (o.icon != null) ...[
                      Icon(o.icon, size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                    ],
                    Text(o.label),
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
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
    required this.totalCount,
    required this.hasActiveFilters,
    required this.onResetFilters,
  });

  final PurgeController controllers;
  final int detectedCount;
  final int emptyCount;
  final int shownCount;
  final int totalCount;
  final bool hasActiveFilters;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = controllers.selected;
    final total = totalCount;
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
  const _EmptyFiltered({
    required this.detectedCount,
    required this.onReset,
    required this.onRescan,
  });

  final int detectedCount;
  final VoidCallback onReset;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nothingFound = detectedCount == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            nothingFound ? Icons.check_circle_outline : Icons.search_off,
            size: 40,
            color: scheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            nothingFound ? 'Nothing to clean' : 'Nothing matches those filters',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            nothingFound
                ? 'No regenerable caches, build artifacts or large files were detected.'
                : 'Try a different term or reset the filters to see everything.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 14),
          nothingFound
              ? OutlinedButton.icon(
                  onPressed: onRescan,
                  icon: const Icon(Icons.radar),
                  label: const Text('Rescan'),
                )
              : OutlinedButton(
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