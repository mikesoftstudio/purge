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
          body: ScanScreen(
            controller: controller,
            onClean: () {},
            onCleanItems: (id, paths) {},
          ),
        ),
      ),
    );

    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Docker'), findsOneWidget);
    expect(find.byType(CategoryCard), findsNWidgets(2));
    expect(find.text('Clean 1'), findsOneWidget);
  });

  testWidgets('tabs separate caches and files', (WidgetTester tester) async {
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
          category: getCategory('large-files')!,
          paths: const [],
          totalSizeBytes: 1024 * 1024,
          applicable: true,
          detected: true,
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: purgeTheme(brightness: Brightness.light),
        home: Scaffold(
          body: ScanScreen(
            controller: controller,
            onClean: () {},
            onCleanItems: (id, paths) {},
          ),
        ),
      ),
    );

    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Large Files'), findsNothing);
    expect(find.text('Caches (1)'), findsOneWidget);
    expect(find.text('Files (1)'), findsOneWidget);

    await tester.tap(find.text('Files (1)'));
    await tester.pump();

    expect(find.text('Large Files'), findsOneWidget);
    expect(find.text('Trash'), findsNothing);
    expect(find.text('in large files'), findsOneWidget);
  });

  testWidgets('cards show a hint when a scan needs attention', (WidgetTester tester) async {
    final controller = PurgeController()
      ..ready = true
      ..env = _env(AppPlatform.android)
      ..results = [
        ScanResult(
          category: getCategory('app-caches')!,
          paths: const [],
          totalSizeBytes: 0,
          applicable: true,
          detected: false,
          scanHint:
              'Grant "Files & media" (all files access) in Settings to clean app caches',
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: purgeTheme(brightness: Brightness.light),
        home: Scaffold(
          body: ScanScreen(
            controller: controller,
            onClean: () {},
            onCleanItems: (id, paths) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('all files access'), findsNothing);

    await tester.tap(find.text('Detected'));
    await tester.pump();
    await tester.tap(find.text('Empty'));
    await tester.pump();

    expect(find.textContaining('all files access'), findsOneWidget);
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

  test('categories for a platform are relevant to it', () {
    final android = categoriesForPlatform(AppPlatform.android).map((c) => c.id);
    expect(android.toSet(), {'app-caches', 'system-caches'});

    final ios = categoriesForPlatform(AppPlatform.ios).map((c) => c.id);
    expect(ios, ['app-caches']);

    final windows = categoriesForPlatform(AppPlatform.windows).map((c) => c.id).toSet();
    expect(
      windows,
      containsAll([
        'trash',
        'npm-cache',
        'pip-cache',
        'gradle-build-caches',
        'docker',
        'dotnet-nuget',
        'chocolatey-cache',
        'scoop-cache',
        'user-app-caches',
      ]),
    );
    expect(windows, isNot(contains('app-caches')));

    final macos = categoriesForPlatform(AppPlatform.macos).map((c) => c.id).toSet();
    expect(
      macos,
      containsAll([
        'homebrew-cache',
        'cocoapods-cache',
        'xcode-deriveddata',
        'ios-simulators',
        'flutter-pub-cache',
        'user-app-caches',
      ]),
    );
    expect(macos, isNot(contains('app-caches')));

    final linux = categoriesForPlatform(AppPlatform.linux).map((c) => c.id);
    expect(linux, contains('user-app-caches'));
  });
}