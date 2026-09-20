import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../log.dart';
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

  final FileStat stat;
  try {
    stat = FileStat.statSync(path);
  } catch (_) {
    _sizeCache.remove(_sizeKey(path));
    return 0;
  }
  if (stat.type == FileSystemEntityType.notFound) {
    _sizeCache.remove(_sizeKey(path));
    return 0;
  }

  final key = _sizeKey(path);
  final mtimeMs = stat.modified.millisecondsSinceEpoch;
  final hit = _sizeCache[key];
  if (hit != null && hit.mtimeMs == mtimeMs) {
    return hit.bytes;
  }

  // Cache miss: size the path the expensive way (du / walk), then remember it
  // keyed by the path's mtime so an unchanged "Rescan" replays the result.
  final bytes = await _sizePathUncached(path);
  _sizeCache[key] = _CachedSize(mtimeMs: mtimeMs, bytes: bytes);
  return bytes;
}

class _CachedSize {
  const _CachedSize({required this.mtimeMs, required this.bytes});
  final int mtimeMs;
  final int bytes;
}

final Map<String, _CachedSize> _sizeCache = {};

String _sizeKey(String path) {
  final normalized = p.normalize(p.absolute(path));
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

/// Drops a path (and everything beneath it) from the size cache. Used after a
/// clean so removed content is never replayed from a stale cache entry.
void invalidateSizeCache(String path) {
  final key = _sizeKey(path);
  _sizeCache.removeWhere((cached, _) => cached == key || cached.startsWith(key + p.separator));
}

/// Forgets every cached size. Used after a clean completes so the next scan
/// re-measures everything from disk.
void clearSizeCache() => _sizeCache.clear();

Future<int> _sizePathUncached(String path) async {
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

/// Removes any path inside [excluded] (or nested beneath one) from [paths],
/// so blocklisted locations are never measured or queued for deletion.
List<String> applyPathExclusions(List<String> paths, List<String> excluded) {
  if (excluded.isEmpty) return paths;
  final block = excluded
      .where((e) => e.trim().isNotEmpty)
      .map((e) => p.normalize(e))
      .toList();
  if (block.isEmpty) return paths;
  return paths.where((path) {
    final normalized = p.normalize(path);
    final blocked = block.any(
      (b) => normalized == b || normalized.startsWith(b + p.separator),
    );
    return !blocked;
  }).toList();
}

const _entriesMaxResults = 150;

/// Enumerates individual files and folders inside [roots].
///
/// File roots are listed themselves; directory roots are listed one level
/// deep so the user can pick specific items. Directories are sized the same
/// way the scanner sizes categories (`du`/walk). Results are sorted largest
/// first and capped for display.
Future<({List<ScanEntry> entries, bool truncated})> listEntriesForRoots(
  List<String> roots,
) async {
  final entries = <ScanEntry>[];
  for (final root in roots) {
    final type = _entryType(root);
    if (type == FileSystemEntityType.directory) {
      entries.addAll(await _entriesOfDirectory(root));
    } else if (type == FileSystemEntityType.file) {
      entries.add(ScanEntry(
        path: root,
        name: p.basename(root),
        sizeBytes: max(_fileSize(root), 0),
        kind: EntryKind.file,
      ));
    }
  }
  entries.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
  final truncated = entries.length > _entriesMaxResults;
  return (
    entries: truncated ? entries.sublist(0, _entriesMaxResults) : entries,
    truncated: truncated,
  );
}

Future<List<ScanEntry>> _entriesOfDirectory(String dir) async {
  final List<FileSystemEntity> raw;
  try {
    raw = Directory(dir).listSync(followLinks: false);
  } catch (_) {
    return const [];
  }

  final children = <({String path, String name, EntryKind kind, int bytes})>[];
  final dirs = <String>[];
  for (final e in raw) {
    final type = _entryType(e.path);
    if (type == FileSystemEntityType.directory) {
      dirs.add(e.path);
      children.add((path: e.path, name: p.basename(e.path), kind: EntryKind.directory, bytes: 0));
    } else if (type == FileSystemEntityType.file) {
      children.add((path: e.path, name: p.basename(e.path), kind: EntryKind.file, bytes: max(_fileSize(e.path), 0)));
    }
  }

  if (dirs.isNotEmpty) {
    final sized = await mapWithConcurrency(dirs, 4, (path) async {
      final bytes = await sizeOfPath(path);
      return (path: path, bytes: bytes);
    });
    final byPath = {for (final s in sized) s.path: s.bytes};
    for (var i = 0; i < children.length; i++) {
      final c = children[i];
      if (c.kind == EntryKind.directory) {
        children[i] = (path: c.path, name: c.name, kind: c.kind, bytes: byPath[c.path] ?? 0);
      }
    }
  }

  return [
    for (final c in children)
      ScanEntry(path: c.path, name: c.name, sizeBytes: max(c.bytes, 0), kind: c.kind),
  ];
}

FileSystemEntityType _entryType(String path) {
  try {
    return FileSystemEntity.typeSync(path, followLinks: false);
  } catch (_) {
    return FileSystemEntityType.notFound;
  }
}

int _fileSize(String path) {
  try {
    return File(path).lengthSync();
  } catch (_) {
    return 0;
  }
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
  List<String> excludedPaths = const [],
  ScanProgressCallback? onProgress,
}) async {
  final seenIds = <String>{};
  final unique = <CategoryDefinition>[];
  for (final category in categories) {
    if (seenIds.add(category.id)) unique.add(category);
  }
  categories = unique;
  if (categories.isEmpty) return const [];
  final batches = List<List<ScanResult>?>.filled(categories.length, null);
  var next = 0;
  var done = 0;
  String? current;

  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= categories.length) return;
      current = categories[i].name;
      onProgress?.call(done, categories.length, current);
      batches[i] = await _scanCategory(categories[i], env,
          excludedPaths: excludedPaths);
      done++;
      onProgress?.call(done, categories.length, current);
    }
  }

  final n = min(6, categories.length);
  await Future.wait(List.generate(n, (_) => worker()));
  onProgress?.call(done, categories.length, null);
  return [
    for (final b in batches) ...?b,
  ];
}

