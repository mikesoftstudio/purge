import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'screens/clean_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/summary_screen.dart';
import 'state/purge_controller.dart';
import 'theme.dart';
import 'widgets/app_shell.dart';

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
    showClean = true;
    showSummary = false;
    setState(() {});
    controller.cleanSelected();
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
      home: AppShell(
        controller: controller,
        index: showClean || showSummary ? index : index,
        onIndex: (value) {
          showClean = false;
          showSummary = false;
          setState(() => index = value);
        },
        child: _body(),
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
        onStop: controller.cancelClean,
      );
    }
    if (index == 1) {
      return ScanScreen(
        controller: controller,
        onClean: _startClean,
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
    );
  }
}
