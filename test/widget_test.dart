import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:purge/engine/categories.dart';
import 'package:purge/engine/types.dart';
import 'package:purge/main.dart';
import 'package:purge/screens/scan_screen.dart';
import 'package:purge/state/purge_controller.dart';
import 'package:purge/theme.dart';
import 'package:purge/widgets/category_card.dart';

HostEnv _env(AppPlatform platform) => HostEnv(
      platform: platform,
      home: '/home/test',
      localAppData: '/home/test/appdata',
      tempDir: '/home/test/tmp',
      cargoHome: '/home/test/.cargo',
      mobileCachePaths: const [],
    );

void main() {
  testWidgets('Purge app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PurgeApp());
    await tester.pump();
    expect(find.text('Purge'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('desktop layout uses a navigation rail', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = PurgeController()
      ..ready = true
      ..env = _env(AppPlatform.macos);
    await tester.pumpWidget(PurgeApp(controller: controller));
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('mobile layout uses a bottom navigation bar', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = PurgeController()
      ..ready = true
      ..env = _env(AppPlatform.android);
    await tester.pumpWidget(PurgeApp(controller: controller));
    await tester.pump();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('scan results render category cards', (WidgetTester tester) async {
    final controller = PurgeController()
      ..ready = true
      ..env = _env(AppPlatform.macos)
      ..results = [
        ScanResult(
          category: getCategory('trash')!,
          paths: const [],
          totalSizeBytes: 5 * 1024 * 1024,
          applicable: true,
          detected: true,
        ),
        ScanResult(
          category: getCategory('docker')!,
          paths: const [],
          totalSizeBytes: 12 * 1024 * 1024,
          applicable: true,
          detected: true,
        ),
      ]
      ..selected.add('trash');

    await tester.pumpWidget(
      MaterialApp(
        theme: purgeTheme(brightness: Brightness.light),
        home: Scaffold(
          body: ScanScreen(controller: controller, onClean: () {}),
        ),
      ),
    );

    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Docker'), findsOneWidget);
    expect(find.byType(CategoryCard), findsNWidgets(2));
    expect(find.text('Clean 1'), findsOneWidget);
  });

  testWidgets('recommended selection skips advanced items', (WidgetTester tester) async {
    final controller = PurgeController()
      ..ready = true
      ..env = _env(AppPlatform.macos)
      ..results = [
        ScanResult(
          category: getCategory('trash')!,
          paths: const [],
          totalSizeBytes: 5 * 1024 * 1024,
          applicable: true,
          detected: true,
        ),
        ScanResult(
          category: getCategory('docker')!,
          paths: const [],
          totalSizeBytes: 12 * 1024 * 1024,
          applicable: true,
          detected: true,
        ),
      ];

    controller.selectRecommended();
    expect(controller.selected, contains('trash'));
    expect(controller.selected, isNot(contains('docker')));
  });
}