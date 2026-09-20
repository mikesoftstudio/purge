import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/bytes.dart';
import '../engine/categories.dart';
import '../engine/cleaner.dart';
import '../engine/custom.dart';
import '../engine/disk.dart';
import '../engine/host.dart';
import '../engine/platform.dart';
import '../engine/projects.dart';
import '../engine/scanner.dart';
import '../engine/types.dart';
import '../log.dart';
import '../platform/notify.dart';
import '../platform/tray.dart';

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
  int cleanDone = 0;
  int cleanTotal = 0;
  CleanSummary? summary;
  ThemeMode themeMode = ThemeMode.system;
  DateTime? cleanStartedAt;
  int lastFreedBytes = 0;
  bool storageAccessGranted = true;
  bool _cancel = false;
  List<String> _savedProjectRoots = const [];
  List<CategoryDefinition> dynamicCategories = const [];
  Set<String> _savedSelection = const {};
  int ageFilterDays = 0;
  List<String> customRoots = const [];
  Set<String> excludedCategoryIds = const {};
  List<String> excludedPaths = const [];
  List<CategoryDefinition> customCategories = const [];
  bool autoScanEnabled = true;
  int autoScanMinutes = 30;
  int notifyThresholdBytes = 0;
  int _lastNotifiedReclaimable = 0;
  Timer? _rescanTimer;

  AppPlatform get platform => env?.platform ?? detectPlatform();
  String get platformName => platformLabel(platform);
  String get noun => deviceNoun(platform);

  bool get supportsProjects =>
      platform == AppPlatform.macos ||
      platform == AppPlatform.linux ||
      platform == AppPlatform.windows;

  List<CategoryDefinition> get availableCategories =>
      env == null ? const [] : categoriesForPlatform(env!.platform);

  List<String> get projectRoots =>
      env == null ? const [] : resolveProjectRoots(env!, _savedProjectRoots);

  List<String> get defaultProjectRootsList =>
      env == null ? const [] : defaultProjectRoots(env!);

  Future<void> addProjectRoot(String path) async {
    if (env == null) {
      purgeLog('projects', 'add-ignored: $path (env not ready)');
      return;
    }
    final dir = normalize(path);
    if (!Directory(dir).existsSync()) {
      purgeLog('projects', 'add-ignored: $dir (folder not found)');
      return;
    }
    if (_savedProjectRoots.contains(dir)) {
      purgeLog('projects', 'add-ignored: $dir (already saved)');
      return;
    }
    _savedProjectRoots = [..._savedProjectRoots, dir];
    await saveProjectRoots(_savedProjectRoots);
    purgeLog('projects', 'root-added: $dir (${_savedProjectRoots.length} saved)');
    notifyListeners();
  }

  Future<void> removeProjectRoot(String path) async {
    if (!_savedProjectRoots.contains(path)) {
      purgeLog('projects', 'remove-ignored: $path (not a saved root)');
      return;
    }
    _savedProjectRoots = _savedProjectRoots.where((r) => r != path).toList();
    await saveProjectRoots(_savedProjectRoots);
    purgeLog('projects', 'root-removed: $path (${_savedProjectRoots.length} saved)');
    notifyListeners();
  }

  int get totalReclaimableBytes => results
      .where((r) => r.detected)
      .fold<int>(0, (acc, r) => acc + r.totalSizeBytes);

  int get selectedBytes => results
      .where((r) => selected.contains(r.id) && r.detected)
      .fold<int>(0, (acc, r) => acc + r.totalSizeBytes);

  List<ScanResult> get selectedItems =>
      results.where((r) => selected.contains(r.id)).toList();

  /// Enumerates the individual files/folders inside a scan result so the
  /// user can pick specific items to delete instead of the whole category.
  Future<({List<ScanEntry> entries, bool truncated})> itemsFor(ScanResult result) {
    final roots = [
      for (final p in result.paths)
        if (p.exists) p.path,
    ];
    return listEntriesForRoots(roots);
  }

  List<ScanResult> get selectable => results
      .where((r) => r.applicable && (r.detected || r.totalSizeBytes > 0))
      .toList();

  Future<void> init() async {
    purgeLog('app', 'initializing');
    await _loadTheme();
    purgeLog('app', 'theme=$themeMode');
    await _loadLastFreed();
    purgeLog('app', 'lastFreed=restored ${formatBytes(lastFreedBytes)}');
    await _loadSelection();
    purgeLog('app', 'selection=restored ${_savedSelection.length} saved ids');
    await _loadAgeFilter();
    purgeLog('app', 'ageFilter=${ageFilterDays > 0 ? '${ageFilterDays}d' : 'off'}');
    _savedProjectRoots = await loadSavedProjectRoots();
    purgeLog('app', 'saved project roots=${_savedProjectRoots.length}');
    customRoots = await loadCustomRoots();
    purgeLog('app', 'custom roots=${customRoots.length}');
    excludedCategoryIds = (await loadExcludedCategoryIds()).toSet();
    excludedPaths = await loadExcludedPaths();
    purgeLog('app', 'excluded categories=${excludedCategoryIds.length}, paths=${excludedPaths.length}');
    await _loadAutoSettings();
    env = await loadHostEnv();
    if (env!.platform == AppPlatform.android) {
      purgeLog('storage', 'requesting all-files access');
      await requestStorageAccess();
      storageAccessGranted = await isStorageAccessGranted();
      purgeLog('storage', 'all-files access=$storageAccessGranted (granted=${storageAccessGranted ? 'yes' : 'no'})');
    } else {
      purgeLog('storage', 'all-files access skipped (${env!.platform.name})');
    }
    await loadDisk();
    _rebuildCustomCategories();
    ready = true;
    notifyListeners();
    purgeLog('app', 'ready platform=$platformName home=${env!.home} '
        'disk=${formatBytes(disk.totalBytes)} total, ${formatBytes(disk.freeBytes)} free '
        '${env!.platform == AppPlatform.android ? 'AllFilesAccess=$storageAccessGranted' : ''}');
    await _logDeviceDetails();
    TrayBridge.setScanHandler(() {
      if (ready && !scanning && !cleaning) {
        unawaited(scan());
      }
    });
    _restartRescanTimer();
    if (autoScanEnabled) {
      purgeLog('app', 'auto-scan on launch');
      unawaited(scan());
    }
  }

  Future<void> _logDeviceDetails() async {
    final parts = <String>[
      'platform=$platformName',
      'os=${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'dart=${Platform.version}',
      'cpu=${Platform.numberOfProcessors}',
    ];
    if (Platform.isMacOS) {
      try {
        final r = await Process.run('sw_vers', const []);
        final text = '${r.stdout}';
        final v = RegExp(r'ProductVersion:\s*(\S+)').firstMatch(text)?.group(1);
        final b = RegExp(r'BuildVersion:\s*(\S+)').firstMatch(text)?.group(1);
        parts.add('macos=${v ?? '?'}${b != null ? ' ($b)' : ''}');
      } catch (_) {}
    }
    try {
      parts.add('host=${Platform.localHostname}');
    } catch (_) {}
    if (env?.platform == AppPlatform.android) {
      final info = await getDeviceInfo();
      if (info.isNotEmpty) {
        parts.addAll([
          'android=${info['model']}',
          'api=${info['api']}',
          'abis=${info['arch']}',
          'filesAccess=$storageAccessGranted',
        ]);
      }
    }
    purgeLog('device', parts.join(' '));
  }

  Future<void> loadDisk() async {
    if (env == null) return;
    try {
      disk = await getDiskInfo(env!);
      purgeLog('disk', '${formatBytes(disk.totalBytes)} total, '
          '${formatBytes(disk.usedBytes)} used, ${formatBytes(disk.freeBytes)} free '
          '(${disk.volumes.length} volume${disk.volumes.length == 1 ? '' : 's'})');
    } catch (err) {
      disk = DiskInfo.empty;
      purgeLog('disk', 'failed: $err');
    }
    notifyListeners();
  }

  Future<void> scan() async {
    if (env == null || scanning) return;
    if (env!.platform == AppPlatform.android) {
      storageAccessGranted = await isStorageAccessGranted();
      purgeLog('storage', 'all-files access before scan=$storageAccessGranted');
    }
    final baseCats = categoriesForPlatform(env!.platform);
    var cats = [...baseCats];
    if (env!.isDesktop) {
      try {
        final roots = projectRoots;
        purgeLog('projects', 'roots=${roots.length}: ${roots.join(' | ')}');
        final projects = await discoverProjects(roots);
        dynamicCategories = projectCategoryDefinitions(projects);
        if (projects.isNotEmpty) {
          purgeLog('projects', 'found ${projects.length} projects → '
              '${dynamicCategories.length} project categories');
        }
        cats = [...cats, ...dynamicCategories];
      } catch (err) {
        dynamicCategories = const [];
        purgeLog('projects', 'discovery failed: $err');
      }
    }
    _rebuildCustomCategories();
    cats = [...cats, ...customCategories];
    final excludedIds = excludedCategoryIds;
    if (excludedIds.isNotEmpty) {
      cats = cats.where((c) => !excludedIds.contains(c.id)).toList();
      purgeLog('scan', '${cats.length} categories after excluding ${excludedIds.length}');
    }
    scanning = true;
    scanError = null;
    scanDone = 0;
    scanTotal = cats.length;
    scanCurrent = null;
    purgeLog('scan', 'starting scan of $scanTotal categories');
    notifyListeners();
    try {
      results = await scanCategories(
        cats,
        env!,
        excludedPaths: excludedPaths,
        onProgress: (done, total, current) {
          scanDone = done;
          scanTotal = total;
          scanCurrent = current;
          notifyListeners();
        },
      );
      selected
        ..clear()
        ..addAll(_savedSelection.where((id) => results.any((r) => r.id == id)));
      await _saveSelection();
      purgeLog('scan', 'selection restored (${selected.length} item${selected.length == 1 ? '' : 's'} '
          'from ${_savedSelection.length} saved)');
    } catch (err) {
      scanError = err.toString();
      purgeLog('scan', 'failed: $scanError');
    } finally {
      scanCurrent = null;
      scanning = false;
      notifyListeners();
      purgeLog('scan', 'finished — '
          '${totalReclaimableBytes == 0 ? 'nothing found' : '$formatBytes(totalReclaimableBytes) reclaimable'}');
      unawaited(_maybeNotifyReclaimable());
      _updateTraySummary();
    }
  }

  /// Adds/removes the tracked custom folder definitions after roots change.
  void _rebuildCustomCategories() {
    final roots = customRoots
        .where((r) => r.trim().isNotEmpty && Directory(r).existsSync())
        .toList();
    customCategories =
        roots.isEmpty ? const [] : [customFoldersCategory(roots)];
  }

  /// Adds a tracked folder. Returns `true` on success; `false` when the folder
  /// does not exist or is already tracked.
  Future<bool> addCustomRoot(String raw) async {
    final dir = normalizeCustomPath(raw);
    if (dir == null) {
      purgeLog('custom', 'add-ignored: $raw (folder not found)');
      return false;
    }
    if (customRoots.contains(dir)) {
      purgeLog('custom', 'add-ignored: $dir (already tracked)');
      return false;
    }
    customRoots = [...customRoots, dir];
    await saveCustomRoots(customRoots);
    _rebuildCustomCategories();
    purgeLog('custom', 'tracked: $dir (${customRoots.length})');
    notifyListeners();
    return true;
  }

  Future<void> removeCustomRoot(String path) async {
    if (!customRoots.contains(path)) return;
    customRoots = customRoots.where((r) => r != path).toList();
    await saveCustomRoots(customRoots);
    _rebuildCustomCategories();
    purgeLog('custom', 'untracked: $path (${customRoots.length} left)');
    notifyListeners();
  }

  Future<void> toggleExcludedCategory(String id) async {
    final next = {...excludedCategoryIds};
    if (!next.add(id)) next.remove(id);
    excludedCategoryIds = next;
    await saveExcludedCategoryIds(next.toList()..sort());
    purgeLog('exclusions', 'category excluded=${next.contains(id)}: $id');
    notifyListeners();
  }

  /// Adds a path to the blocklist. Returns `true` when it was newly blocked.
  Future<bool> addExcludedPath(String raw) async {
    final path = normalize(raw.trim());
    if (path.isEmpty || path == normalize('~')) {
      purgeLog('exclusions', 'add-ignored: $raw (empty/home)');
      return false;
    }
    if (excludedPaths.contains(path)) {
      purgeLog('exclusions', 'add-ignored: $path (already blocked)');
      return false;
    }
    excludedPaths = [...excludedPaths, path];
    await saveExcludedPaths(excludedPaths);
    purgeLog('exclusions', 'blocked path: $path');
    notifyListeners();
    return true;
  }

  Future<void> removeExcludedPath(String path) async {
    excludedPaths = excludedPaths.where((p) => p != path).toList();
    await saveExcludedPaths(excludedPaths);
    purgeLog('exclusions', 'unblocked path: $path');
    notifyListeners();
  }

