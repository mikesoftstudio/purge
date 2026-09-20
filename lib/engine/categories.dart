import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'bytes.dart';
import 'disk.dart';
import 'host.dart';
import 'platform.dart';
import 'types.dart';
import '../log.dart';

const _allDesktop = [
  AppPlatform.macos,
  AppPlatform.linux,
  AppPlatform.windows,
];

List<CategoryDefinition> allCategories() => [
      trashCategory,
      systemCategory,
      appCachesCategory,
      userAppCachesCategory,
      homebrewCategory,
      npmCategory,
      pnpmCategory,
      yarnCategory,
      pipCategory,
      cocoapodsCategory,
      flutterCategory,
      flutterSdkCacheCategory,
      xcodeDerivedDataCategory,
      xcodeDeviceSupportCategory,
      xcodeSimulatorCachesCategory,
      iosSimulatorsCategory,
      gradleCachesCategory,
      gradleWrapperDistsCategory,
      dockerCategory,
      goCategory,
      cargoCategory,
      dotnetCategory,
      chocolateyCategory,
      scoopCategory,
      largeFilesCategory,
    ];

List<CategoryDefinition> categoriesForPlatform(AppPlatform platform) =>
    allCategories().where((c) => c.platforms.contains(platform)).toList();

CategoryDefinition? getCategory(String id) {
  for (final c in allCategories()) {
    if (c.id == id) return c;
  }
  return null;
}

final trashCategory = CategoryDefinition(
  id: 'trash',
  name: 'Trash',
  description: 'Files you have moved to Trash / Recycle Bin.',
  safety: SafetyTier.safe,
  tradeoff: 'Items in the Trash are permanently deleted and cannot be restored.',
  platforms: _allDesktop,
  getPaths: (env) async {
    if (env.isWindows) return const [];
    if (env.isMacos) {
      return [homePath(env, ['.Trash']), homePath(env, ['.local', 'share', 'Trash'])];
    }
    return [homePath(env, ['.local', 'share', 'Trash'])];
  },
  getSizeBytes: (env) async {
    if (env.isWindows) return _recycleBinBytes();
    if (env.isMacos) return _macTrashBytes();
    throw StateError('path sizing');
  },
  cleanCommands: (env) {
    if (env.isWindows) {
      return const [
        CleanCommand(
          command: 'Clear-RecycleBin',
          args: ['-Force'],
          shell: true,
          label: 'Clear-RecycleBin -Force',
        ),
      ];
    }
    if (env.isMacos) {
      return [
        CleanCommand(
          command: 'rm',
          args: ['-rf', homePath(env, ['.Trash'])],
          shell: true,
          label: 'empty Trash',
        ),
        CleanCommand(
          command: 'rm',
          args: ['-rf', homePath(env, ['.local', 'share', 'Trash'])],
          shell: true,
          label: 'empty XDG Trash',
        ),
      ];
    }
    return [
      CleanCommand(
        command: 'rm',
        args: ['-rf', homePath(env, ['.local', 'share', 'Trash'])],
        shell: true,
        label: 'empty Trash',
      ),
    ];
  },
  onFailureCommands: (env) {
    if (!env.isMacos) return const [];
    return const [
      CleanCommand(
        command: 'osascript',
        args: ['-e', 'tell application "Finder" to empty trash'],
        label: 'empty Trash via Finder',
      ),
    ];
  },
);

final systemCategory = CategoryDefinition(
  id: 'system-caches',
  name: 'System Caches & Logs',
  description: 'Assorted removable application caches in your home directory.',
  safety: SafetyTier.safe,
  tradeoff: 'Apps rebuild caches automatically as you use them.',
  platforms: const [AppPlatform.macos, AppPlatform.linux, AppPlatform.android],
  getPaths: (env) async => _existing(_systemPaths(env)),
  cleanCommands: (env) => _existing(_systemPaths(env))
      .map(
        (path) => CleanCommand(
          command: 'rm',
          args: ['-rf', path],
          shell: true,
          label: 'remove ${p.basename(path)}',
        ),
      )
      .toList(),
);

