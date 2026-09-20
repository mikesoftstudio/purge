import 'package:flutter/material.dart';

import '../engine/bytes.dart';
import '../engine/categories.dart';
import '../engine/types.dart';
import '../state/purge_controller.dart';
import '../theme.dart';
import '../ui/strings.dart';
import '../widgets/disk_overview.dart';

class DashboardStrings {
  DashboardStrings._();

  static const heroPrefix = 'Reclaim space on your ';
  static const heroBody = 'Purge safely removes regenerable caches, logs and build artifacts '
      'left behind by your development tools. Your projects, source code '
      'and personal files stay untouched.';
  static const scanMy = 'Scan my ';
  static const recentlyFreedPrefix = 'You recently freed ';
  static const recentlyFreedSuffix =
      '. Everything regenerates on next use — a quick scan keeps it tidy.';
  static const storage = 'Storage';
  static const storageSubMulti =
      'free space on the volume holding your home — every mount listed below';
  static const storageSubSingle = 'on the volume holding your home directory';
  static const volumes = 'Volumes';
  static const home = 'home';
  static const of = ' of ';
  static const safeToReclaimPrefix = 'safe to reclaim across ';
  static const itemSingular = ' item';
  static const itemPlural = ' items';
  static const reviewAndClean = 'Review & clean';
  static const cleanRecommended = 'Clean recommended';
  static const largestOnMac = 'Largest finds on ';
  static const macOS = 'macOS';
  static const thisMac = 'this Mac';
  static const thisDevice = 'this device';
  static const seeAllPrefix = 'See all ';
  static const seeAllSuffix = ' items';
  static const howItStaysSafe = 'How it stays safe';
  static const safeForEveryone =
      'Designed for everyone — from first-time users to command-line veterans.';
  static const readOnlyScan = 'Read-only scan';
  static const readOnlyScanBody =
      'A scan only measures. Nothing is deleted until you confirm it.';
  static const regenerableCaches = 'Regenerable caches';
  static const regenerableCachesBody =
      'Everything Purge removes is a cache, log or build artifact — never your '
      'projects or personal files.';
  static const guardedDeletion = 'Guarded deletion';
  static const guardedDeletionBody =
      'Dangerous paths like your home directory and system roots are validated and rejected.';
  static const deviceDetails = 'Device details';
  static const techSubtitle = 'For power users — platform, paths and scan coverage.';
  static const emDash = '—';
  static const platform = 'Platform';
  static const systemVolume = 'System volume';
  static const homeLabel = 'Home';
  static const tempLabel = 'Temp';
  static const dataDir = 'Data dir';
  static const categoriesLabel = 'Categories';
  static const coveredSuffix = ' covered on ';
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.onScan,
    required this.onCleanRecommended,
  });

  final PurgeController controller;
  final VoidCallback onScan;
  final ValueChanged<BuildContext> onCleanRecommended;

  @override
  Widget build(BuildContext context) {
    final hasDisk = controller.disk.totalBytes > 0;
    final detected = controller.results
        .where((r) => r.detected && r.totalSizeBytes > 0)
        .toList()
      ..sort((a, b) => b.totalSizeBytes.compareTo(a.totalSizeBytes));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        _Hero(controller: controller, onScan: onScan),
        if (controller.lastFreedBytes > 0) ...[
          const SizedBox(height: 16),
          _RecentlyFreed(bytes: controller.lastFreedBytes),
        ],
        if (hasDisk) ...[
          const SizedBox(height: 16),
          _StorageCard(
            controller: controller,
            reclaimable: controller.results.isEmpty
                ? null
                : controller.totalReclaimableBytes,
          ),
        ],
        if (detected.isNotEmpty) ...[
          const SizedBox(height: 16),
          _LastScanCard(
            results: detected,
            totalBytes: controller.totalReclaimableBytes,
            platformName: controller.platformName,
            onScan: onScan,
            onCleanRecommended: detected
                    .any((r) => r.applicable && r.safety != SafetyTier.advanced)
                ? onCleanRecommended
                : null,
          ),
        ],
        const SizedBox(height: 16),
        _SafetySection(),
        const SizedBox(height: 16),
        _TechDetails(controller: controller),
      ],
    );
  }
}

