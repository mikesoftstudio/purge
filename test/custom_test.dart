import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:purge/engine/custom.dart';
import 'package:purge/engine/types.dart';

void main() {
  group('customFoldersCategory', () {
    test('is a per-path caches category on desktop only', () {
      final def = customFoldersCategory(['/tmp/a']);

      expect(def.id, 'custom-folders');
      expect(def.perPath, isTrue);
      expect(def.kind, CategoryKind.caches);
      expect(def.safety, SafetyTier.moderate);
      expect(
        def.platforms,
        containsAll(
            [AppPlatform.macos, AppPlatform.linux, AppPlatform.windows]),
      );
      expect(def.platforms, isNot(contains(AppPlatform.android)));
      expect(def.platforms, isNot(contains(AppPlatform.ios)));
    });

    test('returns the configured roots', () async {
      final def = customFoldersCategory(['/tmp/a', '/tmp/b']);
      await expectLater(
        def.getPaths(HostEnv(
          platform: AppPlatform.macos,
          home: '/Users/test',
          localAppData: '',
          tempDir: '',
          cargoHome: '',
          mobileCachePaths: const [],
        )),
        completion(equals(['/tmp/a', '/tmp/b'])),
      );
    });

    test('clean commands clear contents via a glob through a shell', () {
      final def = customFoldersCategory(['/tmp/a']);
      final cmd = def.cleanCommands(HostEnv(
        platform: AppPlatform.macos,
        home: '/Users/test',
        localAppData: '',
        tempDir: '',
        cargoHome: '',
        mobileCachePaths: const [],
      ));

      expect(cmd, hasLength(1));
      expect(cmd.first.command, 'rm');
      expect(cmd.first.shell, isTrue);
      final label = cmd.first.label!;
      expect(label.toLowerCase(), contains('a'));
    });
  });

  group('normalizeCustomPath', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('purge_custom_path_');
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('accepts an existing folder', () {
      expect(normalizeCustomPath(temp.path), temp.path);
    });

    test('rejects a folder that does not exist', () {
      expect(normalizeCustomPath('${temp.path}/does-not-exist'), isNull);
    });

    test('trims whitespace', () {
      expect(normalizeCustomPath('  ${temp.path}  '), temp.path);
    });

    test('rejects empty input', () {
      expect(normalizeCustomPath(''), isNull);
      expect(normalizeCustomPath('   '), isNull);
    });
  });
}