final appCachesCategory = CategoryDefinition(
  id: 'app-caches',
  name: 'App Caches',
  description: 'Temporary files and caches apps can safely rebuild.',
  safety: SafetyTier.safe,
  tradeoff: 'Apps rebuild these caches the next time you use them.',
  platforms: const [AppPlatform.android, AppPlatform.ios],
  getPaths: (env) async {
    if (env.platform == AppPlatform.android) {
      final targets = await _resolveAndroidAppCacheTargets();
      purgeLog('scan', 'App Caches: ${targets.length} cache locations');
      return targets;
    }
    return env.mobileCachePaths;
  },
  cleanCommands: (env) {
    final targets = env.platform == AppPlatform.android
        ? (_androidAppCacheTargets ?? const <String>[])
        : env.mobileCachePaths;
    return targets
        .map(
          (path) => CleanCommand(
            command: 'rm',
            args: ['-rf', path],
            label: 'remove ${p.basename(p.dirname(path))} cache',
          ),
        )
        .toList();
  },
  skipReason: (env) async {
    if (env.platform != AppPlatform.android) return null;
    if (!Platform.isAndroid) return null;
    final granted = await isStorageAccessGranted();
    if (granted) return null;
    return 'Grant "Files & media" (all files access) in Settings to clean app caches';
  },
);

final userAppCachesCategory = CategoryDefinition(
  id: 'user-app-caches',
  name: 'App Caches',
  description:
      'Caches kept by everyday apps — browsers, chat, editors and media tools — '
      'in your system cache folder. One card per app.',
  safety: SafetyTier.safe,
  tradeoff: 'Each app rebuilds its cache the next time you use it.',
  platforms: _allDesktop,
  kind: CategoryKind.caches,
  perPath: true,
  getPaths: (env) async => _discoverUserAppCaches(env),
  cleanCommands: (_) => const [],
);

/// Cache-folder names already owned by dedicated developer categories on macOS
/// (`~/Library/Caches/*` or its children), so they are not double-counted here.
const _macDevCacheNames = {
  'cocoapods',
  'yarn',
  'pip',
  'go-build',
  'homebrew',
  'com.apple.dt.xcode',
  'com.google.softwareupdateagent',
  'com.apple.helpd',
  'org.carthage.carthagekit',
};

/// Cache-folder names already owned by dedicated developer categories on Linux
/// (`~/.cache/*`).
const _linuxDevCacheNames = {
  'homebrew',
  'pnpm',
  'yarn',
  'pip',
  'go-build',
};

/// On Windows the per-app caches are nested `Cache`-style folders under
/// `%LOCALAPPDATA%`. These names are either dev caches we already cover or are
/// not safe to treat as app caches, so they are skipped while walking.
const _windowsSkipNames = {
  'pip',
  'yarn',
  'go-build',
  'pub',
  'npm-cache',
  'pnpm',
  'temp',
  'purge',
};

/// Recognised Windows app-cache folder names (mostly from Chromium,
/// Electron/CEF and Unity apps). Only an exact match is deleted — a folder
/// like `not-a-cache` is never touched.
bool _isWindowsCacheName(String lower) {
  if (lower == 'cache' ||
      lower.startsWith('cache_') ||
      lower.startsWith('cachedata') ||
      lower.startsWith('cachestorage')) {
    return true;
  }
  return const {
    'gpucache',
    'grshadercache',
    'shadercache',
    'code cache',
    'webcache',
    'web cache',
    'cefcache',
    'dawncache',
    'dawn gpcache',
    'jitcache',
  }.contains(lower);
}

/// Enumerates per-app cache folders for everyday (non-developer) apps.
Future<List<String>> _discoverUserAppCaches(HostEnv env) async {
  switch (env.platform) {
    case AppPlatform.macos:
      return _listCacheDirs(homePath(env, ['Library', 'Caches']),
          skip: _macDevCacheNames);
    case AppPlatform.linux:
      return _listCacheDirs(homePath(env, ['.cache']),
          skip: _linuxDevCacheNames);
    case AppPlatform.windows:
      return _windowsCacheDirs(env);
    default:
      return const [];
  }
}

/// Returns the immediate per-app cache folders inside [root], excluding hidden
/// entries, Purge's own cache and the developer cache names in [skip].
List<String> _listCacheDirs(String root, {required Set<String> skip}) {
  try {
    final dir = Directory(root);
    if (!dir.existsSync()) return const [];
    final out = <String>[];
    for (final e in dir.listSync(followLinks: false)) {
      final name = p.basename(e.path);
      final lower = name.toLowerCase();
      if (name.startsWith('.')) continue;
      if (lower.startsWith('dev.purge') || lower == 'purge') continue;
      if (skip.contains(lower)) continue;
      try {
        final type = FileSystemEntity.typeSync(e.path, followLinks: false);
        if (type != FileSystemEntityType.directory) continue;
      } catch (_) {
        continue;
      }
      out.add(e.path);
    }
    out.sort();
    return out;
  } catch (_) {
    return const [];
  }
}