// ---------------------------------------------------------------- Hero

class _Hero extends StatelessWidget {
  const _Hero({required this.controller, required this.onScan});

  final PurgeController controller;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final headline = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${DashboardStrings.heroPrefix}${controller.noun}',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold, height: 1.15),
        ),
        const SizedBox(height: 10),
        Text(
          DashboardStrings.heroBody,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15, height: 1.45),
        ),
      ],
    );

    final actions = FilledButton.icon(
      onPressed: onScan,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.radar),
      label: Text('${DashboardStrings.scanMy}${controller.noun}'),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  scheme.primary.withValues(alpha: 0.22),
                  scheme.surfaceContainerHigh,
                ]
              : [
                  purgeGreen.withValues(alpha: 0.13),
                  scheme.surfaceContainerLow,
                ],
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headline,
                const SizedBox(height: 20),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: headline),
              const SizedBox(width: 24),
              actions,
            ],
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------- Recently freed

class _RecentlyFreed extends StatelessWidget {
  const _RecentlyFreed({required this.bytes});

  final int bytes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF052E16) : const Color(0xFFECFDF5),
        border: Border.all(color: isDark ? const Color(0xFF166534) : const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: purgeGreenDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: DashboardStrings.recentlyFreedPrefix),
                  TextSpan(
                    text: formatBytes(bytes),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: DashboardStrings.recentlyFreedSuffix),
                ],
              ),
              style: TextStyle(color: scheme.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- Storage

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.controller, required this.reclaimable});

  final PurgeController controller;
  final int? reclaimable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final volumes = controller.disk.volumes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  DashboardStrings.storage,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    volumes.length > 1
                        ? DashboardStrings.storageSubMulti
                        : DashboardStrings.storageSubSingle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            DiskOverview(
              disk: controller.disk,
              reclaimableBytes: reclaimable,
            ),
            if (volumes.length > 1) ...[
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _VolumeList(volumes: volumes, home: controller.disk.home),
            ],
          ],
        ),
      ),
    );
  }
}

class _VolumeList extends StatelessWidget {
  const _VolumeList({required this.volumes, required this.home});

  final List<DiskVolume> volumes;
  final String home;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = [...volumes]..sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DashboardStrings.volumes,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        for (final v in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VolumeRow(
              volume: v,
              isHome: home.isNotEmpty &&
                  (v.mountPoint == home || home.startsWith('${v.mountPoint}/')),
            ),
          ),
      ],
    );
  }
}

class VolumeRow extends StatelessWidget {
  const VolumeRow({super.key, required this.volume, required this.isHome});

  final DiskVolume volume;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final usedPct = volume.totalBytes > 0
        ? (volume.usedBytes / volume.totalBytes).clamp(0.0, 1.0)
        : 0.0;
    final label = _shortLabel(volume);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isHome ? FontWeight.w700 : FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (isHome) ...[
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: purgeGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  DashboardStrings.home,
                  style: TextStyle(fontSize: 10, color: purgeGreenDark),
                ),
              ),
            ],
            Text(
              '${formatBytesShort(volume.usedBytes)}${DashboardStrings.of}${formatBytesShort(volume.totalBytes)}',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: usedPct,
            minHeight: 4,
            color: isHome ? purgeGreen : scheme.outline,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  String _shortLabel(DiskVolume v) {
    final m = v.mountPoint;
    final name = m == '/' || m.isEmpty ? '' : m.split('/').last;
    if (name.isNotEmpty) return name;
    return v.filesystem.split('/').last;
  }
}

// ------------------------------------------------------ Last scan result

class _LastScanCard extends StatelessWidget {
  const _LastScanCard({
    required this.results,
    required this.totalBytes,
    required this.platformName,
    required this.onScan,
    this.onCleanRecommended,
  });

