import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'host.dart';
import 'types.dart';

const _projectPlatforms = [
  AppPlatform.macos,
  AppPlatform.linux,
  AppPlatform.windows,
];

const _markers = [
  'package.json',
  'pubspec.yaml',
  'Cargo.toml',
  'go.mod',
  'composer.json',
  'requirements.txt',
  'pyproject.toml',
  'setup.py',
  'Gemfile',
  'Podfile',
  'pom.xml',
  'build.gradle',
  'build.gradle.kts',
  'settings.gradle',
];

const _markerSuffixes = ['.csproj', '.sln', '.fsproj', '.xcodeproj', '.xcworkspace'];

const _cacheDirTiers = <String, SafetyTier>{
  'build': SafetyTier.safe,
  'dist': SafetyTier.safe,
  'out': SafetyTier.safe,
  'target': SafetyTier.safe,
  'bin': SafetyTier.safe,
  'obj': SafetyTier.safe,
  '.next': SafetyTier.safe,
  '.nuxt': SafetyTier.safe,
  'cmake-build-debug': SafetyTier.safe,
  'cmake-build-release': SafetyTier.safe,
  '__pycache__': SafetyTier.safe,
  '.pytest_cache': SafetyTier.safe,
  '.mypy_cache': SafetyTier.safe,
  '.ruff_cache': SafetyTier.safe,
  'node_modules': SafetyTier.moderate,
  'Pods': SafetyTier.moderate,
  'vendor': SafetyTier.moderate,
  '.venv': SafetyTier.moderate,
  'venv': SafetyTier.moderate,
  '.dart_tool': SafetyTier.moderate,
  '.gradle': SafetyTier.moderate,
  'bower_components': SafetyTier.moderate,
  'jspm_packages': SafetyTier.moderate,
  'stack-work': SafetyTier.moderate,
};

const _skipDirNames = {
  '.git', '.svn', '.hg', '.bzr',
  '.idea', '.vscode',
  '.cache', '.pub-cache', 'Caches', 'Library',
  'node_modules', 'build', 'dist', 'out', 'target', '.next', '.nuxt',
  'Pods', '.venv', 'venv', '.dart_tool', '.gradle', 'vendor',
  'bower_components', 'jspm_packages', 'stack-work',
};

List<String> defaultProjectRoots(HostEnv env) {
  final candidates = <List<String>>[
    ['Projects'],
    ['Developer'],
    ['dev'],
    ['src'],
    ['Code'],
    ['Work'],
    ['Documents', 'Projects'],
    ['Documents', 'dev'],
  ];
  if (env.isWindows) {
    final seen = <String>{};
    final roots = <String>[];
    for (final d in ['source', 'source/repos', 'Projects', 'dev', 'Documents/Projects']) {
      final dir = normalize(p.joinAll([env.home, d]));
      if (_isDir(dir) && seen.add(dir)) roots.add(dir);
    }
    return roots;
  }
  final seen = <String>{};
  final roots = <String>[];
  for (final parts in candidates) {
    final dir = normalize(homePath(env, parts));
    if (_isDir(dir) && seen.add(dir)) roots.add(dir);
  }
  return roots;
}

List<String> resolveProjectRoots(HostEnv env, List<String> saved) {
  final roots = <String>{...defaultProjectRoots(env)};
  for (final r in saved) {
    final dir = normalize(r);
    if (!_isDir(dir)) continue;
    roots.add(dir);
  }
  final list = roots.toList()..sort();
  return list;
}

Future<List<String>> loadSavedProjectRoots() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('purge.project_roots') ?? const [];
  } catch (_) {
    return const [];
  }
}

Future<void> saveProjectRoots(List<String> roots) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('purge.project_roots', roots);
  } catch (_) {}
}

bool _isDir(String path) {
  try {
    return FileSystemEntity.isDirectorySync(path);
  } catch (_) {
    return false;
  }
}

