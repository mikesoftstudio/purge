import 'dart:io';

import 'package:flutter/services.dart';

import 'bytes.dart';
import 'types.dart';

const diskChannel = MethodChannel('dev.purge.app/disk');

Future<DiskInfo> getDiskInfo(HostEnv env) async {
  if (Platform.isWindows) return _windows(env);
  if (Platform.isMacOS || Platform.isLinux) return _unix(env);
  return _native(env);
}

DiskInfo aggregateDf({required List<DfSizes> rows, required String home}) {
  final block = rows
      .where((s) =>
          s.filesystem.startsWith('/dev/') &&
          !s.filesystem.startsWith('/dev/loop'))
      .toList();
  if (block.isEmpty) {
    return DiskInfo(
      totalBytes: 0,
      usedBytes: 0,
      freeBytes: 0,
      home: home,
      filesystem: 'unknown',
    );
  }

  String containerKey(DfSizes s) {
    final dev = s.filesystem;
    final m = RegExp(r'^/dev/disk\d+').firstMatch(dev);
    if (m != null) return m.group(0)!;
    return dev;
  }

  DfSizes? homeVolume;
  var homeLen = -1;
  for (final s in block) {
    final m = s.mountPoint;
    if (m.length > homeLen && (home == m || home.startsWith('$m/'))) {
      homeLen = m.length;
      homeVolume = s;
    }
  }

  final homeContainer = homeVolume == null ? null : containerKey(homeVolume);
  final inContainer = homeContainer == null
      ? block
      : block.where((s) => containerKey(s) == homeContainer).toList();

  var total = 0;
  var principal = block.first;
  for (final s in inContainer) {
    if (s.totalBytes > total) total = s.totalBytes;
    if (s.usedBytes > principal.usedBytes) principal = s;
  }

  final free = total > principal.freeBytes ? principal.freeBytes : 0;
  final used = total > free ? total - free : 0;
  final volumes = block
      .map((s) => DiskVolume(
            filesystem: s.filesystem,
            mountPoint: s.mountPoint,
            totalBytes: s.totalBytes,
            usedBytes: s.usedBytes,
            freeBytes: s.freeBytes,
          ))
      .toList();

  return DiskInfo(
    totalBytes: total,
    usedBytes: used,
    freeBytes: free,
    home: home,
    filesystem: homeVolume?.filesystem ?? 'unknown',
    volumes: volumes,
  );
}

Future<DiskInfo> _unix(HostEnv env) async {
  try {
    final r = await Process.run('df', ['-kP']);
    return aggregateDf(rows: parseDfPosixAll(r.stdout as String), home: env.home);
  } catch (_) {
    return DiskInfo(
      totalBytes: 0,
      usedBytes: 0,
      freeBytes: 0,
      home: env.home,
      filesystem: 'unknown',
    );
  }
}

Future<DiskInfo> _windows(HostEnv env) async {
  final drive = env.home.split(r'\').first + r'\';
  try {
    final r = await Process.run('powershell.exe', [
      '-NoProfile',
      '-Command',
      'Get-PSDrive -PSProvider FileSystem | Where-Object { \$_.Root -eq \'$drive\' } | Select-Object -First 1 | ForEach-Object { "\$(\$_.Used) \$(\$_.Free) \$(\$_.Root)" }',
    ]);
    final parts = (r.stdout as String).trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final used = int.tryParse(parts[0]);
      final free = int.tryParse(parts[1]);
      if (used != null && used >= 0 && free != null && free >= 0) {
        return DiskInfo(
          totalBytes: used + free,
          usedBytes: used,
          freeBytes: free,
          home: env.home,
          filesystem: drive,
          volumes: [
            DiskVolume(
              filesystem: drive,
              mountPoint: drive,
              totalBytes: used + free,
              usedBytes: used,
              freeBytes: free,
            ),
          ],
        );
      }
    }
  } catch (_) {}
  return DiskInfo(
    totalBytes: 0,
    usedBytes: 0,
    freeBytes: 0,
    home: env.home,
    filesystem: drive,
  );
}

Future<DiskInfo> _native(HostEnv env) async {
  try {
    final path = env.home.isNotEmpty ? env.home : Directory.systemTemp.path;
    final raw = await diskChannel.invokeMethod<Map<dynamic, dynamic>>('getDiskInfo', {
      'path': path,
    });
    if (raw != null) {
      final total = (raw['total'] as num?)?.toInt() ?? 0;
      final free = (raw['free'] as num?)?.toInt() ?? 0;
      final used = (raw['used'] as num?)?.toInt() ?? (total - free);
      return DiskInfo(
        totalBytes: total,
        usedBytes: used < 0 ? 0 : used,
        freeBytes: free,
        home: env.home,
        filesystem: path,
      );
    }
  } catch (_) {}
  return DiskInfo(
    totalBytes: 0,
    usedBytes: 0,
    freeBytes: 0,
    home: env.home,
    filesystem: 'unknown',
  );
}

Future<bool> requestStorageAccess() async {
  if (!Platform.isAndroid) return true;
  try {
    final ok = await diskChannel.invokeMethod<bool>('requestStoragePermission');
    return ok ?? false;
  } catch (_) {
    return false;
  }
}
