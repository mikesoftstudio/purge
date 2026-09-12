import 'dart:io';

import 'package:path/path.dart' as p;

import 'bytes.dart';
import 'platform.dart';
import 'scanner.dart';
import 'types.dart';

class UnsafePathError implements Exception {
  UnsafePathError(this.path);
  final String path;
  @override
  String toString() => 'Refusing to remove unsafe path: $path';
}

class CleanCommandError implements Exception {
  CleanCommandError(this.commandLabel, this.exitCode);
  final String commandLabel;
  final int? exitCode;
  @override
  String toString() => 'Command failed (exit ${exitCode ?? "?"}): $commandLabel';
}

void assertSafePath(String path, {required String home}) {
  final normalized = p.normalize(path);
  if (path.trim().isEmpty) throw UnsafePathError('empty path');
  if (normalized == '/' || normalized == r'\') throw UnsafePathError(path);

  if (Platform.isWindows) {
    if (RegExp(r'^[a-zA-Z]:\\?$').hasMatch(normalized)) {
      throw UnsafePathError(path);
    }
    if (normalized.toLowerCase() == p.normalize(home).toLowerCase()) {
      throw UnsafePathError(path);
    }
  } else if (normalized == home) {
    throw UnsafePathError(path);
  }

  final segments = p.split(normalized).where((s) => s.isNotEmpty && s != '/').toList();
  if (segments.isEmpty) throw UnsafePathError(path);
}

Future<void> removePath(String path, {required String home}) async {
  assertSafePath(path, home: home);
  if (!pathExists(path)) return;
  final type = FileSystemEntity.typeSync(path, followLinks: false);
  if (type == FileSystemEntityType.directory) {
    try {
      await Directory(path).delete(recursive: true);
    } catch (_) {
      final dir = Directory(path);
      if (!dir.existsSync()) return;
      for (final entry in dir.listSync(followLinks: false)) {
        try {
          if (entry is Directory) {
            await entry.delete(recursive: true);
          } else {
            await entry.delete();
          }
        } catch (_) {}
      }
    }
  } else {
    await File(path).delete();
  }
}

Future<void> runCleanCommand(CleanCommand cmd, {required String home}) async {
  if (cmd.command == 'rm') {
    for (final arg in cmd.args) {
      if (arg.startsWith('-')) continue;
      await removePath(arg, home: home);
    }
    return;
  }

  if (!canSpawnProcesses) {
    throw CleanCommandError(cmd.label ?? cmd.command, null);
  }

  if (cmd.shell || Platform.isWindows) {
    final shell = Platform.isWindows ? 'powershell.exe' : '/bin/bash';
    final joined = ([cmd.command, ...cmd.args]).join(' ');
    final full = Platform.isWindows ? '$joined; exit \$LASTEXITCODE' : joined;
    final shellArgs = Platform.isWindows
        ? ['-NoProfile', '-Command', full]
        : ['-c', full];
    final r = await Process.run(shell, shellArgs, runInShell: false);
    if (r.exitCode != 0) {
      throw CleanCommandError(cmd.label ?? cmd.command, r.exitCode);
    }
    return;
  }

  final r = await Process.run(cmd.command, cmd.args);
  if (r.exitCode != 0) {
    throw CleanCommandError(cmd.label ?? cmd.command, r.exitCode);
  }
}

Future<void> runCleanJob({
  required List<CategoryDefinition> categories,
  required HostEnv env,
  Map<String, int>? measuredSizes,
  required void Function(CleanProgressEvent event) onProgress,
  required bool Function() isCancelled,
}) async {
  for (final category in categories) {
    if (isCancelled()) {
      onProgress(CleanProgressEvent(
        categoryId: category.id,
        status: 'skipped',
        label: 'Cancelled',
      ));
      continue;
    }

    if (category.skipReason != null) {
      final reason = await category.skipReason!(env).catchError((_) => null);
      if (reason != null) {
        onProgress(CleanProgressEvent(
          categoryId: category.id,
          status: 'skipped',
          label: reason,
        ));
        continue;
      }
    }

    onProgress(CleanProgressEvent(categoryId: category.id, status: 'cleaning'));

    final before = measuredSizes?[category.id] ?? await _measureCategory(category, env);
    final commands = category.cleanCommands(env);

    var outcome = 'done';
    for (final cmd in commands) {
      if (isCancelled()) {
        outcome = 'error';
        break;
      }
      onProgress(CleanProgressEvent(
        categoryId: category.id,
        status: 'cleaning',
        label: cmd.label ?? cmd.command,
      ));
      try {
        await runCleanCommand(cmd, home: env.home);
      } catch (err) {
        final fallback = (category.onFailureCommands?.call(env) ?? const <CleanCommand>[])
            .where((c) => c.command != cmd.command || c.args.join(' ') != cmd.args.join(' '))
            .toList();
        if (fallback.isEmpty) {
          outcome = 'error';
          onProgress(CleanProgressEvent(
            categoryId: category.id,
            status: 'error',
            label: err.toString().split('\n').first,
          ));
          break;
        }
        var recovered = false;
        for (final c in fallback) {
          onProgress(CleanProgressEvent(
            categoryId: category.id,
            status: 'cleaning',
            label: 'retry: ${c.label ?? c.command}',
          ));
          try {
            await runCleanCommand(c, home: env.home);
            recovered = true;
            break;
          } catch (_) {}
        }
        if (!recovered) {
          outcome = 'error';
          onProgress(CleanProgressEvent(
            categoryId: category.id,
            status: 'error',
            label: err.toString().split('\n').first,
          ));
        }
        break;
      }
    }

    if (isCancelled()) {
      onProgress(CleanProgressEvent(
        categoryId: category.id,
        status: 'skipped',
        label: 'Cancelled',
      ));
      continue;
    }

    var after = before;
    try {
      after = await _measureCategory(category, env);
    } catch (_) {
      after = before;
    }
    final freedBytes = max0(finiteBytes(before) - finiteBytes(after));

    if (outcome == 'error') {
      onProgress(CleanProgressEvent(
        categoryId: category.id,
        status: 'error',
        freedBytes: freedBytes,
      ));
    } else {
      onProgress(CleanProgressEvent(
        categoryId: category.id,
        status: 'done',
        freedBytes: freedBytes,
      ));
    }
  }
}

int max0(int n) => n > 0 ? n : 0;

Future<int> _measureCategory(CategoryDefinition category, HostEnv env) async {
  Future<int> fromPaths() async {
    final paths = await category.getPaths(env);
    final sized = await sumPathSizes(paths);
    return sized.totalSizeBytes;
  }

  if (category.getSizeBytes != null) {
    try {
      return finiteBytes(await category.getSizeBytes!(env));
    } catch (_) {
      return fromPaths();
    }
  }
  return fromPaths();
}
