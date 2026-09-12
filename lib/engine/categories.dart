import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'bytes.dart';
import 'host.dart';
import 'platform.dart';
import 'types.dart';

const _allDesktop = [
  AppPlatform.macos,
  AppPlatform.linux,
  AppPlatform.windows,
];

const _allButIos = [
  AppPlatform.macos,
  AppPlatform.linux,
  AppPlatform.windows,
  AppPlatform.android,
];

const _everywhere = [
  AppPlatform.macos,
  AppPlatform.linux,
  AppPlatform.windows,
  AppPlatform.android,
  AppPlatform.ios,
];

List<CategoryDefinition> allCategories() => [
      trashCategory,
      systemCategory,
      appCachesCategory,
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
  platforms: _allButIos,
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
  description: 'Temporary files and caches this device can safely rebuild.',
  safety: SafetyTier.safe,
  tradeoff: 'Apps rebuild these caches the next time you use them.',
  platforms: const [AppPlatform.android, AppPlatform.ios],
  getPaths: (env) async => env.mobileCachePaths,
  cleanCommands: (env) => env.mobileCachePaths
      .map(
        (path) => CleanCommand(
          command: 'rm',
          args: ['-rf', path],
          label: 'remove ${p.basename(path)}',
        ),
      )
      .toList(),
);

final homebrewCategory = CategoryDefinition(
  id: 'homebrew-cache',
  name: 'Homebrew',
  description: 'Downloaded bottle archive cache plus old package versions.',
  safety: SafetyTier.safe,
  tradeoff: 'The next brew install re-downloads bottles; brew cleanup keeps current installs.',
  platforms: const [AppPlatform.macos, AppPlatform.linux],
  toolRequirement: 'brew',
  getPaths: (env) async => [_brewCache(env)],
  cleanCommands: (env) => [
    CleanCommand(
      command: 'rm',
      args: ['-rf', _brewCache(env)],
      label: 'remove brew download cache',
    ),
    const CleanCommand(
      command: 'brew',
      args: ['cleanup', '--prune=all'],
      label: 'brew cleanup --prune=all',
    ),
  ],
);

final npmCategory = CategoryDefinition(
  id: 'npm-cache',
  name: 'npm Cache',
  description: 'Downloaded package tarballs and registry metadata used by npm install.',
  safety: SafetyTier.safe,
  tradeoff: 'The next npm install in each project re-downloads packages.',
  platforms: _everywhere,
  toolRequirement: 'npm',
  getPaths: (env) async => [_npmPath(env)],
  cleanCommands: (_) => const [
    CleanCommand(
      command: 'npm',
      args: ['cache', 'clean', '--force'],
      label: 'npm cache clean --force',
    ),
  ],
);

final pnpmCategory = CategoryDefinition(
  id: 'pnpm-cache',
  name: 'pnpm Store',
  description: 'Cached package store and metadata used by pnpm.',
  safety: SafetyTier.safe,
  tradeoff: 'Packages are re-downloaded on the next pnpm install.',
  platforms: _allButIos,
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
  platforms: _allButIos,
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
  platforms: _everywhere,
  toolRequirement: Platform.isWindows ? 'pip' : 'pip3',
  getPaths: (env) async => [_pipPath(env)],
  cleanCommands: (_) {
    final bin = Platform.isWindows ? 'pip' : 'pip3';
    return [
      CleanCommand(
        command: bin,
        args: const ['cache', 'purge'],
        label: '$bin cache purge',
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
  platforms: _allButIos,
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
  platforms: _allButIos,
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
  platforms: _allButIos,
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
  platforms: _allButIos,
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
  platforms: _allButIos,
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
  platforms: _allButIos,
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
