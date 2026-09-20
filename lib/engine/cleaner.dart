import 'dart:io';

import 'package:path/path.dart' as p;

import '../log.dart';
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
  CleanCommandError(this.commandLabel, this.exitCode, {this.detail});
  final String commandLabel;
  final int? exitCode;
  final String? detail;
  @override
  String toString() {
    final base = 'Command failed (exit ${exitCode ?? "?"}): $commandLabel';
    final message = detail?.trim() ?? '';
    return message.isEmpty ? base : '$base — $message';
  }
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

Future<void> runCleanCommand(
  CleanCommand cmd, {
  required String home,
  void Function(int completed, int total)? onProgress,
}) async {
  final label = cmd.label ?? cmd.command;
  purgeLog('clean', 'running: $label');
  if (cmd.command == 'rm') {
    final targets = cmd.args.where((a) => !a.startsWith('-')).toList();
    var completed = 0;
    for (final arg in targets) {
      await removePath(arg, home: home);
      completed++;
      if (onProgress != null) onProgress(completed, targets.length);
    }
    purgeLog('clean', 'done: $label');
    return;
  }

  if (!canSpawnProcesses) {
    throw CleanCommandError(label, null, detail: 'Cannot spawn processes');
  }

  Future<ProcessResult> run(String exec, List<String> args) async {
    try {
      return await Process.run(exec, args, runInShell: false);
    } catch (e) {
      throw CleanCommandError(label, null, detail: '$e');
    }
  }

  if (cmd.shell || Platform.isWindows) {
    final shell = Platform.isWindows ? 'powershell.exe' : '/bin/bash';
    final joined = ([cmd.command, ...cmd.args]).join(' ');
    final full = Platform.isWindows ? '$joined; exit \$LASTEXITCODE' : joined;
    final shellArgs = Platform.isWindows
        ? ['-NoProfile', '-Command', full]
        : ['-c', full];
    final r = await run(shell, shellArgs);
    if (r.exitCode != 0) {
      final tail = (r.stderr as String).trim();
      purgeLog('clean', 'failed: $label (exit ${r.exitCode}) ${tail.length > 200 ? tail.substring(tail.length - 200) : tail}');
      throw CleanCommandError(label, r.exitCode,
          detail: tail.isEmpty ? null : tail);
    }
    purgeLog('clean', 'done: $label');
    return;
  }

  final r = await run(cmd.command, cmd.args);
  if (r.exitCode != 0) {
    final tail = (r.stderr as String).trim();
    purgeLog('clean', 'failed: $label (exit ${r.exitCode}) ${tail.length > 200 ? tail.substring(tail.length - 200) : tail}');
    throw CleanCommandError(label, r.exitCode,
        detail: tail.isEmpty ? null : tail);
  }
  purgeLog('clean', 'done: $label');
}