/// Walks `%LOCALAPPDATA%` to a bounded depth and collects folders whose name
/// looks like a cache (`Cache`, `CachedData`, `GPUCache`, `Code Cache`, …).
/// Only literally cache-named folders are ever returned, never app-data.
List<String> _windowsCacheDirs(HostEnv env) {
  final root = env.localAppData;
  if (root.isEmpty) return const [];
  const maxDepth = 6;
  const maxFound = 80;
  const maxCrawled = 5000;
  final found = <String>[];
  final stack = <(String path, int depth)>[(root, 0)];
  var crawled = 0;
  while (stack.isNotEmpty && found.length < maxFound && crawled < maxCrawled) {
    final (path, depth) = stack.removeLast();
    crawled++;
    final List<FileSystemEntity> children;
    try {
      children = Directory(path).listSync(followLinks: false);
    } catch (_) {
      continue;
    }
    for (final child in children) {
      final name = p.basename(child.path);
      final lower = name.toLowerCase();
      if (lower.startsWith('dev.purge') || lower == 'purge') continue;
      if (_windowsSkipNames.contains(lower)) continue;
      final isDir = FileSystemEntity.typeSync(child.path, followLinks: false) ==
          FileSystemEntityType.directory;
      if (!isDir) continue;
      if (depth >= 1 && _isWindowsCacheName(lower)) {
        found.add(child.path);
        continue;
      }
      if (depth < maxDepth) stack.add((child.path, depth + 1));
    }
  }
  found.sort();
  return found;
}

List<String>? _androidAppCacheTargets;

Future<List<String>> _resolveAndroidAppCacheTargets() async {
  List<String> targets = const [];
  if (Platform.isAndroid) {
    final info = await listExternalCacheDirs();
    final raw = (info['dirs'] as List?)?.cast<String>() ?? const <String>[];
    final pkgCount = (info['packages'] as num?)?.toInt();
    if (info.isNotEmpty) {
      targets = raw.where((path) => _isCacheDir(path)).toList();
      purgeLog(
        'scan',
        'App Caches enumeration: native=ok packages=$pkgCount rawDirs=${raw.length}',
      );
    } else {
      purgeLog(
        'scan',
        'App Caches enumeration: native=unavailable (stale build? rebuild with flutter)',
      );
    }
  }
  if (targets.isEmpty) {
    final scanned = _discoverAndroidAppCacheTargets();
    if (scanned.isNotEmpty) {
      targets = scanned;
      purgeLog('scan', 'App Caches enumeration: fallback dir scan found ${scanned.length}');
    }
  }
  _androidAppCacheTargets = targets;
  return targets;
}

bool _isCacheDir(String path) {
  try {
    return FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.directory;
  } catch (_) {
    return false;
  }
}

List<String> _discoverAndroidAppCacheTargets() {
  const dataRoot = '/storage/emulated/0/Android/data';
  try {
    final root = Directory(dataRoot);
    if (!root.existsSync()) return const [];
    final targets = <String>[];
    final pkgRe = RegExp(r'^[a-z][a-z0-9]*(\.[a-z0-9_]+)+$');
    for (final entry in root.listSync(followLinks: false)) {
      if (entry is! Directory) continue;
      final name = p.basename(entry.path);
      if (name.startsWith('.') || name == 'dev.purge.purge') continue;
      if (!pkgRe.hasMatch(name)) continue;
      final cache = p.join(entry.path, 'cache');
      try {
        if (FileSystemEntity.typeSync(cache, followLinks: false) ==
            FileSystemEntityType.directory) {
          targets.add(cache);
        }
      } catch (_) {}
    }
    targets.sort();
    return targets;
  } catch (_) {
    return const [];
  }
}

final homebrewCategory = CategoryDefinition(
  id: 'homebrew-cache',
  name: 'Homebrew',
  description: 'Downloaded bottle cache, old versions and the API/bootsnap caches.',
  safety: SafetyTier.safe,
  tradeoff: 'The next brew install re-downloads bottles; brew cleanup keeps current installs.',
  platforms: const [AppPlatform.macos, AppPlatform.linux],
  toolRequirement: 'brew',
  getPaths: (env) async => [_brewCache(env)],
  cleanCommands: (env) => [
    const CleanCommand(
      command: 'brew',
      args: ['cleanup', '--prune=all'],
      label: 'brew cleanup --prune=all',
    ),
    CleanCommand(
      command: 'rm',
      args: ['-rf', _brewCache(env)],
      label: 'remove brew cache folder',
    ),
  ],
);

final npmCategory = CategoryDefinition(
  id: 'npm-cache',
  name: 'npm Cache',
  description: 'Downloaded package tarballs, registry metadata and npx temp installs.',
  safety: SafetyTier.safe,
  tradeoff: 'The next npm install or npx run in each project re-downloads packages.',
  platforms: _allDesktop,
  toolRequirement: 'npm',
  getPaths: (env) async => [_npmPath(env)],
  cleanCommands: (env) => [
    const CleanCommand(
      command: 'npm',
      args: ['cache', 'clean', '--force'],
      label: 'npm cache clean --force',
    ),
    CleanCommand(
      command: 'rm',
      args: ['-rf', _npmPath(env)],
      label: 'remove npm cache folder',
    ),
  ],
);

