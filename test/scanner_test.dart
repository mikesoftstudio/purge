import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:purge/engine/scanner.dart';
import 'package:purge/engine/types.dart';

void main() {
  group('listEntriesForRoots', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('purge_entries_');
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    File file(String relative, int bytes) {
      final f = File('${temp.path}/$relative');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(List<int>.filled(bytes, 0));
      return f;
    }

    test('lists immediate children of a directory root, largest first', () async {
      file('a.dat', 1000);
      file('b.dat', 5000);
      Directory('${temp.path}/sub').createSync();

      final result = await listEntriesForRoots([temp.path]);

      expect(result.truncated, isFalse);
      final names = [for (final e in result.entries) e.name];
      expect(names, containsAll(['a.dat', 'b.dat', 'sub']));
      expect(result.entries.first.name, 'b.dat');
      expect(result.entries.first.kind, EntryKind.file);
      expect(
        result.entries.map((e) => e.kind).where((k) => k == EntryKind.directory),
        hasLength(1),
      );
    });

    test('sizes directories with the same walk used by the scanner', () async {
      final dir = Directory('${temp.path}/sub');
      dir.createSync();
      final f = File('${dir.path}/inner.bin');
      f.writeAsBytesSync(List<int>.filled(4096, 0));

      final result = await listEntriesForRoots([temp.path]);
      final sub = result.entries.firstWhere((e) => e.name == 'sub');

      expect(sub.kind, EntryKind.directory);
      expect(sub.sizeBytes, greaterThan(0));
      expect(sub.sizeBytes, greaterThanOrEqualTo(4096));
    });

    test('a file root is listed by itself', () async {
      final f = file('single.bin', 2048);

      final result = await listEntriesForRoots([f.path]);

      expect(result.entries, hasLength(1));
      expect(result.entries.single.name, 'single.bin');
      expect(result.entries.single.kind, EntryKind.file);
      expect(result.entries.single.sizeBytes, 2048);
    });

    test('missing roots are ignored', () async {
      final result = await listEntriesForRoots(['${temp.path}/missing']);

      expect(result.entries, isEmpty);
      expect(result.truncated, isFalse);
    });

    test('caps the number of displayed entries', () async {
      for (var i = 0; i < 300; i++) {
        file('f$i.bin', 10);
      }

      final result = await listEntriesForRoots([temp.path]);

      expect(result.entries, hasLength(150));
      expect(result.truncated, isTrue);
    });
  });

  group('applyPathExclusions', () {
    test('keeps paths that are not blocked', () {
      final out = applyPathExclusions(
        ['/a/bin', '/b/cache', '/c/free'],
        ['/b/cache'],
      );
      expect(out, ['/a/bin', '/c/free']);
    });

    test('drops everything nested beneath a blocked path', () {
      final out = applyPathExclusions(
        ['/b', '/b/cache', '/b/cache/nested', '/a/free'],
        ['/b/cache'],
      );
      expect(out, ['/b', '/a/free']);
    });

    test('an exact full-name match is only dropped for that path', () {
      final out = applyPathExclusions(
        ['/cache', '/cache-extra', '/cache/child'],
        ['/cache'],
      );
      expect(out, ['/cache-extra'], reason: '/cache-extra is not nested');
    });

    test('empty exclusions leave the list untouched', () {
      final paths = <String>['/a'];
      expect(applyPathExclusions(paths, const []), same(paths));
    });
  });

  group('sizeOfPath mtime cache', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('purge_sizeof_');
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('reports the on-disk size of a file', () async {
      final f = File('${temp.path}/payload.bin');
      f.writeAsBytesSync(List<int>.filled(4096, 0));
      final size = await sizeOfPath(f.path);
      expect(size, greaterThanOrEqualTo(4096));
    });

    test('refreshes when the file grows (mtime changes)', () async {
      final f = File('${temp.path}/grow.bin');
      f.writeAsBytesSync(List<int>.filled(1024, 0));
      final first = await sizeOfPath(f.path);
      expect(first, greaterThanOrEqualTo(1024));

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      f.writeAsBytesSync(List<int>.filled(8192, 0));
      final second = await sizeOfPath(f.path);

      expect(second, greaterThanOrEqualTo(8192),
          reason: 'mtime should differ, so the cached size is replaced');
    });

    test('clearSizeCache keeps future reads working', () async {
      final f = File('${temp.path}/clean.bin');
      f.writeAsBytesSync(List<int>.filled(64, 0));
      await sizeOfPath(f.path);
      clearSizeCache();
      invalidateSizeCache(f.path);
      final after = await sizeOfPath(f.path);
      expect(after, greaterThanOrEqualTo(64));
    });
  });
}