Future<void> runCleanJob({
  required List<CategoryDefinition> categories,
  required HostEnv env,
  Map<String, int>? measuredSizes,
  Duration? minAge,
  List<String> excludedPaths = const [],
  required void Function(CleanProgressEvent event) onProgress,
  required bool Function() isCancelled,
}) async {
  final planned = <({CategoryDefinition category, List<CleanCommand> commands})>[
    for (final category in categories)
      (
        category: category,
        commands: _planCommands(category, env, minAge: minAge, excludedPaths: excludedPaths),
      ),
  ];
  var done = 0;
  var total = 0;
  for (final plan in planned) {
    total += _unitsOf(plan.commands);
  }

  var lastCompleted = 0;

  void clearProgress() {
    lastCompleted = 0;
  }

  void addUnits(int n) {
    done += n;
  }

  void emit(
    String categoryId,
    String status, {
    String? label,
    int? freedBytes,
  }) {
    onProgress(CleanProgressEvent(
      categoryId: categoryId,
      status: status,
      label: label,
      freedBytes: freedBytes,
      done: done,
      total: total,
    ));
  }

  for (final plan in planned) {
    final category = plan.category;
    if (isCancelled()) {
      addUnits(plan.commands.isEmpty ? 0 : _unitsOf(plan.commands));
      emit(category.id, 'skipped', label: 'Cancelled');
      continue;
    }

    final categoryUnits = plan.commands.isEmpty ? 0 : _unitsOf(plan.commands);
    var catDone = 0;

    if (category.skipReason != null) {
      final reason = await category.skipReason!(env).catchError((_) => null);
      if (reason != null) {
        purgeLog('clean', 'skipped ${category.name}: $reason');
        addUnits(categoryUnits);
        catDone = categoryUnits;
        emit(category.id, 'skipped', label: reason);
        continue;
      }
    }

    if (plan.commands.isEmpty) {
      final label = minAge != null
          ? CleanerStrings.recentlyUsedSkipped
          : CleanerStrings.excludedSkipped;
      purgeLog('clean', 'skipped ${category.name}: $label');
      addUnits(0);
      emit(category.id, 'skipped', label: label);
      continue;
    }

    purgeLog('clean', 'starting ${category.name}');
    emit(category.id, 'cleaning');

    final before = measuredSizes?[category.id] ?? await _measureCategory(category, env);
    final commands = plan.commands;

    var outcome = 'done';
    for (final cmd in commands) {
      if (isCancelled()) {
        outcome = 'error';
        break;
      }

      final commandUnits = _unitsOfCommand(cmd);
      clearProgress();

      emit(category.id, 'cleaning', label: cmd.label ?? cmd.command);
      try {
        if (cmd.command == 'rm') {
          await runCleanCommand(
            cmd,
            home: env.home,
            onProgress: (completed, cmdTotal) {
              final delta = completed - lastCompleted;
              lastCompleted = completed;
              if (delta > 0) {
                addUnits(delta);
                catDone += delta;
                emit(category.id, 'cleaning', label: cmd.label ?? cmd.command);
              }
            },
          );
        } else {
          await runCleanCommand(cmd, home: env.home);
          addUnits(commandUnits);
          catDone += commandUnits;
          emit(category.id, 'cleaning', label: cmd.label ?? cmd.command);
        }
      } catch (err) {
        final fallback = (category.onFailureCommands?.call(env) ?? const <CleanCommand>[])
            .where((c) => c.command != cmd.command || c.args.join(' ') != cmd.args.join(' '))
            .toList();
        if (fallback.isEmpty) {
          outcome = 'error';
          clearProgress();
          addUnits(categoryUnits - catDone);
          catDone = categoryUnits;
          emit(category.id, 'error',
              label: err.toString().split('\n').first);
          break;
        }
        var recovered = false;
        for (final c in fallback) {
          emit(category.id, 'cleaning', label: 'retry: ${c.label ?? c.command}');
          try {
            if (c.command == 'rm') {
              await runCleanCommand(
                c,
                home: env.home,
                onProgress: (completed, cmdTotal) {
                  final delta = completed - lastCompleted;
                  lastCompleted = completed;
                  if (delta > 0) {
                    addUnits(delta);
                    catDone += delta;
                  }
                },
              );
            } else {
              await runCleanCommand(c, home: env.home);
              addUnits(_unitsOfCommand(c));
              catDone += _unitsOfCommand(c);
            }
            recovered = true;
            break;
          } catch (_) {}
        }
        if (!recovered) {
          outcome = 'error';
          addUnits(categoryUnits - catDone);
          catDone = categoryUnits;
          emit(category.id, 'error',
              label: err.toString().split('\n').first);
        }
        break;
      }
      clearProgress();
    }

    if (isCancelled()) {
      addUnits(categoryUnits - catDone);
      emit(category.id, 'skipped', label: 'Cancelled');
      continue;
    }

    var after = before;
    try {
      after = await _measureCategory(category, env);
    } catch (_) {
      after = before;
    }
    final freedBytes = max0(finiteBytes(before) - finiteBytes(after));
    purgeLog('clean',
        '${category.name}: $outcome freed ${formatBytes(freedBytes)}');

    if (categoryUnits > catDone) {
      addUnits(categoryUnits - catDone);
    }
    if (outcome == 'error') {
      emit(category.id, 'error', freedBytes: freedBytes);
    } else {
      emit(category.id, 'done', freedBytes: freedBytes);
    }
  }
}

/// How many progress units a command contributes: one per path it removes,
/// one per non-`rm` command (which we can only step once).
int _unitsOf(List<CleanCommand> commands) =>
    commands.fold<int>(0, (acc, c) => acc + _unitsOfCommand(c));

class CleanerStrings {
  CleanerStrings._();

  static const recentlyUsedSkipped = 'recently used — skipped by age filter';
  static const excludedSkipped = 'blocked — skipped because it is in your blocklist';
}

