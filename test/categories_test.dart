import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:purge/engine/categories.dart';
import 'package:purge/engine/types.dart';

const mac = HostEnv(
  platform: AppPlatform.macos,
  home: '/Users/test',
  localAppData: '/Users/test/Library/Application Support',
  tempDir: '/tmp',
  cargoHome: '/Users/test/.cargo',
  mobileCachePaths: [],
);

void main() {
  group('large files', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('purge_large_files_');
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    HostEnv home() => HostEnv(
          platform: AppPlatform.macos,
          home: temp.path,
          localAppData: '${temp.path}/Library/Application Support',
          tempDir: '${temp.path}/tmp',
          cargoHome: '${temp.path}/.cargo',
          mobileCachePaths: const [],
        );

    void sparse(String relative, [int bytes = 120 * 1024 * 1024]) {
      final file = File('${temp.path}/$relative');
      file.parent.createSync(recursive: true);
      final raf = file.openSync(mode: FileMode.write);
      raf.truncateSync(bytes);
      raf.closeSync();
    }

    void small(String relative) {
      final file = File('${temp.path}/$relative');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('small');
    }

    test('finds large files and skips small ones, caches and hidden dirs', () async {
      sparse('big.bin');
      small('small.txt');
      sparse('node_modules/pkg/ignored.bin');
      sparse('.hidden/ignored.bin');
      sparse('Library/ignored.bin');

      final paths = await getCategory('large-files')!.getPaths(home());
      expect(paths, [p.join(temp.path, 'big.bin')]);
    });

    test('ranks largest files first', () async {
      sparse('smaller.bin', 110 * 1024 * 1024);
      sparse('bigger.bin', 300 * 1024 * 1024);
      final paths = await getCategory('large-files')!.getPaths(home());
      expect(paths, hasLength(2));
      expect(paths.first, p.join(temp.path, 'bigger.bin'));
      expect(paths.last, p.join(temp.path, 'smaller.bin'));
    });

    test('clean commands delete every large file', () async {
      sparse('a.bin');
      sparse('b.bin');
      final cmds = getCategory('large-files')!.cleanCommands(home());
      expect(cmds.single.command, 'rm');
      expect(cmds.single.args, hasLength(2));
      expect(cmds.single.label, 'delete 2 large files');
    });

    test('is a desktop-only advanced category', () async {
      final cat = getCategory('large-files')!;
      expect(cat.safety, SafetyTier.advanced);
      for (final platform in [AppPlatform.android, AppPlatform.ios]) {
        expect(cat.platforms, isNot(contains(platform)));
      }
      final empty = HostEnv(
        platform: AppPlatform.macos,
        home: temp.path,
        localAppData: '${temp.path}/Library/Application Support',
        tempDir: '${temp.path}/tmp',
        cargoHome: '${temp.path}/.cargo',
        mobileCachePaths: const [],
      );
      expect(await cat.getPaths(empty), isEmpty);
    });
  });

  test('homebrew deletes the cache folder last so nothing is recreated', () {
    final cmds = getCategory('homebrew-cache')!.cleanCommands(mac);
    final last = cmds.last;
    expect(last.command, 'rm');
    expect(last.args.where((a) => !a.startsWith('-')), ['/Users/test/Library/Caches/Homebrew']);
    expect(cmds.any((c) => c.command == 'brew' && c.args.contains('cleanup')), isTrue);
    expect(cmds.last.command, isNot('brew'));
  });

  test('npm removes the whole cache folder including npx temp installs', () {
    final cmds = getCategory('npm-cache')!.cleanCommands(mac);
    final last = cmds.last;
    expect(last.command, 'rm');
    expect(last.args.where((a) => !a.startsWith('-')), ['/Users/test/.npm']);
    expect(cmds.length, 2);
  });

  test('clean commands run in a safe order for every tool cache', () {
    for (final id in ['npm-cache', 'homebrew-cache', 'pnpm-cache', 'yarn-cache', 'pip-cache']) {
      final cmds = getCategory(id)!.cleanCommands(mac);
      expect(cmds, isNotEmpty, reason: '$id should emit clean commands');
      final rms = cmds.where((c) => c.command == 'rm').toList();
      if (rms.isNotEmpty) {
        expect(cmds.last.command, 'rm',
            reason: '$id must finish by deleting the cache folder, otherwise the tool '
                'recreates it before measuring');
        for (final c in rms) {
          final target = c.args.lastWhere((a) => !a.startsWith('-'));
          expect(target.length, greaterThan(10), reason: '$id rm target $target looks unsafe');
        }
      }
    }
  });

  group('user-app-caches', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('purge_app_caches_');
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    HostEnv home(AppPlatform platform, {String cacheSub = 'Library/Caches'}) => HostEnv(
          platform: platform,
          home: temp.path,
          localAppData: '${temp.path}/AppData/Local',
          tempDir: '${temp.path}/tmp',
          cargoHome: '${temp.path}/.cargo',
          mobileCachePaths: const [],
        );

    test('macOS lists one card per app cache and skips dev caches and Purge', () async {
      Directory('${temp.path}/Library/Caches').createSync(recursive: true);
      for (final name in ['com.apple.Safari', 'com.google.Chrome', 'com.spotify.client']) {
        Directory('${temp.path}/Library/Caches/$name').createSync(recursive: true);
      }
      for (final dev in ['CocoaPods', 'yarn', 'pip', 'go-build', 'Homebrew', 'com.apple.dt.Xcode', 'com.apple.helpd', 'com.google.SoftwareUpdateAgent', 'org.carthage.CarthageKit']) {
        Directory('${temp.path}/Library/Caches/$dev').createSync(recursive: true);
      }
      Directory('${temp.path}/Library/Caches/dev.purge.purge').createSync(recursive: true);

      final paths = await getCategory('user-app-caches')!.getPaths(home(AppPlatform.macos));
      final names = paths.map((path) => p.basename(path)).toSet();
      expect(names, containsAll(['com.apple.Safari', 'com.google.Chrome', 'com.spotify.client']));
      for (final skipped in ['CocoaPods', 'yarn', 'pip', 'go-build', 'Homebrew', 'com.apple.dt.Xcode', 'com.apple.helpd', 'com.google.SoftwareUpdateAgent', 'org.carthage.CarthageKit', 'dev.purge.purge']) {
        expect(names, isNot(contains(skipped)));
      }
    });

    test('Linux lists ~/.cache apps and skips dev cache names', () async {
      Directory('${temp.path}/.cache').createSync(recursive: true);
      for (final name in ['brave', 'gimp', 'vlc', 'homebrew', 'pnpm', 'yarn', 'pip', 'go-build', '.hidden']) {
        Directory('${temp.path}/.cache/$name').createSync(recursive: true);
      }

      final paths = await getCategory('user-app-caches')!.getPaths(home(AppPlatform.linux, cacheSub: '.cache'));
      final names = paths.map((path) => p.basename(path)).toSet();
      expect(names, containsAll(['brave', 'gimp', 'vlc']));
      for (final skipped in ['homebrew', 'pnpm', 'yarn', 'pip', 'go-build', '.hidden']) {
        expect(names, isNot(contains(skipped)));
      }
    });

    test('Windows collects cache-named folders under %LOCALAPPDATA% only', () async {
      final base = '${temp.path}/AppData/Local';
      Directory('$base/Google/Chrome/User Data/Default/Cache').createSync(recursive: true);
      Directory('$base/Google/Chrome/User Data/Default/Code Cache').createSync(recursive: true);
      Directory('$base/Slack/Cache').createSync(recursive: true);
      Directory('$base/GoLang/GoLand/options').createSync(recursive: true);
      Directory('$base/pip/Cache').createSync(recursive: true);
      Directory('$base/Yarn/Cache').createSync(recursive: true);
      Directory('$base/npm-cache').createSync(recursive: true);
      Directory('$base/Notes/not-a-cache').createSync(recursive: true);

      final paths = await getCategory('user-app-caches')!.getPaths(home(AppPlatform.windows));
      final names = paths.map((path) => path.replaceFirst(base, '').replaceAll(r'\', '/')).toSet();
      expect(names, containsAll([
        '/Google/Chrome/User Data/Default/Cache',
        '/Google/Chrome/User Data/Default/Code Cache',
        '/Slack/Cache',
      ]));
      for (final skipped in ['/pip/Cache', '/Yarn/Cache', '/npm-cache', '/Notes/not-a-cache']) {
        expect(names, isNot(contains(skipped)));
      }
    });

    test('is a desktop-only safe, per-path category', () {
      final cat = getCategory('user-app-caches')!;
      expect(cat.safety, SafetyTier.safe);
      expect(cat.perPath, isTrue);
      for (final platform in [AppPlatform.android, AppPlatform.ios]) {
        expect(cat.platforms, isNot(contains(platform)));
      }
    });
  });
}