final pnpmCategory = CategoryDefinition(
  id: 'pnpm-cache',
  name: 'pnpm Store',
  description: 'Cached package store and metadata used by pnpm.',
  safety: SafetyTier.safe,
  tradeoff: 'Packages are re-downloaded on the next pnpm install.',
  platforms: _allDesktop,
  toolRequirement: 'pnpm',
  getPaths: (env) async => [_pnpmPath(env)],
  cleanCommands: (env) => [
    const CleanCommand(
      command: 'pnpm',
      args: ['store', 'prune'],
      label: 'pnpm store prune',
    ),
    CleanCommand(
      command: 'rm',
      args: ['-rf', _pnpmPath(env)],
      label: 'remove pnpm cache dir',
    ),
  ],
);

final yarnCategory = CategoryDefinition(
  id: 'yarn-cache',
  name: 'Yarn Cache',
  description: 'Cached packages used by yarn install.',
  safety: SafetyTier.safe,
  tradeoff: 'Packages are re-downloaded on the next yarn install.',
  platforms: _allDesktop,
  toolRequirement: 'yarn',
  getPaths: (env) async => [_yarnPath(env)],
  cleanCommands: (_) => const [
    CleanCommand(
      command: 'yarn',
      args: ['cache', 'clean'],
      label: 'yarn cache clean',
    ),
  ],
);

final pipCategory = CategoryDefinition(
  id: 'pip-cache',
  name: 'pip Cache',
  description: 'Cached Python package wheels used by pip install.',
  safety: SafetyTier.safe,
  tradeoff: 'Python packages are re-downloaded on the next pip install.',
  platforms: _allDesktop,
  toolRequirement: Platform.isWindows ? 'pip' : 'pip3',
  getPaths: (env) async => [_pipPath(env)],
  cleanCommands: (env) {
    if (Platform.isWindows) {
      return const [
        CleanCommand(
          command: 'pip',
          args: ['cache', 'purge'],
          label: 'pip cache purge',
        ),
      ];
    }
    return [
      CleanCommand(
        command: 'rm',
        args: ['-rf', _pipPath(env)],
        shell: true,
        label: 'remove pip cache',
      ),
    ];
  },
);

final cocoapodsCategory = CategoryDefinition(
  id: 'cocoapods-cache',
  name: 'CocoaPods Cache',
  description: 'Downloaded CocoaPods spec and pod archives.',
  safety: SafetyTier.safe,
  tradeoff: 'Pods are re-downloaded on the next pod install.',
  platforms: const [AppPlatform.macos],
  toolRequirement: 'pod',
  getPaths: (env) async => [homePath(env, ['Library', 'Caches', 'CocoaPods'])],
  cleanCommands: (env) => [
    CleanCommand(
      command: 'rm',
      args: ['-rf', homePath(env, ['Library', 'Caches', 'CocoaPods'])],
      label: 'remove CocoaPods cache',
    ),
  ],
);

final flutterCategory = CategoryDefinition(
  id: 'flutter-pub-cache',
  name: 'Dart / Flutter Pub Cache',
  description: 'Downloaded Dart packages used by pub get.',
  safety: SafetyTier.safe,
  tradeoff: 'Packages are re-downloaded on the next pub get / flutter run.',
  platforms: _allDesktop,
  toolRequirement: 'flutter',
  getPaths: (env) async => [_pubCachePath(env)],
  cleanCommands: (env) => [
    CleanCommand(
      command: 'rm',
      args: ['-rf', _pubCachePath(env)],
      label: 'remove pub cache',
    ),
  ],
);

final flutterSdkCacheCategory = CategoryDefinition(
  id: 'flutter-sdk-cache',
  name: 'Flutter Engine Cache',
  description: 'Pre-built Flutter engine artifacts inside the SDK.',
  safety: SafetyTier.moderate,
  tradeoff: 'The next flutter command re-downloads ~1–2 GB of engine artifacts.',
  platforms: _allDesktop,
  toolRequirement: 'flutter',
  getPaths: (env) async {
    final path = await _flutterSdkCachePath();
    return path == null ? const <String>[] : [path];
  },
  cleanCommands: (env) {
    final path = _cachedFlutterSdkCache;
    if (path == null || path.isEmpty) return const [];
    return [
      CleanCommand(
        command: 'rm',
        args: ['-rf', path],
        label: 'remove Flutter engine cache',
      ),
    ];
  },
);

