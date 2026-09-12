import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'bytes.dart';
import 'platform.dart';
import 'tool_detect.dart';
import 'types.dart';

bool pathExists(String path) {
  if (path.isEmpty) return false;
  try {
    return FileSystemEntity.typeSync(path, followLinks: false) !=
        FileSystemEntityType.notFound;
  } catch (_) {
    return false;
  }
}

List<String> dedupeNestedPaths(List<String> paths) {
  final resolved = paths
      .where((e) => e.isNotEmpty)
      .map((e) {
        final r = p.normalize(p.absolute(e));
        return Platform.isWindows ? r.toLowerCase() : r;
      })
      .toSet()
      .toList()
    ..sort((a, b) => a.length.compareTo(b.length));

  final kept = <String>[];
  for (final path in resolved) {
    final nested = kept.any(
      (parent) => path == parent || path.startsWith(parent + p.separator),
    );
    if (!nested) kept.add(path);
  }
  return kept;
}

int walkSize(String root) {
  var total = 0;
  final stack = <String>[root];
  final seen = <String>{};

  while (stack.isNotEmpty) {
    final current = stack.removeLast();
    FileSystemEntityType type;
    FileStat st;
    try {
      type = FileSystemEntity.typeSync(current, followLinks: false);
      st = FileStat.statSync(current);
    } catch (_) {
      continue;
    }
    if (type == FileSystemEntityType.notFound) continue;
    if (type == FileSystemEntityType.link) continue;

    if (type != FileSystemEntityType.directory) {
      total += max(st.size, 0);
      continue;
    }

    final resolved = p.normalize(p.absolute(current));
    if (!seen.add(resolved)) continue;

    total += max(st.size, 0);

    try {
      for (final entry in Directory(current).listSync(followLinks: false)) {
        final name = p.basename(entry.path);
        if (name == '.' || name == '..') continue;
        stack.add(entry.path);
      }
    } catch (_) {}
  }
  return total;
}

Future<int> sizeOfPath(String path) async {
  if (path.isEmpty) return 0;
  if (!pathExists(path)) return 0;

  if (!Platform.isWindows && canSpawnProcesses) {
    try {
      final r = await Process.run('du', ['-sk', path]);
      final stdout = '${r.stdout}${r.stderr}';
      final k = parseDuKilobytes(r.stdout as String) ?? parseDuKilobytes(stdout);
      if (k != null) return k * 1024;
    } catch (_) {}
  }
  return walkSize(path);
}

Future<({List<PathSize> paths, int totalSizeBytes})> sumPathSizes(
  List<String> paths,
) async {
  final unique = dedupeNestedPaths(paths);
  final sized = await mapWithConcurrency(unique, 4, (path) async {
    final sizeBytes = await sizeOfPath(path);
    return PathSize(path: path, sizeBytes: sizeBytes, exists: pathExists(path));
  });
  final totalSizeBytes = sized.fold<int>(0, (acc, e) => acc + finiteBytes(e.sizeBytes));
  return (paths: sized, totalSizeBytes: totalSizeBytes);
}

Future<List<R>> mapWithConcurrency<T, R>(
  List<T> items,
  int limit,
  Future<R> Function(T item) fn,
) async {
  if (items.isEmpty) return [];
  final results = List<R?>.filled(items.length, null);
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final i = next;
      next++;
      if (i >= items.length) return;
      results[i] = await fn(items[i]);
    }
  }

  final n = min(limit, items.length);
  await Future.wait(List.generate(n, (_) => worker()));
  return results.cast<R>();
}

typedef ScanProgressCallback = void Function(
  int done,
  int total,
  String? currentName,
);

Future<List<ScanResult>> scanCategories(
  List<CategoryDefinition> categories,
  HostEnv env, {
  ScanProgressCallback? onProgress,
}) async {
  if (categories.isEmpty) return const [];
  final results = List<ScanResult?>.filled(categories.length, null);
  var next = 0;
  var done = 0;
  String? current;

  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= categories.length) return;
      current = categories[i].name;
      onProgress?.call(done, categories.length, current);
      results[i] = await _scanCategory(categories[i], env);
      done++;
      onProgress?.call(done, categories.length, current);
    }
  }

  final n = min(6, categories.length);
  await Future.wait(List.generate(n, (_) => worker()));
  onProgress?.call(done, categories.length, null);
  return results.cast<ScanResult>();
}

Future<ScanResult> _scanCategory(CategoryDefinition category, HostEnv env) async {
  final applicable = category.platforms.contains(env.platform);
  if (!applicable) {
    return ScanResult(
      category: category,
      paths: const [],
      totalSizeBytes: 0,
      applicable: false,
      detected: false,
    );
  }

  var toolMissing = false;
  if (category.toolRequirement != null &&
      !await hasTool(category.toolRequirement!)) {
    toolMissing = true;
  }

  final rawPaths = await category.getPaths(env);
  final sized = await sumPathSizes(rawPaths);
  var totalSizeBytes = sized.totalSizeBytes;
  if (category.getSizeBytes != null) {
    try {
      totalSizeBytes = finiteBytes(await category.getSizeBytes!(env));
    } catch (_) {
      totalSizeBytes = sized.totalSizeBytes;
    }
  }

  final detected = !toolMissing &&
      (sized.paths.any((e) => e.exists && e.sizeBytes > 0) ||
          totalSizeBytes > 0 ||
          (rawPaths.isEmpty && category.cleanCommands(env).isNotEmpty));

  return ScanResult(
    category: category,
    paths: sized.paths,
    totalSizeBytes: totalSizeBytes,
    applicable: true,
    detected: detected,
    toolMissing: toolMissing,
  );
}