Future<List<ScanResult>> _scanCategory(
  CategoryDefinition category,
  HostEnv env, {
  List<String> excludedPaths = const [],
}) async {
  final applicable = category.platforms.contains(env.platform);
  if (!applicable) {
    return [
      ScanResult(
        category: category,
        paths: const [],
        totalSizeBytes: 0,
        applicable: false,
        detected: false,
      ),
    ];
  }

  var toolMissing = false;
  if (category.toolRequirement != null &&
      !await hasTool(category.toolRequirement!)) {
    toolMissing = true;
  }

  String? hint;
  if (category.skipReason != null) {
    try {
      hint = await category.skipReason!(env);
    } catch (_) {}
  }

  final rawPaths = applyPathExclusions(await category.getPaths(env), excludedPaths);
  if (category.perPath) {
    return _scanPerPath(category, env, rawPaths, toolMissing: toolMissing, hint: hint);
  }

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

  purgeLog(
    'scan',
    '${category.name}: ${formatBytes(totalSizeBytes)} '
    '${detected ? 'detected' : 'not detected'}'
    '${toolMissing ? ' (tool missing: ${category.toolRequirement})' : ''}'
    '${hint != null ? ' ($hint)' : ''}',
  );

  return [
    ScanResult(
      category: category,
      paths: sized.paths,
      totalSizeBytes: totalSizeBytes,
      applicable: true,
      detected: detected,
      toolMissing: toolMissing,
      scanHint: hint,
    ),
  ];
}

/// Splits a `perPath` category into one result per file/folder so each
/// individual item is visible and selectable on its own.
Future<List<ScanResult>> _scanPerPath(
  CategoryDefinition category,
  HostEnv env,
  List<String> rawPaths, {
  required bool toolMissing,
  required String? hint,
}) async {
  if (rawPaths.isEmpty) return const [];
  final sized = await sumPathSizes(rawPaths);
  final results = <ScanResult>[];
  for (final pathSize in sized.paths) {
    if (!pathSize.exists || pathSize.sizeBytes <= 0) continue;
    final scoped = _perPathCategory(category, pathSize.path);
    results.add(ScanResult(
      category: scoped,
      paths: [pathSize],
      totalSizeBytes: pathSize.sizeBytes,
      applicable: true,
      detected: true,
      toolMissing: toolMissing,
      scanHint: hint,
    ));
  }
  results.sort((a, b) => b.totalSizeBytes.compareTo(a.totalSizeBytes));
  return results;
}

CategoryDefinition _perPathCategory(
  CategoryDefinition base,
  String path,
) =>
    CategoryDefinition(
      id: '${base.id}@${p.normalize(path)}',
      name: p.basename(path),
      description: base.description,
      safety: base.safety,
      tradeoff: base.tradeoff,
      platforms: base.platforms,
      kind: base.kind,
      getPaths: (_) async => [path],
      cleanCommands: (_) => [
        CleanCommand(
          command: 'rm',
          args: [path],
          label: 'delete ${p.basename(path)}',
        ),
      ],
    );