String expandHome(String path) {
  if (!path.startsWith('~')) return path;
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'];
  if (home == null || home.isEmpty) return path;
  if (path == '~') return home;
  final rest = (path.startsWith('~/') || path.startsWith(r'~\'))
      ? path.substring(2)
      : path.substring(1);
  return p.joinAll([home, rest]);
}

String normalize(String path) => p.normalize(expandHome(path));

class ProjectFound {
  const ProjectFound({
    required this.root,
    required this.path,
    required this.name,
    required this.marker,
  });

  final String root;
  final String path;
  final String name;
  final String marker;
}

Future<List<ProjectFound>> discoverProjects(List<String> roots) async {
  final seen = <String>{};
  final projects = <ProjectFound>[];
  for (final root in roots) {
    final dir = normalize(root);
    if (!_isDir(dir)) continue;
    _scanDir(dir, projects, 0, seen);
  }
  projects.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return projects;
}

void _scanDir(String dir, List<ProjectFound> out, int depth, Set<String> seen) {
  if (depth > 6) return;
  final Directory d;
  try {
    d = Directory(dir);
    if (!d.existsSync()) return;
  } catch (_) {
    return;
  }
  final List<FileSystemEntity> entries;
  try {
    entries = d.listSync(followLinks: false);
  } catch (_) {
    return;
  }
  final marker = _findMarker(entries);
  if (marker != null) {
    final normalized = p.normalize(dir);
    if (seen.add(normalized)) {
      out.add(ProjectFound(
        root: dir,
        path: dir,
        name: p.basename(dir),
        marker: marker,
      ));
    }
    return;
  }
  for (final e in entries) {
    if (e is! Directory) continue;
    final name = p.basename(e.path);
    if (name.startsWith('.')) continue;
    if (_skipDirNames.contains(name)) continue;
    _scanDir(e.path, out, depth + 1, seen);
  }
}

String? _findMarker(List<FileSystemEntity> entries) {
  for (final e in entries) {
    final name = p.basename(e.path);
    if (_markers.contains(name)) return name;
    for (final suffix in _markerSuffixes) {
      if (name.endsWith(suffix)) return name;
    }
  }
  return null;
}

class ProjectCacheDir {
  const ProjectCacheDir({
    required this.path,
    required this.name,
    required this.tier,
  });

  final String path;
  final String name;
  final SafetyTier tier;
}

List<ProjectCacheDir> projectCacheDirs(ProjectFound project) {
  final Directory d;
  try {
    d = Directory(project.path);
    if (!d.existsSync()) return const [];
  } catch (_) {
    return const [];
  }
  final List<FileSystemEntity> entries;
  try {
    entries = d.listSync(followLinks: false);
  } catch (_) {
    return const [];
  }
  final isDotnet = project.marker.endsWith('.csproj') ||
      project.marker.endsWith('.sln') ||
      project.marker.endsWith('.fsproj');
  final dirs = <ProjectCacheDir>[];
  for (final e in entries) {
    if (e is! Directory) continue;
    final name = p.basename(e.path);
    final tier = _cacheDirTiers[name];
    if (tier == null) continue;
    if ((name == 'bin' || name == 'obj') && !isDotnet) continue;
    dirs.add(ProjectCacheDir(path: e.path, name: name, tier: tier));
  }
  dirs.sort((a, b) {
    final byTier = a.tier.index.compareTo(b.tier.index);
    return byTier != 0 ? byTier : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return dirs;
}

List<CategoryDefinition> projectCategoryDefinitions(List<ProjectFound> projects) {
  if (projects.isEmpty) return const [];
  final defs = <CategoryDefinition>[];
  for (final project in projects) {
    final dirs = projectCacheDirs(project);
    if (dirs.isEmpty) continue;
    final buildDirs = dirs.where((d) => d.tier == SafetyTier.safe).toList();
    if (buildDirs.isNotEmpty) {
      defs.add(_makeProjectCategory(
        project: project,
        suffix: 'build',
        displayName: '${project.name} · build outputs',
        tier: SafetyTier.safe,
        tradeoff: 'Build and generated artifacts that are recreated the next time you build the project.',
        dirs: buildDirs,
      ));
    }
    final depsDirs = dirs.where((d) => d.tier == SafetyTier.moderate).toList();
    if (depsDirs.isNotEmpty) {
      defs.add(_makeProjectCategory(
        project: project,
        suffix: 'deps',
        displayName: '${project.name} · dependencies',
        tier: SafetyTier.moderate,
        tradeoff: 'Dependencies that are re-downloaded and reinstalled the next time you install or build the project.',
        dirs: depsDirs,
      ));
    }
  }
  return defs;
}

CategoryDefinition _makeProjectCategory({
  required ProjectFound project,
  required String suffix,
  required String displayName,
  required SafetyTier tier,
  required String tradeoff,
  required List<ProjectCacheDir> dirs,
}) {
  final paths = dirs.map((d) => d.path).toList();
  return CategoryDefinition(
    id: 'project:${project.path}:$suffix',
    name: displayName,
    description: project.path,
    safety: tier,
    tradeoff: tradeoff,
    platforms: _projectPlatforms,
    getPaths: (_) async => paths,
    cleanCommands: (_) => [
      for (final path in paths)
        CleanCommand(
          command: 'rm',
          args: ['-rf', path],
          label: 'remove ${p.basename(path)}',
        ),
    ],
  );
}