/// Builds the effective clean commands for a category, applying the age filter
/// (rm-only) and then dropping any paths the user blocklisted.
List<CleanCommand> _planCommands(
  CategoryDefinition category,
  HostEnv env, {
  Duration? minAge,
  List<String> excludedPaths = const [],
}) {
  var commands = category.cleanCommands(env);
  if (minAge != null) {
    commands = _applyAgeFilter(commands, minAge);
  }
  if (excludedPaths.isNotEmpty) {
    commands = _applyExclusions(commands, excludedPaths);
  }
  return commands;
}

/// Removes `rm` targets that are (or are nested beneath) a blocklisted path.
/// Non-`rm` tool commands are left untouched; category-level exclusions happen
/// earlier, in the scan step.
List<CleanCommand> _applyExclusions(
    List<CleanCommand> commands, List<String> excludedPaths) {
  final block = excludedPaths
      .where((e) => e.trim().isNotEmpty)
      .map((e) => p.normalize(e))
      .toList();
  if (block.isEmpty) return commands;
  final out = <CleanCommand>[];
  for (final cmd in commands) {
    if (cmd.command != 'rm') {
      out.add(cmd);
      continue;
    }
    final flags = cmd.args.where((a) => a.startsWith('-')).toList();
    final targets = cmd.args.where((a) => !a.startsWith('-')).toList();
    final kept = targets.where((a) {
      final n = p.normalize(a);
      return block.every((b) => n != b && !n.startsWith(b + p.separator));
    }).toList();
    if (kept.isEmpty) continue;
    if (kept.length == targets.length) {
      out.add(cmd);
    } else {
      out.add(CleanCommand(
        command: 'rm',
        args: [...flags, ...kept],
        shell: cmd.shell,
        label: cmd.label,
      ));
    }
  }
  return out;
}

/// Returns [commands] with the `rm` commands trimmed to only paths whose
/// last-modified time is older than [minAge]. Non-`rm` tool commands (brew,
/// npm, ...) are kept as-is. Empty results mean nothing qualifies.
List<CleanCommand> _applyAgeFilter(
    List<CleanCommand> commands, Duration minAge) {
  final cutoff = DateTime.now().subtract(minAge);
  final out = <CleanCommand>[];
  for (final cmd in commands) {
    if (cmd.command != 'rm') {
      out.add(cmd);
      continue;
    }
    final flags = cmd.args.where((a) => a.startsWith('-')).toList();
    final targets = cmd.args.where((a) => !a.startsWith('-')).toList();
    final kept = targets.where((a) => _olderThan(cutoff, a)).toList();
    if (kept.isEmpty) continue;
    if (kept.length == targets.length) {
      out.add(cmd);
    } else {
      out.add(CleanCommand(
        command: 'rm',
        args: [...flags, ...kept],
        shell: cmd.shell,
        label: cmd.label,
      ));
    }
  }
  return out;
}

bool _olderThan(DateTime cutoff, String path) {
  try {
    return !FileStat.statSync(path).modified.isAfter(cutoff);
  } catch (_) {
    return true;
  }
}

int _unitsOfCommand(CleanCommand cmd) {
  if (cmd.command == 'rm') {
    final targets = cmd.args.where((a) => !a.startsWith('-')).length;
    return targets > 0 ? targets : 1;
  }
  return 1;
}

int max0(int n) => n > 0 ? n : 0;

List<ScanResult> applyCleanToResults(
    List<ScanResult> results, List<CleanProgressEvent> events) {
  if (results.isEmpty) return results;
  final freed = <String, int>{};
  for (final e in events) {
    final f = e.freedBytes;
    if (e.status == 'done' && f != null && f > 0) {
      freed[e.categoryId] = (freed[e.categoryId] ?? 0) + f;
    }
  }
  if (freed.isEmpty) return results;
  return results.map((r) {
    final f = freed[r.id];
    if (f == null) return r;
    final remaining = finiteBytes(r.totalSizeBytes - f);
    final detected = remaining > 0 && r.detected;
    return ScanResult(
      category: r.category,
      paths: r.paths,
      totalSizeBytes: remaining,
      applicable: r.applicable,
      detected: detected,
      toolMissing: r.toolMissing,
      scanHint: r.scanHint,
    );
  }).toList();
}

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
