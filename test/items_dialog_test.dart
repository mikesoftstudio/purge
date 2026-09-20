import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:purge/engine/categories.dart';
import 'package:purge/engine/types.dart';
import 'package:purge/screens/scan_screen.dart';
import 'package:purge/state/purge_controller.dart';

void main() {
  testWidgets('details dialog lists individual files and allows selection',
      (WidgetTester tester) async {
    final temp = Directory.systemTemp.createTempSync('purge_items_dialog_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    File(p.join(temp.path, 'a.dat')).writeAsBytesSync(List<int>.filled(2048, 0));
    File(p.join(temp.path, 'b.dat')).writeAsBytesSync(List<int>.filled(4096, 0));

    final controller = PurgeController()
      ..ready = true
      ..env = HostEnv(
        platform: AppPlatform.macos,
        home: temp.path,
        localAppData: '${temp.path}/Library/Application Support',
        tempDir: '${temp.path}/tmp',
        cargoHome: '${temp.path}/.cargo',
        mobileCachePaths: const [],
      )
      ..results = [
        ScanResult(
          category: getCategory('trash')!,
          paths: [PathSize(path: temp.path, sizeBytes: 2048, exists: true)],
          totalSizeBytes: 1024 * 1024,
          applicable: true,
          detected: true,
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScanScreen(
            controller: controller,
            onClean: () {},
            onCleanItems: (id, paths) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final info = find.byTooltip('Details for Trash');
    await tester.ensureVisible(info);
    await tester.pumpAndSettle();
    await tester.tap(info);
    await tester.pumpAndSettle();

    expect(find.text('a.dat'), findsOneWidget);
    expect(find.text('b.dat'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Select all'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 selected'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });
}