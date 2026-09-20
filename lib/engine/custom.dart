import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'projects.dart';
import 'types.dart';

const _customPlatforms = [
  AppPlatform.macos,
  AppPlatform.linux,
  AppPlatform.windows,
];

/// One per-path category that turns every user-tracked folder into its own
/// selectable card (mirrors how `large-files` and project caches work).
CategoryDefinition customFoldersCategory(List<String> roots) {
  return CategoryDefinition(
    id: 'custom-folders',
    name: 'Custom folders',
    description: 'Folders you asked Purge to track.',
    safety: SafetyTier.moderate,
    tradeoff:
        'Your own build/cache folders. Only remove the ones you are sure about.',
    platforms: _customPlatforms,
    kind: CategoryKind.caches,
    perPath: true,
    getPaths: (_) async => roots,
    cleanCommands: (env) => [
      for (final root in roots)
        CleanCommand(
          command: 'rm',
          args: ['-rf', '$root/*'],
          shell: true,
          label: 'clear ${root.split(Platform.pathSeparator).last}',
        ),
    ],
  );
}

Future<List<String>> loadCustomRoots() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('purge.custom_roots') ?? const [];
  } catch (_) {
    return const [];
  }
}

Future<void> saveCustomRoots(List<String> roots) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('purge.custom_roots', roots);
  } catch (_) {}
}

Future<List<String>> loadExcludedCategoryIds() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('purge.excluded_categories') ?? const [];
  } catch (_) {
    return const [];
  }
}

Future<void> saveExcludedCategoryIds(List<String> ids) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('purge.excluded_categories', ids);
  } catch (_) {}
}

Future<List<String>> loadExcludedPaths() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('purge.excluded_paths') ?? const [];
  } catch (_) {
    return const [];
  }
}

Future<void> saveExcludedPaths(List<String> paths) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('purge.excluded_paths', paths);
  } catch (_) {}
}

/// Normalizes a user-typed folder path and rejects ones that do not exist.
String? normalizeCustomPath(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final dir = normalize(trimmed);
  if (dir.isEmpty) return null;
  if (!Directory(dir).existsSync()) return null;
  return dir;
}