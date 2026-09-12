import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'platform.dart';
import 'types.dart';

Future<HostEnv> loadHostEnv() async {
  final platform = detectPlatform();
  var home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  final localAppData = Platform.environment['LOCALAPPDATA'] ??
      (home.isNotEmpty ? p.join(home, 'AppData', 'Local') : '');
  final tempDir = Platform.environment['TEMP'] ??
      Platform.environment['TMPDIR'] ??
      Directory.systemTemp.path;
  final cargoHome = Platform.environment['CARGO_HOME'] ??
      (home.isNotEmpty ? p.join(home, '.cargo') : '');

  final mobileCachePaths = <String>[];
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      final cache = await getApplicationCacheDirectory();
      final tmp = await getTemporaryDirectory();
      mobileCachePaths.addAll([cache.path, tmp.path]);
      try {
        final support = await getApplicationSupportDirectory();
        mobileCachePaths.add(support.path);
      } catch (_) {}
      if (home.isEmpty) {
        home = cache.parent.path;
      }
      if (Platform.isAndroid) {
        try {
          final ext = await getExternalStorageDirectory();
          if (ext != null) mobileCachePaths.add(ext.path);
        } catch (_) {}
        if (!Directory(home).existsSync()) {
          const shared = '/storage/emulated/0';
          if (Directory(shared).existsSync()) home = shared;
        }
      }
    }
  } catch (_) {}

  return HostEnv(
    platform: platform,
    home: home,
    localAppData: localAppData,
    tempDir: tempDir,
    cargoHome: cargoHome,
    mobileCachePaths: mobileCachePaths,
  );
}

String homePath(HostEnv env, List<String> parts) => p.joinAll([env.home, ...parts]);

String localPath(HostEnv env, List<String> parts) =>
    p.joinAll([env.localAppData, ...parts]);