  final List<ScanResult> results;
  final int totalBytes;
  final String platformName;
  final VoidCallback onScan;
  final ValueChanged<BuildContext>? onCleanRecommended;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxSize = results.fold<int>(1, (m, r) => r.totalSizeBytes > m ? r.totalSizeBytes : m);
    final top = results.take(3).toList();

    final summary = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: purgeGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: purgeGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatBytes(totalBytes),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: purgeGreenDark,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${DashboardStrings.safeToReclaimPrefix}${results.length}${results.length == 1 ? DashboardStrings.itemSingular : DashboardStrings.itemPlural}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text(DashboardStrings.reviewAndClean),
          ),
          if (onCleanRecommended != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onCleanRecommended!(context),
              icon: const Icon(Icons.auto_fix_high),
              label: const Text(DashboardStrings.cleanRecommended),
            ),
          ],
        ],
      ),
    );

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${DashboardStrings.largestOnMac}${platformName == DashboardStrings.macOS ? DashboardStrings.thisMac : DashboardStrings.thisDevice}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 12),
        for (final r in top)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MiniBar(result: r, maxSize: maxSize),
          ),
        if (results.length > 3)
          TextButton(
            onPressed: onScan,
            child: Text('${DashboardStrings.seeAllPrefix}${results.length}${DashboardStrings.seeAllSuffix}'),
          ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [summary, const SizedBox(height: 20), list],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 260, child: summary),
                const SizedBox(width: 24),
                Expanded(child: list),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.result, required this.maxSize});

  final ScanResult result;
  final int maxSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = (result.totalSizeBytes / maxSize).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                result.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              ),
            ),
            Text(
              formatBytes(result.totalSizeBytes),
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            color: purgeGreen,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- Safety

class _SafetySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = [
      (
        Icons.visibility_outlined,
        DashboardStrings.readOnlyScan,
        DashboardStrings.readOnlyScanBody,
      ),
      (
        Icons.refresh_outlined,
        DashboardStrings.regenerableCaches,
        DashboardStrings.regenerableCachesBody,
      ),
      (
        Icons.shield_outlined,
        DashboardStrings.guardedDeletion,
        DashboardStrings.guardedDeletionBody,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              DashboardStrings.howItStaysSafe,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              DashboardStrings.safeForEveryone,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 620
                        ? 2
                        : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: features.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisExtent: 132,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, i) => _FeatureCard(
                    icon: features[i].$1,
                    title: features[i].$2,
                    body: features[i].$3,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: purgeGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Tech

class _TechDetails extends StatelessWidget {
  const _TechDetails({required this.controller});

  final PurgeController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final env = controller.env;

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? DashboardStrings.emDash : value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontFamily: label == DashboardStrings.homeLabel ||
                          label == DashboardStrings.tempLabel
                      ? Strings.monospace
                      : null,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        leading: Icon(Icons.terminal_outlined, color: scheme.onSurfaceVariant),
        title: const Text(
          DashboardStrings.deviceDetails,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          DashboardStrings.techSubtitle,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
        ),
        children: [
          const Divider(height: 24),
          row(DashboardStrings.platform, controller.platformName),
          row(DashboardStrings.systemVolume,
              controller.disk.filesystem == 'unknown' ? DashboardStrings.emDash : controller.disk.filesystem),
          row(DashboardStrings.volumes,
              controller.disk.volumes.isEmpty ? DashboardStrings.emDash : '${controller.disk.volumes.length}'),
          row(DashboardStrings.homeLabel, env?.home ?? ''),
          row(DashboardStrings.tempLabel, env?.tempDir ?? ''),
          row(DashboardStrings.dataDir, env?.localAppData ?? ''),
          row(
            DashboardStrings.categoriesLabel,
            '${categoriesForPlatform(controller.platform).length}${DashboardStrings.coveredSuffix}${controller.platformName}',
          ),
        ],
      ),
    );
  }
}