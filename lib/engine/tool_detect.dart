import 'dart:io';

import 'platform.dart';
import 'types.dart';

const knownTools = [
  'brew',
  'npm',
  'pnpm',
  'yarn',
  'pip3',
  'pip',
  'pod',
  'flutter',
  'dart',
  'gradle',
  'docker',
  'go',
  'cargo',
  'xcodebuild',
  'xcrun',
  'sdkmanager',
  'dotnet',
  'choco',
  'scoop',
];

final _toolCache = <String, bool>{};
final _versionCache = <String, String?>{};

Future<bool> hasTool(String name) async {
  if (name.isEmpty) return false;
  final cached = _toolCache[name];
  if (cached != null) return cached;
  if (!canSpawnProcesses) {
    _toolCache[name] = false;
    return false;
  }
  var found = false;
  try {
    if (Platform.isWindows) {
      final r = await Process.run('where', [name], runInShell: false);
      found = r.exitCode == 0;
    } else {
      final r = await Process.run('sh', ['-c', 'command -v "$name"']);
      found = r.exitCode == 0 && (r.stdout as String).trim().isNotEmpty;
    }
  } catch (_) {
    found = false;
  }
  _toolCache[name] = found;
  return found;
}

Future<String?> toolVersion(String name) async {
  if (_versionCache.containsKey(name)) return _versionCache[name];
  if (!canSpawnProcesses) {
    _versionCache[name] = null;
    return null;
  }
  String? version;
  try {
    final args = name == 'xcodebuild' ? ['-version'] : ['--version'];
    final r = await Process.run(name, args, runInShell: Platform.isWindows);
    version = (r.stdout as String)
        .split('\n')
        .first
        .trim();
    if (version.length > 80) version = version.substring(0, 80);
    if (version.isEmpty) version = null;
  } catch (_) {
    version = null;
  }
  _versionCache[name] = version;
  return version;
}

void resetToolCache() {
  _toolCache.clear();
  _versionCache.clear();
}

Future<List<ToolInfo>> detectTools() async {
  final out = <ToolInfo>[];
  for (final name in knownTools) {
    final installed = await hasTool(name);
    out.add(ToolInfo(
      name: name,
      installed: installed,
      version: installed ? await toolVersion(name) : null,
    ));
  }
  return out;
}