final xcodeDerivedDataCategory = CategoryDefinition(
  id: 'xcode-deriveddata',
  name: 'Xcode DerivedData',
  description: 'Build products, indexes and logs created by Xcode for every project you open.',
  safety: SafetyTier.safe,
  tradeoff: 'Your first build after cleaning will be slower while Xcode regenerates everything.',
  platforms: const [AppPlatform.macos],
  toolRequirement: 'xcodebuild',
  getPaths: (env) async => [
    homePath(env, ['Library', 'Developer', 'Xcode', 'DerivedData']),
    homePath(env, ['Library', 'Caches', 'com.apple.dt.Xcode']),
  ],
  cleanCommands: (env) => [
    CleanCommand(
      command: 'rm',
      args: ['-rf', homePath(env, ['Library', 'Developer', 'Xcode', 'DerivedData'])],
      shell: true,
      label: 'remove DerivedData',
    ),
    CleanCommand(
      command: 'rm',
      args: ['-rf', homePath(env, ['Library', 'Caches', 'com.apple.dt.Xcode'])],
      shell: true,
      label: 'remove Xcode app caches',
    ),
  ],
);

final xcodeDeviceSupportCategory = CategoryDefinition(
  id: 'xcode-devicesupport',
  name: 'Old iOS DeviceSupport',
  description: 'Debug symbols for past iOS versions on devices you have plugged in.',
  safety: SafetyTier.moderate,
  tradeoff: 'Debugging an old iOS device may need you to re-plug it once to rebuild symbols.',
  platforms: const [AppPlatform.macos],
  toolRequirement: 'xcodebuild',
  getPaths: (env) async => _oldDeviceSupportPaths(env),
  cleanCommands: (env) => _oldDeviceSupportPaths(env)
      .map(
        (path) => CleanCommand(
          command: 'rm',
          args: ['-rf', path],
          label: 'remove ${p.basename(path)}',
        ),
      )
      .toList(),
);

final xcodeSimulatorCachesCategory = CategoryDefinition(
  id: 'xcode-simulator-caches',
  name: 'Simulator Caches',
  description: 'iOS Simulator dyld and app caches.',
  safety: SafetyTier.safe,
  tradeoff: 'Simulators take slightly longer to launch once.',
  platforms: const [AppPlatform.macos],
  toolRequirement: 'xcrun',
  getPaths: (env) async => [
    homePath(env, ['Library', 'Developer', 'CoreSimulator', 'Caches']),
  ],
  cleanCommands: (env) => [
    CleanCommand(
      command: 'rm',
      args: [
        '-rf',
        homePath(env, ['Library', 'Developer', 'CoreSimulator', 'Caches']),
      ],
      label: 'remove CoreSimulator caches',
    ),
  ],
);

final iosSimulatorsCategory = CategoryDefinition(
  id: 'ios-simulators',
  name: 'Unused iOS Simulators',
  description: 'Simulator devices Xcode no longer uses but keeps on disk.',
  safety: SafetyTier.moderate,
  tradeoff: 'You may need to re-create a simulator if you switch iOS versions.',
  platforms: const [AppPlatform.macos],
  toolRequirement: 'xcrun',
  getPaths: (env) async => _unavailableSimulatorPaths(env),
  cleanCommands: (_) => const [
    CleanCommand(
      command: 'xcrun',
      args: ['simctl', 'delete', 'unavailable'],
      label: 'xcrun simctl delete unavailable',
    ),
  ],
);

final gradleCachesCategory = CategoryDefinition(
  id: 'gradle-build-caches',
  name: 'Gradle Build Caches',
  description: 'Compiled module and dependency caches shared across Android/JVM builds.',
  safety: SafetyTier.safe,
  tradeoff: 'The first build after cleaning is slower while dependencies reload.',
  platforms: _allDesktop,
  getPaths: (env) async => [_gradleCaches(env)],
  cleanCommands: (env) => [
    CleanCommand(
      command: 'rm',
      args: ['-rf', _gradleCaches(env)],
      label: 'remove Gradle caches',
    ),
  ],
);

final gradleWrapperDistsCategory = CategoryDefinition(
  id: 'gradle-wrapper-dists',
  name: 'Gradle Wrapper Downloads',
  description: 'Downloaded Gradle distributions used by ./gradlew.',
  safety: SafetyTier.safe,
  tradeoff: 'The next ./gradlew run re-downloads the bundled Gradle version.',
  platforms: _allDesktop,
  getPaths: (env) async => [_gradleWrapperDists(env)],
  cleanCommands: (env) => [
    CleanCommand(
      command: 'rm',
      args: ['-rf', _gradleWrapperDists(env)],
      label: 'remove Gradle wrapper dists',
    ),
  ],
);

