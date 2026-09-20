import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:purge/engine/cleaner.dart';
import 'package:purge/engine/types.dart';

void main() {
  group('runCleanJob progress', () {
    late Directory temp;
    late HostEnv env;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('purge_cleaner_');
      env = HostEnv(
        platform: AppPlatform.macos,
        home: temp.path,
        localAppData: '${temp.path}/Library/Application Support',
        tempDir: '${temp.path}/tmp',
        cargoHome: '${temp.path}/.cargo',
        mobileCachePaths: const [],
      );
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('reports per-path progress and ends at the total', () async {
      final paths = [for (var i = 0; i < 5; i++) '${temp.path}/f$i.bin'];
      for (final path in paths) {
        File(path).writeAsBytesSync(List<int>.filled(10, 0));
      }

      final category = CategoryDefinition(
        id: 'items',
        name: 'items',
        description: '',
        safety: SafetyTier.moderate,
        tradeoff: '',
        platforms: const [AppPlatform.macos],
        getPaths: (_) async => paths,
        cleanCommands: (_) => [
              CleanCommand(command: 'rm', args: paths, label: 'delete items'),
            ],
      );

      final seen = <CleanProgressEvent>[];
      await runCleanJob(
        categories: [category],
        env: env,
        onProgress: seen.add,
        isCancelled: () => false,
      );

      expect(seen, isNotEmpty);
      expect(seen.every((e) => e.total == 5), isTrue);

      final done = seen.where((e) => e.status == 'done').toList();
      expect(done, hasLength(1));
      expect(done.first.done, 5);

      final cleaningDones =
          seen.where((e) => e.status == 'cleaning').map((e) => e.done!).toList();
      expect(cleaningDones.length, greaterThanOrEqualTo(6));
      expect(cleaningDones.last, 5);
      expect(cleaningDones.toSet().length, greaterThan(1),
          reason: 'progress should move gradually, not jump to 100');

      for (final path in paths) {
        expect(File(path).existsSync(), isFalse);
      }
    });

    test('age filter removes only files older than the cutoff', () async {
      final oldPath = '${temp.path}/old.bin';
      final recentPath = '${temp.path}/recent.bin';
      File(oldPath).writeAsBytesSync(List<int>.filled(10, 0));
      File(recentPath).writeAsBytesSync(List<int>.filled(10, 0));
      File(oldPath)
          .setLastModifiedSync(DateTime.now().subtract(const Duration(days: 10)));

      final category = CategoryDefinition(
        id: 'old-items',
        name: 'old items',
        description: '',
        safety: SafetyTier.safe,
        tradeoff: '',
        platforms: const [AppPlatform.macos],
        getPaths: (_) async => [oldPath, recentPath],
        cleanCommands: (_) => [
          CleanCommand(command: 'rm', args: [oldPath, recentPath], label: 'delete items'),
        ],
      );

      final seen = <CleanProgressEvent>[];
      await runCleanJob(
        categories: [category],
        env: env,
        minAge: const Duration(days: 7),
        onProgress: seen.add,
        isCancelled: () => false,
      );

      expect(File(oldPath).existsSync(), isFalse,
          reason: 'old file should be removed');
      expect(File(recentPath).existsSync(), isTrue,
          reason: 'recent file should be kept');

      final done = seen.where((e) => e.status == 'done').toList();
      expect(done, hasLength(1));
      expect(done.first.done, 1, reason: 'only the old file counts as a unit');
      expect(done.first.total, 1);
    });

    test('age filter skips a category when everything is too recent',
        () async {
      final recentPath = '${temp.path}/recent.bin';
      File(recentPath).writeAsBytesSync(List<int>.filled(10, 0));

      final category = CategoryDefinition(
        id: 'fresh-items',
        name: 'fresh items',
        description: '',
        safety: SafetyTier.safe,
        tradeoff: '',
        platforms: const [AppPlatform.macos],
        getPaths: (_) async => [recentPath],
        cleanCommands: (_) => [
          CleanCommand(command: 'rm', args: [recentPath], label: 'delete items'),
        ],
      );

      final seen = <CleanProgressEvent>[];
      await runCleanJob(
        categories: [category],
        env: env,
        minAge: const Duration(days: 7),
        onProgress: seen.add,
        isCancelled: () => false,
      );

      expect(File(recentPath).existsSync(), isTrue,
          reason: 'recent file must not be deleted');
      expect(
        seen.any((e) =>
            e.status == 'skipped' &&
            e.label == CleanerStrings.recentlyUsedSkipped),
        isTrue,
        reason: 'category should be skipped with the age-filter message',
      );
      expect(seen.where((e) => e.status == 'done'), isEmpty);
    });
  });

  group('blocklist exclusions', () {
    late Directory temp;
    late HostEnv env;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('purge_excl_');
      env = HostEnv(
        platform: AppPlatform.macos,
        home: temp.path,
        localAppData: '${temp.path}/Library/Application Support',
        tempDir: '${temp.path}/tmp',
        cargoHome: '${temp.path}/.cargo',
        mobileCachePaths: const [],
      );
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('keeps files outside the blocklist', () async {
      final keepPath = '${temp.path}/keep.bin';
      final blockedPath = '${temp.path}/blocked.bin';
      File(keepPath).writeAsBytesSync(List<int>.filled(10, 0));
      File(blockedPath).writeAsBytesSync(List<int>.filled(10, 0));

      final category = CategoryDefinition(
        id: 'mixed',
        name: 'mixed',
        description: '',
        safety: SafetyTier.safe,
        tradeoff: '',
        platforms: const [AppPlatform.macos],
        getPaths: (_) async => [keepPath, blockedPath],
        cleanCommands: (_) => [
          CleanCommand(command: 'rm', args: [keepPath, blockedPath], label: 'delete'),
        ],
      );

      final seen = <CleanProgressEvent>[];
      await runCleanJob(
        categories: [category],
        env: env,
        excludedPaths: [blockedPath],
        onProgress: seen.add,
        isCancelled: () => false,
      );

      expect(File(blockedPath).existsSync(), isTrue,
          reason: 'blocked file must not be deleted');
      expect(File(keepPath).existsSync(), isFalse);
      expect(seen.where((e) => e.status == 'done'), hasLength(1));
    });

    test('skips a category when every target is blocked', () async {
      final blockedPath = '${temp.path}/blocked.bin';
      File(blockedPath).writeAsBytesSync(List<int>.filled(10, 0));

      final category = CategoryDefinition(
        id: 'fully-blocked',
        name: 'fully blocked',
        description: '',
        safety: SafetyTier.safe,
        tradeoff: '',
        platforms: const [AppPlatform.macos],
        getPaths: (_) async => [blockedPath],
        cleanCommands: (_) => [
          CleanCommand(command: 'rm', args: [blockedPath], label: 'delete'),
        ],
      );

      final seen = <CleanProgressEvent>[];
      await runCleanJob(
        categories: [category],
        env: env,
        excludedPaths: [blockedPath],
        onProgress: seen.add,
        isCancelled: () => false,
      );

      expect(File(blockedPath).existsSync(), isTrue);
      expect(
        seen.any((e) =>
            e.status == 'skipped' &&
            e.label == CleanerStrings.excludedSkipped),
        isTrue,
        reason: 'blocked category is skipped with the blocklist message',
      );
      expect(seen.where((e) => e.status == 'done'), isEmpty);
    });

    test('nested blocklist target also protects deeper files', () async {
      Directory('${temp.path}/cache').createSync();
      final nested = '${temp.path}/cache/deep.bin';
      File(nested).writeAsBytesSync(List<int>.filled(10, 0));

      final category = CategoryDefinition(
        id: 'nested',
        name: 'nested',
        description: '',
        safety: SafetyTier.safe,
        tradeoff: '',
        platforms: const [AppPlatform.macos],
        getPaths: (_) async => [nested],
        cleanCommands: (_) => [
          CleanCommand(command: 'rm', args: [nested], label: 'delete'),
        ],
      );

      final seen = <CleanProgressEvent>[];
      await runCleanJob(
        categories: [category],
        env: env,
        excludedPaths: ['${temp.path}/cache'],
        onProgress: seen.add,
        isCancelled: () => false,
      );

      expect(File(nested).existsSync(), isTrue);
      expect(seen.where((e) => e.status == 'done'), isEmpty);
    });
  });
}