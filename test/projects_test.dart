import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:purge/engine/projects.dart';
import 'package:purge/engine/types.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('purge_projects_test_');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Directory dir(String relative) {
    final d = Directory('${temp.path}/$relative');
    d.createSync(recursive: true);
    return d;
  }

  void file(String relative) {
    File('${temp.path}/$relative')
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');
  }

  group('tilde expansion', () {
    test('expandHome resolves ~ to the home directory', () {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      expect(home, isNotNull);
      expect(expandHome('~/src'), p.join(home!, 'src'));
      expect(expandHome('~'), home);
      expect(expandHome('/abs/path'), '/abs/path');
    });

    test('normalize expands a leading tilde', () {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      expect(home, isNotNull);
      expect(normalize('~/Downloads'), p.join(home!, 'Downloads'));
    });
  });

  group('discoverProjects', () {
    test('finds projects by marker at bounded depth, skipping tool dirs', () async {
      dir('project-a/node_modules');
      file('project-a/package.json');
      dir('project-b/subproject/.dart_tool');
      file('project-b/subproject/pubspec.yaml');
      file('project-c/go.mod');

      final projects = await discoverProjects([temp.path]);
      final names = projects.map((p) => p.name).toSet();
      expect(names, containsAll(['project-a', 'subproject', 'project-c']));
      expect(names, isNot(contains('node_modules')));
      expect(names, isNot(contains('.dart_tool')));
    });

    test('does not descend into a project to find nested ones', () async {
      file('outer/pubspec.yaml');
      file('outer/inner/go.mod');

      final projects = await discoverProjects([temp.path]);
      final names = projects.map((p) => p.name).toList();
      expect(names, contains('outer'));
      expect(names, isNot(contains('inner')));
    });

    test('skips hidden directories', () async {
      file('.hidden/go.mod');

      final projects = await discoverProjects([temp.path]);
      expect(projects, isEmpty);
    });

    test('honours the surrogate marker suffixes', () async {
      file('app/MyApp.csproj');
      dir('mac/MacApp.xcodeproj');

      final projects = await discoverProjects([temp.path]);
      final markers = projects.map((p) => p.marker).toSet();
      expect(markers, containsAll(['MyApp.csproj', 'MacApp.xcodeproj']));
    });

    test('does not treat a project root as a nested project', () async {
      file('pubspec.yaml');
      final projects = await discoverProjects([temp.path]);
      expect(projects.length, 1);
      expect(projects.single.path, temp.path);
    });

    test('deduplicates the same project reached from overlapping roots', () async {
      file('project-a/package.json');
      final projectRoot = '${temp.path}/project-a';

      final projects = await discoverProjects([temp.path, projectRoot]);
      final paths = projects.map((p) => p.path).toList();
      expect(paths.where((x) => x == projectRoot).length, 1,
          reason: 'the same project must not be discovered twice');
    });
  });

  group('projectCacheDirs', () {
    ProjectFound project(String marker) => ProjectFound(
          root: temp.path,
          path: temp.path,
          name: 'proj',
          marker: marker,
        );

    test('classifies build outputs safe and dependency trees moderate', () {
      dir('build');
      dir('dist');
      dir('node_modules');
      dir('.dart_tool');

      final dirs = projectCacheDirs(project('package.json'));
      final safe = dirs.where((d) => d.tier == SafetyTier.safe).map((d) => d.name).toSet();
      final moderate = dirs.where((d) => d.tier == SafetyTier.moderate).map((d) => d.name).toSet();
      expect(safe, containsAll(['build', 'dist']));
      expect(moderate, containsAll(['node_modules', '.dart_tool']));
    });

    test('excludes source-adjacent bin/obj unless the project is .NET', () {
      dir('bin');
      dir('obj');
      expect(projectCacheDirs(project('package.json')), isEmpty);

      dir('bin');
      dir('obj');
      final dotnet = projectCacheDirs(project('MyApp.csproj'));
      expect(dotnet.map((d) => d.name), containsAll(['bin', 'obj']));
    });

    test('ignores unrelated directories', () {
      dir('src');
      dir('docs');
      expect(projectCacheDirs(project('package.json')), isEmpty);
    });
  });

  group('projectCategoryDefinitions', () {
    ProjectFound project(String marker) => ProjectFound(
          root: temp.path,
          path: temp.path,
          name: 'myproj',
          marker: marker,
        );

    test('generates separate safe and moderate categories', () {
      dir('build');
      dir('node_modules');
      final defs = projectCategoryDefinitions([project('package.json')]);

      expect(defs.length, 2);
      final build = defs.singleWhere((d) => d.safety == SafetyTier.safe);
      final deps = defs.singleWhere((d) => d.safety == SafetyTier.moderate);

      expect(build.id, 'project:${temp.path}:build');
      expect(deps.id, 'project:${temp.path}:deps');
      expect(build.platforms, isNot(contains(AppPlatform.android)));
      expect(deps.platforms, isNot(contains(AppPlatform.ios)));
    });

    test('emits clean commands for each targeted folder', () async {
      dir('build');
      dir('dist');
      dir('node_modules');
      final defs = projectCategoryDefinitions([project('package.json')]);
      final build = defs.singleWhere((d) => d.safety == SafetyTier.safe);
      final cmds = build.cleanCommands(const HostEnv(
        platform: AppPlatform.macos,
        home: '/tmp',
        localAppData: '/tmp',
        tempDir: '/tmp',
        cargoHome: '/tmp',
        mobileCachePaths: [],
      ));
      expect(cmds.length, 2);
      expect(cmds.every((c) => c.command == 'rm' && c.args.first == '-rf'), isTrue);
      expect(cmds.map((c) => c.label), containsAll(['remove build', 'remove dist']));

      final paths = await build.getPaths(const HostEnv(
        platform: AppPlatform.macos,
        home: '/tmp',
        localAppData: '/tmp',
        tempDir: '/tmp',
        cargoHome: '/tmp',
        mobileCachePaths: [],
      ));
      expect(paths, containsAll(['${temp.path}/build', '${temp.path}/dist']));
    });

    test('returns empty for a project with no cache dirs', () {
      dir('src');
      expect(projectCategoryDefinitions([project('package.json')]), isEmpty);
    });
  });
}