final dockerCategory = CategoryDefinition(
  id: 'docker',
  name: 'Docker',
  description: 'Unused images, stopped containers, build cache and local volumes.',
  safety: SafetyTier.advanced,
  tradeoff: 'Containers and images are removed and must be re-pulled or rebuilt later.',
  platforms: _allDesktop,
  toolRequirement: 'docker',
  getPaths: (_) async => const [],
  getSizeBytes: (_) => _dockerReclaimableBytes(),
  cleanCommands: (_) => const [
    CleanCommand(
      command: 'docker',
      args: ['system', 'prune', '-af', '--volumes'],
      label: 'docker system prune -af --volumes',
    ),
  ],
  skipReason: (_) async {
    if (!canSpawnProcesses) return 'Docker is not available';
    try {
      final r = await Process.run('docker', ['info']);
      if (r.exitCode == 0) return null;
    } catch (_) {}
    return 'Docker daemon is not running';
  },
);

final goCategory = CategoryDefinition(
  id: 'go-build-cache',
  name: 'Go Build Cache',
  description: 'Compiled Go package artifacts and downloaded module sources.',
  safety: SafetyTier.safe,
  tradeoff: 'The first go build after cleaning is slower.',
  platforms: _allDesktop,
  toolRequirement: 'go',
  getPaths: (env) async => [_goBuildCache(env), _goModCache(env)],
  cleanCommands: (_) => const [
    CleanCommand(command: 'go', args: ['clean', '-cache'], label: 'go clean -cache'),
    CleanCommand(command: 'go', args: ['clean', '-modcache'], label: 'go clean -modcache'),
  ],
);

final cargoCategory = CategoryDefinition(
  id: 'cargo-registry-cache',
  name: 'Cargo Registry Cache',
  description: 'Downloaded crate archives used by cargo build.',
  safety: SafetyTier.safe,
  tradeoff: 'Crates are re-downloaded on the next cargo build.',
  platforms: _allDesktop,
  toolRequirement: 'cargo',
  getPaths: (env) async => [p.join(env.cargoHome, 'registry', 'cache')],
  cleanCommands: (env) => [
    CleanCommand(
      command: 'rm',
      args: ['-rf', p.join(env.cargoHome, 'registry', 'cache')],
      label: 'remove cargo registry cache',
    ),
  ],
);

final dotnetCategory = CategoryDefinition(
  id: 'dotnet-nuget',
  name: '.NET / NuGet',
  description: 'Downloaded NuGet packages and HTTP caches used by dotnet restore.',
  safety: SafetyTier.moderate,
  tradeoff: 'The next dotnet restore re-downloads packages, which can be slow.',
  platforms: _allDesktop,
  toolRequirement: 'dotnet',
  getPaths: (env) async => [
    homePath(env, ['.nuget', 'packages']),
    env.isWindows
        ? localPath(env, ['NuGet', 'v3-cache'])
        : homePath(env, ['.local', 'share', 'NuGet', 'v3-cache']),
    env.isWindows ? p.join(env.tempDir, 'NuGetScratch') : '/tmp/NuGetScratch',
  ],
  cleanCommands: (_) => const [
    CleanCommand(
      command: 'dotnet',
      args: ['nuget', 'locals', 'all', '--clear'],
      label: 'dotnet nuget locals all --clear',
    ),
  ],
);

final chocolateyCategory = CategoryDefinition(
  id: 'chocolatey-cache',
  name: 'Chocolatey Cache',
  description: 'HTTP download cache kept by Chocolatey package installs.',
  safety: SafetyTier.safe,
  tradeoff: 'Packages are re-downloaded on the next choco install.',
  platforms: const [AppPlatform.windows],
  toolRequirement: 'choco',
  getPaths: (env) async => env.tempDir.isEmpty ? const <String>[] : [p.join(env.tempDir, 'chocolatey')],
  cleanCommands: (_) => const [
    CleanCommand(command: 'choco', args: ['cache', 'remove'], label: 'choco cache remove'),
  ],
);

final scoopCategory = CategoryDefinition(
  id: 'scoop-cache',
  name: 'Scoop Cache',
  description: 'Downloaded installers kept by Scoop for app updates.',
  safety: SafetyTier.safe,
  tradeoff: 'Apps re-download installers on the next scoop update.',
  platforms: const [AppPlatform.windows],
  toolRequirement: 'scoop',
  getPaths: (env) async => [homePath(env, ['scoop', 'cache'])],
  cleanCommands: (_) => const [
    CleanCommand(command: 'scoop', args: ['cache', 'rm', '*'], label: 'scoop cache rm *'),
  ],
);

