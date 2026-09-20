import 'package:flutter/material.dart';

import '../engine/types.dart';
import '../state/purge_controller.dart';
import '../theme.dart';

class AppShellStrings {
  AppShellStrings._();

  static const mark = '◆';
  static const appName = 'Purge';
  static const dashboard = 'Dashboard';
  static const scan = 'Scan';
  static const toggleTheme = 'Toggle theme';
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.controller,
    required this.index,
    required this.onIndex,
    required this.child,
  });

  final PurgeController controller;
  final int index;
  final ValueChanged<int> onIndex;
  final Widget child;

  bool get _isDesktop => switch (controller.platform) {
        AppPlatform.macos || AppPlatform.windows || AppPlatform.linux => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = _isDesktop;
    final showRail = isDesktop && width >= 900;
    final showTopNav = !showRail && width >= 700;
    final showBottomNav = !showRail && !showTopNav;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: purgeGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(AppShellStrings.mark,
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            const Text(AppShellStrings.appName,
                style: TextStyle(fontWeight: FontWeight.w700)),
            if (showTopNav) ...[
              const SizedBox(width: 24),
              _NavButton(
                label: AppShellStrings.dashboard,
                selected: index == 0,
                onTap: () => onIndex(0),
              ),
              _NavButton(
                label: AppShellStrings.scan,
                selected: index == 1,
                onTap: () => onIndex(1),
              ),
            ],
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: purgeGreen),
                const SizedBox(width: 6),
                Text(controller.platformName, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: AppShellStrings.toggleTheme,
            onPressed: controller.cycleTheme,
            icon: Icon(switch (controller.themeMode) {
              ThemeMode.light => Icons.light_mode_outlined,
              ThemeMode.dark => Icons.dark_mode_outlined,
              ThemeMode.system => Icons.contrast,
            }),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 1240 : 1100),
          child: showRail
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NavigationRail(
                      selectedIndex: index,
                      onDestinationSelected: onIndex,
                      labelType: NavigationRailLabelType.all,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: Text(AppShellStrings.dashboard),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.radar_outlined),
                          selectedIcon: Icon(Icons.radar),
                          label: Text(AppShellStrings.scan),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: child),
                  ],
                )
              : child,
        ),
      ),
      bottomNavigationBar: showBottomNav
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: onIndex,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: AppShellStrings.dashboard,
                ),
                NavigationDestination(
                  icon: Icon(Icons.radar_outlined),
                  selectedIcon: Icon(Icons.radar),
                  label: AppShellStrings.scan,
                ),
              ],
            )
          : null,
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
            : null,
        foregroundColor: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      child: Text(label),
    );
  }
}