void toggle(String id) {
  final adding = !selected.contains(id);
  if (adding) {
    selected.add(id);
  } else {
    selected.remove(id);
  }
  _logSelectionChange('toggle', id, adding);
  unawaited(_saveSelection());
  notifyListeners();
}

void selectAll() {
  selected
    ..clear()
    ..addAll(selectable.map((r) => r.id));
  purgeLog('select', 'select-all → ${selected.length} items (${_selectedLabel()})');
  unawaited(_saveSelection());
  notifyListeners();
}

void selectRecommended() {
  final ids = selectable
      .where((r) => r.safety != SafetyTier.advanced)
      .map((r) => r.id);
  selected
    ..clear()
    ..addAll(ids);
  purgeLog('select', 'select-recommended → ${selected.length} items (${_selectedLabel()})');
  unawaited(_saveSelection());
  notifyListeners();
}

void clearSelection() {
  selected.clear();
  purgeLog('select', 'clear-selection (0 items)');
  unawaited(_saveSelection());
  notifyListeners();
}

Future<void> _saveSelection() async {
  _savedSelection = {...selected};
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('purge.selected_ids', selected.toList()..sort());
  } catch (err) {
    purgeLog('select', 'save failed: $err');
  }
}

Future<void> _loadSelection() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList('purge.selected_ids') ?? const [])
        .where((id) => id.isNotEmpty);
    _savedSelection = ids.toSet();
  } catch (_) {
    _savedSelection = const {};
  }
}