String _brewCache(HostEnv env) => env.isMacos
    ? homePath(env, ['Library', 'Caches', 'Homebrew'])
    : homePath(env, ['.cache', 'Homebrew']);

final largeFilesCategory = CategoryDefinition(
  id: 'large-files',
  name: 'Large Files',
  description: 'Individual files of ${formatBytes(_largeFileMinBytes)} or more in your home folder.',
  safety: SafetyTier.advanced,
  tradeoff: 'These are your real files — downloads, disk images, videos. Review the paths before deleting.',
  platforms: _allDesktop,
  kind: CategoryKind.files,
  perPath: true,
  getPaths: (env) async => _findLargeFiles(env),
  cleanCommands: (env) {
    final files = _findLargeFiles(env);
    if (files.isEmpty) return const [];
    return [
      CleanCommand(
        command: 'rm',
        args: files,
        label: 'delete ${files.length} large file${files.length == 1 ? '' : 's'}',
      ),
    ];
  },
);

const _largeFileMinBytes = 100 * 1024 * 1024;
const _largeFileMaxResults = 100;
const _largeFileMaxDepth = 12;

const _largeFileSkipDirs = {
  '.git', '.hg', '.svn', '.bzr', '.idea', '.vscode',
  'node_modules', 'build', 'dist', 'out', 'target', '.next', '.nuxt',
  'Pods', '.venv', 'venv', '.dart_tool', '.gradle', 'vendor',
  'bower_components', 'jspm_packages', 'stack-work',
  'Caches', 'Cache', '.cache', 'Library', 'Application Support',
  'AppData', 'Local Settings', '.Trash',
};

