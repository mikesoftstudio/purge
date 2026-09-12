import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/bytes.dart';
import '../engine/categories.dart';
import '../engine/cleaner.dart';
import '../engine/disk.dart';
import '../engine/host.dart';
import '../engine/platform.dart';
import '../engine/scanner.dart';
import '../engine/types.dart';

class PurgeController extends ChangeNotifier {
  HostEnv? env;
  DiskInfo disk = DiskInfo.empty;
  List<ScanResult> results = const [];
  final Set<String> selected = {};
  bool ready = false;
  bool scanning = false;
  bool cleaning = false;
  String? scanError;
  int scanDone = 0;
  int scanTotal = 0;
  String? scanCurrent;
  List<CleanProgressEvent> events = [];
  CleanSummary? summary;
  ThemeMode themeMode = ThemeMode.system;
  DateTime? cleanStartedAt;
  int lastFreedBytes = 0;
  bool _cancel = false;

  AppPlatform get platform => env?.platform ?? detectPlatform();
  String get platformName => platformLabel(platform);
  String get noun => deviceNoun(platform);

  int get totalReclaimableBytes => results
      .where((r) => r.detected)
      .fold<int>(0, (acc, r) => acc + r.totalSizeBytes);

  int get selectedBytes => results
      .where((r) => selected.contains(r.id) && r.detected)
      .fold<int>(0, (acc, r) => acc + r.totalSizeBytes);

  List<ScanResult> get selectedItems =>
      results.where((r) => selected.contains(r.id)).toList();

  List<ScanResult> get selectable => results
      .where((r) => r.applicable && (r.detected || r.totalSizeBytes > 0))
      .toList();

  Future<void> init() async {
    await _loadTheme();
    await _loadLastFreed();
    env = await loadHostEnv();
    if (env!.platform == AppPlatform.android) {
      await requestStorageAccess();
    }
    await loadDisk();
    ready = true;
    notifyListeners();
  }

  Future<void> loadDisk() async {
    if (env == null) return;
    disk = await getDiskInfo(env!);
    notifyListeners();
  }

  Future<void> scan() async {
    if (env == null || scanning) return;
    scanning = true;
    scanError = null;
    scanDone = 0;
    scanTotal = allCategories().length;
    scanCurrent = null;
    notifyListeners();
    try {
      results = await scanCategories(
        allCategories(),
        env!,
        onProgress: (done, total, current) {
          scanDone = done;
          scanTotal = total;
          scanCurrent = current;
          notifyListeners();
        },
      );
      selected.clear();
    } catch (err) {
      scanError = err.toString();
    } finally {
      scanCurrent = null;
      scanning = false;
      notifyListeners();
    }
  }

  void toggle(String id) {
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    selected
      ..clear()
      ..addAll(selectable.map((r) => r.id));
    notifyListeners();
  }

  void selectRecommended() {
    final ids = selectable
        .where((r) => r.safety != SafetyTier.advanced)
        .map((r) => r.id);
    selected
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void clearSelection() {
    selected.clear();
    notifyListeners();
  }

  Future<void> cleanSelected() async {
    if (env == null || cleaning || selected.isEmpty) return;
    final ids = selected.toList();
    final cats = ids.map(getCategory).whereType<CategoryDefinition>().toList();
    final sizes = {
      for (final r in results)
        if (ids.contains(r.id)) r.id: r.totalSizeBytes,
    };
    cleaning = true;
    _cancel = false;
    events = [];
    cleanStartedAt = DateTime.now();
    notifyListeners();
    try {
      await runCleanJob(
        categories: cats,
        env: env!,
        measuredSizes: sizes,
        onProgress: (event) {
          final idx = events.indexWhere((e) => e.categoryId == event.categoryId);
          if (idx >= 0) {
            events[idx] = event;
          } else {
            events.add(event);
          }
          notifyListeners();
        },
        isCancelled: () => _cancel,
      );
    } finally {
      final finished = DateTime.now();
      final totalFreed = events.fold<int>(
        0,
        (acc, e) => acc + finiteBytes(e.freedBytes ?? 0),
      );
      summary = CleanSummary(
        totalFreedBytes: totalFreed,
        cleaned: events.where((e) => e.status == 'done').map((e) => e.categoryId).toList(),
        skipped: events.where((e) => e.status == 'skipped').map((e) => e.categoryId).toList(),
        errored: events.where((e) => e.status == 'error').map((e) => e.categoryId).toList(),
        startedAt: cleanStartedAt ?? finished,
        finishedAt: finished,
      );
      if (totalFreed > 0) {
        lastFreedBytes = totalFreed;
        unawaited(_saveLastFreed(totalFreed));
      }
      cleaning = false;
      selected.clear();
      notifyListeners();
      await loadDisk();
    }
  }

  void cancelClean() {
    _cancel = true;
    notifyListeners();
  }

  Future<void> cycleTheme() async {
    themeMode = switch (themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('purge.theme', themeMode.name);
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('purge.theme');
      themeMode = switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {}
  }

  Future<void> _loadLastFreed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      lastFreedBytes = prefs.getInt('purge.last_freed') ?? 0;
    } catch (_) {}
  }

  Future<void> _saveLastFreed(int bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('purge.last_freed', bytes);
    } catch (_) {}
  }
}