void setAgeFilterDays(int days) {
  if (ageFilterDays == days) return;
  ageFilterDays = days;
  purgeLog('settings', 'age filter → ${days > 0 ? '$days day${days == 1 ? '' : 's'}' : 'off'}');
  unawaited(_saveAgeFilter());
  notifyListeners();
}

Future<void> _saveAgeFilter() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('purge.age_days', ageFilterDays);
  } catch (err) {
    purgeLog('settings', 'age-days save failed: $err');
  }
}

Future<void> _loadAgeFilter() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    ageFilterDays = prefs.getInt('purge.age_days') ?? 0;
  } catch (_) {
    ageFilterDays = 0;
  }
}

void _logSelectionChange(String action, String id, bool added) {
  String? name;
  for (final r in results) {
    if (r.id == id) {
      name = r.name;
      break;
    }
  }
  purgeLog('select', '$action ${added ? '+' : '-'} $id${name != null ? ' ($name)' : ''} '
      '→ ${selected.length} selected (${_selectedLabel()})');
}

String _selectedLabel() {
  final bytes = selectedBytes;
  return '${formatBytes(bytes)} in ${selected.length} item${selected.length == 1 ? '' : 's'}';
}

  Future<void> cleanSelected() async {
    if (env == null || cleaning || selected.isEmpty) {
      purgeLog('clean', 'aborted pre-clean (env=${env != null}, cleaning=$cleaning, '
          'selected=${selected.length})');
      return;
    }
    final ids = selected.toList();
    final byId = {for (final r in results) r.id: r.category};
    final cats = ids.map((id) => byId[id]).whereType<CategoryDefinition>().toList();
    if (cats.isEmpty) return;
    final sizes = {
      for (final r in results)
        if (ids.contains(r.id)) r.id: r.totalSizeBytes,
    };
    await _runClean(
      cats,
      sizes,
      minAge: ageFilterDays > 0 ? Duration(days: ageFilterDays) : null,
    );
  }

  /// Deletes only the given [paths] inside [categoryId], leaving the rest.
  Future<void> cleanSelectedPaths(String categoryId, List<String> paths) async {
    final allowed = applyPathExclusions(paths, excludedPaths);
    if (allowed.isEmpty) {
      purgeLog('clean', 'aborted pre-clean-items ($categoryId): all paths are blocklisted');
      return;
    }
    if (env == null || cleaning || allowed.isEmpty) {
      purgeLog('clean', 'aborted pre-clean-items ($categoryId, items=${allowed.length})');
      return;
    }
    CategoryDefinition? source;
    for (final r in results) {
      if (r.id == categoryId) {
        source = r.category;
        break;
      }
    }
    final pseudo = CategoryDefinition(
      id: categoryId,
      name: source?.name ?? categoryId,
      description: source?.description ?? '',
      safety: source?.safety ?? SafetyTier.moderate,
      tradeoff: source?.tradeoff ?? '',
      platforms: const [],
      getPaths: (_) async => [...allowed],
      cleanCommands: (_) => [
        CleanCommand(
          command: 'rm',
          args: [...allowed],
          label: 'delete ${allowed.length} selected item${allowed.length == 1 ? '' : 's'}',
        ),
      ],
    );
    final before = await sumPathSizes(allowed);
    await _runClean([pseudo], {categoryId: before.totalSizeBytes});
  }

  Future<void> _runClean(
    List<CategoryDefinition> cats,
    Map<String, int> sizes, {
    Duration? minAge,
  }) async {
    cleaning = true;
    _cancel = false;
    events = [];
    cleanStartedAt = DateTime.now();
    cleanDone = 0;
    cleanTotal = 0;
    purgeLog('clean',
        'starting clean of ${cats.map((c) => c.name).join(', ')}'
        '${minAge != null ? ' (age filter: > ${minAge.inDays}d)' : ''}');
    notifyListeners();
    try {
      await runCleanJob(
        categories: cats,
        env: env!,
        measuredSizes: sizes,
        minAge: minAge,
        excludedPaths: excludedPaths,
        onProgress: (event) {
          final idx = events.indexWhere((e) => e.categoryId == event.categoryId);
          if (idx >= 0) {
            events[idx] = event;
          } else {
            events.add(event);
          }
          if (event.done != null) {
            cleanDone = event.done!;
            cleanTotal = event.total ?? cleanTotal;
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
      results = applyCleanToResults(results, events);
      clearSizeCache();
      cleaning = false;
      selected.clear();
      await _saveSelection();
      notifyListeners();
      await loadDisk();
      _updateTraySummary();
      purgeLog('clean', 'finished — ${formatBytes(summary!.totalFreedBytes)} freed '
          '(${summary!.cleaned.length} cleaned, ${summary!.skipped.length} skipped, '
          '${summary!.errored.length} errored)');
      for (final e in events.where((e) => e.status == 'error')) {
        purgeLog('clean', 'error ${e.categoryId}: ${e.label}');
      }
    }
  }

  void cancelClean() {
    _cancel = true;
    purgeLog('clean', 'cancel requested');
    notifyListeners();
  }

  // --------------------------------------------------------- auto settings

  Future<void> setAutoScanEnabled(bool value) async {
    if (autoScanEnabled == value) return;
    autoScanEnabled = value;
    await _saveAutoSettings();
    purgeLog('settings', 'auto-scan=${value ? 'on' : 'off'}');
    _restartRescanTimer();
    notifyListeners();
  }

  Future<void> setAutoScanMinutes(int minutes) async {
    autoScanMinutes = minutes > 0 ? minutes : 30;
    await _saveAutoSettings();
    purgeLog('settings', 'auto-scan interval=$autoScanMinutes min');
    _restartRescanTimer();
    notifyListeners();
  }

  Future<void> setNotifyThresholdBytes(int bytes) async {
    notifyThresholdBytes = bytes > 0 ? bytes : 0;
    _lastNotifiedReclaimable = 0;
    await _saveAutoSettings();
    purgeLog('settings',
        'notify threshold=${notifyThresholdBytes > 0 ? formatBytes(notifyThresholdBytes) : 'off'}');
    notifyListeners();
  }

  Future<void> _loadAutoSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      autoScanEnabled = prefs.getBool('purge.auto_scan_enabled') ?? true;
      autoScanMinutes = prefs.getInt('purge.auto_scan_minutes') ?? 30;
      notifyThresholdBytes = prefs.getInt('purge.notify_threshold_bytes') ?? 0;
    } catch (_) {
      autoScanEnabled = true;
      autoScanMinutes = 30;
      notifyThresholdBytes = 0;
    }
    if (autoScanMinutes <= 0) autoScanMinutes = 30;
  }

  Future<void> _saveAutoSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('purge.auto_scan_enabled', autoScanEnabled);
      await prefs.setInt('purge.auto_scan_minutes', autoScanMinutes);
      await prefs.setInt('purge.notify_threshold_bytes', notifyThresholdBytes);
    } catch (err) {
      purgeLog('settings', 'save failed: $err');
    }
  }

  void _restartRescanTimer() {
    _rescanTimer?.cancel();
    _rescanTimer = null;
    if (!autoScanEnabled || autoScanMinutes <= 0) return;
    _rescanTimer = Timer.periodic(Duration(minutes: autoScanMinutes), (_) {
      if (ready && !scanning && !cleaning) {
        purgeLog('settings', 'scheduled rescan');
        unawaited(scan());
      }
    });
    purgeLog('settings', 'rescan timer every ${autoScanMinutes}min '
        '(autoScan=$autoScanEnabled)');
  }

  Future<void> _maybeNotifyReclaimable() async {
    if (notifyThresholdBytes <= 0) return;
    final reclaimable = totalReclaimableBytes;
    if (reclaimable >= notifyThresholdBytes) {
      if (reclaimable <= _lastNotifiedReclaimable) return;
      _lastNotifiedReclaimable = reclaimable;
      purgeLog('settings', 'reclaimable ${formatBytes(reclaimable)} crosses '
          'threshold ${formatBytes(notifyThresholdBytes)} → notify');
      await notifySystem(
        '${formatBytes(reclaimable)} reclaimable',
        'Purge found regenerable caches you could clean.',
      );
    } else {
      _lastNotifiedReclaimable = 0;
    }
  }

  void _updateTraySummary() {
    if (!Platform.isMacOS) return;
    unawaited(TrayBridge.updateSummary(
      reclaimableBytes: totalReclaimableBytes,
      freeBytes: disk.freeBytes,
      scanning: scanning || cleaning,
    ));
  }

  @override
  void dispose() {
    _rescanTimer?.cancel();
    super.dispose();
  }

  Future<void> cycleTheme() async {
    themeMode = switch (themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    purgeLog('app', 'theme ${switch (themeMode) {
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    }}');
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
      purgeLog('app', 'lastFreed=saved ${formatBytes(bytes)}');
    } catch (err) {
      purgeLog('app', 'lastFreed save failed: $err');
    }
  }
}