List<String> _findLargeFiles(HostEnv env) {
  if (env.home.isEmpty) return const [];

  List<FileSystemEntity> list(String dir) {
    try {
      return Directory(dir).listSync(followLinks: false);
    } catch (_) {
      return const [];
    }
  }

  FileSystemEntityType typeOf(String path) {
    try {
      return FileSystemEntity.typeSync(path, followLinks: false);
    } catch (_) {
      return FileSystemEntityType.notFound;
    }
  }

  int lengthOf(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  final hits = <({String path, int bytes})>[];
  void walk(String dir, int depth) {
    if (depth > _largeFileMaxDepth) return;
    for (final e in list(dir)) {
      final name = p.basename(e.path);
      if (name.startsWith('.')) continue;
      final type = typeOf(e.path);
      if (type == FileSystemEntityType.directory) {
        if (!_largeFileSkipDirs.contains(name)) walk(e.path, depth + 1);
      } else if (type == FileSystemEntityType.file) {
        final len = lengthOf(e.path);
        if (len >= _largeFileMinBytes) hits.add((path: e.path, bytes: len));
      }
    }
  }

  walk(env.home, 0);
  hits.sort((a, b) => b.bytes.compareTo(a.bytes));
  return [for (final h in hits.take(_largeFileMaxResults)) h.path];
}

String _npmPath(HostEnv env) =>
    env.isWindows ? localPath(env, ['npm-cache']) : homePath(env, ['.npm']);

String _pnpmPath(HostEnv env) =>
    env.isWindows ? localPath(env, ['pnpm']) : homePath(env, ['.cache', 'pnpm']);

String _yarnPath(HostEnv env) {
  if (env.isWindows) return localPath(env, ['Yarn', 'Cache']);
  if (env.isMacos) return homePath(env, ['Library', 'Caches', 'yarn']);
  return homePath(env, ['.cache', 'yarn']);
}

String _pipPath(HostEnv env) {
  if (env.isWindows) return localPath(env, ['pip', 'Cache']);
  if (env.isMacos) return homePath(env, ['Library', 'Caches', 'pip']);
  return homePath(env, ['.cache', 'pip']);
}

String _pubCachePath(HostEnv env) =>
    env.isWindows ? localPath(env, ['Pub', 'Cache']) : homePath(env, ['.pub-cache']);

String _gradleRoot(HostEnv env) => homePath(env, ['.gradle']);

String _gradleCaches(HostEnv env) => p.join(_gradleRoot(env), 'caches');

String _gradleWrapperDists(HostEnv env) => p.join(_gradleRoot(env), 'wrapper', 'dists');

String _goBuildCache(HostEnv env) {
  if (env.isWindows) return localPath(env, ['go-build']);
  if (env.isMacos) return homePath(env, ['Library', 'Caches', 'go-build']);
  return homePath(env, ['.cache', 'go-build']);
}

String _goModCache(HostEnv env) => homePath(env, ['go', 'pkg', 'mod']);

List<String> _systemPaths(HostEnv env) {
  switch (env.platform) {
    case AppPlatform.macos:
      return [
        homePath(env, ['Library', 'Caches', 'com.apple.helpd']),
        homePath(env, ['Library', 'Caches', 'com.google.SoftwareUpdateAgent']),
        homePath(env, ['Library', 'Caches', 'org.carthage.CarthageKit']),
      ];
    case AppPlatform.android:
      return [
        homePath(env, ['.cache']),
        homePath(env, ['.termux', 'cache']),
        homePath(env, ['.local', 'share', 'termux', 'boot']),
      ];
    case AppPlatform.linux:
      return [homePath(env, ['.cache'])];
    default:
      return const [];
  }
}

List<String> _existing(List<String> paths) =>
    paths.where((path) {
      try {
        return FileSystemEntity.typeSync(path, followLinks: false) !=
            FileSystemEntityType.notFound;
      } catch (_) {
        return false;
      }
    }).toList();

List<String> _oldDeviceSupportPaths(HostEnv env) {
  final root = homePath(env, ['Library', 'Developer', 'Xcode', 'iOS DeviceSupport']);
  try {
    final dir = Directory(root);
    if (!dir.existsSync()) return const [];
    final entries = dir
        .listSync(followLinks: false)
        .whereType<Directory>()
        .map((d) {
          var mtime = 0;
          try {
            mtime = d.statSync().modified.millisecondsSinceEpoch;
          } catch (_) {}
          return (path: d.path, mtime: mtime);
        })
        .toList()
      ..sort((a, b) => b.mtime.compareTo(a.mtime));
    if (entries.length <= 1) return const [];
    return entries.skip(1).map((e) => e.path).toList();
  } catch (_) {
    return const [];
  }
}

Future<List<String>> _unavailableSimulatorPaths(HostEnv env) async {
  if (!canSpawnProcesses) return const [];
  final devicesPath = homePath(env, ['Library', 'Developer', 'CoreSimulator', 'Devices']);
  try {
    final r = await Process.run('xcrun', ['simctl', 'list', 'devices', '-j']);
    if (r.exitCode != 0) return const [];
    final data = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    final devices = data['devices'] as Map<String, dynamic>? ?? {};
    final ids = <String>[];
    for (final list in devices.values) {
      if (list is! List) continue;
      for (final device in list) {
        if (device is Map && device['isAvailable'] == false && device['udid'] is String) {
          ids.add(device['udid'] as String);
        }
      }
    }
    return ids
        .map((id) => p.join(devicesPath, id))
        .where((path) => FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound)
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<int> _dockerReclaimableBytes() async {
  if (!canSpawnProcesses) return 0;
  try {
    final r = await Process.run('docker', [
      'system',
      'df',
      '--format',
      '{{.Type}}\t{{.Reclaimable}}',
    ]);
    var total = 0;
    for (final line in (r.stdout as String).split('\n')) {
      final parts = line.split('\t');
      if (parts.length < 2) continue;
      total += parseDockerSize(parts[1]);
    }
    return finiteBytes(total);
  } catch (_) {
    return 0;
  }
}

Future<int> _recycleBinBytes() async {
  try {
    final r = await Process.run('powershell.exe', [
      '-NoProfile',
      '-Command',
      r"$ErrorActionPreference='SilentlyContinue'; $n=0; $s=New-Object -ComObject Shell.Application; foreach($i in $s.NameSpace(10).Items()){ $n += [int64]$i.Size }; $n",
    ]);
    return finiteBytes(int.tryParse((r.stdout as String).trim()) ?? 0);
  } catch (_) {
    return 0;
  }
}

Future<int> _macTrashBytes() async {
  try {
    final r = await Process.run('osascript', [
      '-e',
      'tell application "Finder" to get size of trash',
    ]);
    final n = int.tryParse((r.stdout as String).trim());
    if (n != null && n >= 0) return n;
  } catch (_) {}
  throw StateError('finder trash size unavailable');
}

String? _cachedFlutterSdkCache;

Future<String?> _flutterSdkCachePath() async {
  if (_cachedFlutterSdkCache != null) return _cachedFlutterSdkCache;
  if (!canSpawnProcesses) return null;
  try {
    final r = Platform.isWindows
        ? await Process.run('where', ['flutter'])
        : await Process.run('sh', ['-c', 'command -v flutter']);
    var bin = (r.stdout as String).trim().split('\n').first.trim();
    if (bin.isEmpty) return null;
    try {
      bin = File(bin).resolveSymbolicLinksSync();
    } catch (_) {}
    final sdkBin = p.dirname(bin);
    _cachedFlutterSdkCache = p.join(sdkBin, 'cache');
    return _cachedFlutterSdkCache;
  } catch (_) {
    return null;
  }
}
