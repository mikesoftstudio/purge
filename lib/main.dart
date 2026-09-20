import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine/bytes.dart';
import 'screens/clean_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/summary_screen.dart';
import 'state/purge_controller.dart';
import 'theme.dart';
import 'widgets/app_shell.dart';
import 'widgets/clean_confirm.dart';
import 'widgets/command_palette.dart';
import 'widgets/project_roots_dialog.dart';
import 'widgets/settings_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PurgeApp());
}

ScrollBehavior buildScrollBehavior() {
  final desktop = switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => true,
    _ => false,
  };
  return MaterialScrollBehavior().copyWith(
    scrollbars: desktop,
    dragDevices: <PointerDeviceKind>{
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.invertedStylus,
    },
  );
}

class PurgeApp extends StatefulWidget {
  const PurgeApp({super.key, this.controller});

  final PurgeController? controller;

  @override
  State<PurgeApp> createState() => _PurgeAppState();
}

class _PurgeAppState extends State<PurgeApp> {
  late final PurgeController controller;
  int index = 0;
  bool showClean = false;
  bool showSummary = false;
  List<String> cleanIds = const [];
  int expectedFreed = 0;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? PurgeController();
    controller.addListener(_onChange);
    if (widget.controller == null) {
      controller.init();
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onChange);
    if (widget.controller == null) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChange() {
    if (showClean && !controller.cleaning && controller.summary != null) {
      showClean = false;
      showSummary = true;
    }
    setState(() {});
  }

  void _startClean() {
    cleanIds = controller.selected.toList();
    expectedFreed = controller.results
        .where((r) => cleanIds.contains(r.id))
        .fold<int>(0, (acc, r) => acc + finiteBytes(r.totalSizeBytes));
    showClean = true;
    showSummary = false;
    setState(() {});
    controller.cleanSelected();
  }

  Future<void> _startCleanRecommended(BuildContext context) async {
    controller.selectRecommended();
    if (controller.selected.isEmpty) return;
    final ok = await showCleanConfirmDialog(context, controller);
    if (!mounted) return;
    if (ok) _startClean();
  }

  void _startCleanItems(String categoryId, List<String> paths) {
    cleanIds = [categoryId];
    expectedFreed = 0;
    showClean = true;
    showSummary = false;
    setState(() {});
    controller.cleanSelectedPaths(categoryId, paths);
  }

  void _goDashboard() {
    showClean = false;
    showSummary = false;
    index = 0;
    setState(() {});
  }

  void _goScan() {
    showClean = false;
    showSummary = false;
    index = 1;
    setState(() {});
  }

  void _rescanNow() {
    _goScan();
    controller.scan();
  }

  Future<void> _openPalette(BuildContext context) async {
    if (context.mounted) {
      await showCommandPalette(context, [
        PaletteAction(
          label: 'Rescan now',
          icon: Icons.refresh,
          shortcut: '⌘R',
          onSelect: _rescanNow,
        ),
        PaletteAction(
          label: 'Go to Dashboard',
          icon: Icons.space_dashboard_outlined,
          onSelect: _goDashboard,
        ),
        PaletteAction(
          label: 'Go to Scan',
          icon: Icons.cleaning_services_outlined,
          onSelect: _goScan,
        ),
        PaletteAction(
          label: 'Clean the recommended caches',
          icon: Icons.auto_awesome,
          onSelect: () => _startCleanRecommended(context),
        ),
        PaletteAction(
          label: 'Preferences (custom folders, exclusions, automatic)',
          icon: Icons.settings_outlined,
          onSelect: () => showSettingsDialog(context, controller),
        ),
        PaletteAction(
          label: 'Project folders',
          icon: Icons.folder_open_outlined,
          onSelect: () => showProjectRootsDialog(context, controller),
        ),
        if (controller.selected.isNotEmpty)
          PaletteAction(
            label: 'Clear selection',
            icon: Icons.deselect_outlined,
            onSelect: controller.clearSelection,
          ),
        PaletteAction(
          label: 'Cycle theme (light / dark / system)',
          icon: Icons.brightness_6_outlined,
          onSelect: controller.cycleTheme,
        ),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Purge',
      debugShowCheckedModeBanner: false,
      scrollBehavior: buildScrollBehavior(),
      theme: purgeTheme(brightness: Brightness.light),
      darkTheme: purgeTheme(brightness: Brightness.dark),
      themeMode: controller.themeMode,
      home: Builder(
        builder: (innerContext) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
                _rescanNow,
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
                _openPalette(innerContext),
          },
          child: AppShell(
            controller: controller,
            index: index,
            onIndex: (value) {
              showClean = false;
              showSummary = false;
              setState(() => index = value);
            },
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (!controller.ready && widget.controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (showSummary) {
      return SummaryScreen(
        controller: controller,
        onScanAgain: () {
          showSummary = false;
          index = 1;
          controller.scan();
          setState(() {});
        },
        onHome: () {
          showSummary = false;
          index = 0;
          setState(() {});
        },
      );
    }
    if (showClean) {
      return CleanScreen(
        controller: controller,
        ids: cleanIds,
        expectedBytes: expectedFreed,
        onStop: controller.cancelClean,
      );
    }
    if (index == 1) {
      return ScanScreen(
        controller: controller,
        onClean: _startClean,
        onCleanItems: _startCleanItems,
      );
    }
    return DashboardScreen(
      controller: controller,
      onScan: () {
        index = 1;
        if (controller.results.isEmpty && !controller.scanning) {
          controller.scan();
        }
        setState(() {});
      },
      onCleanRecommended: _startCleanRecommended,
    );
  }
}
