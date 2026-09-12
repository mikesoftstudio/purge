import 'package:flutter_test/flutter_test.dart';

import 'package:purge/engine/bytes.dart';
import 'package:purge/engine/disk.dart';

void main() {
  group('parseDfPosixAll', () {
    test('parses every data row and carries the mount point', () {
      const out = '''
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/disk3s1s1  1947277312  21625632 1908917076     2% /
/dev/disk3s5    1947277312 724392672 1222884640    38% /System/Volumes/Data
/dev/disk3s2    1947277312    339244 1913377048     1% /System/Volumes/Preboot
/dev/disk3s4    1947277312    125914 1913453612     1% /System/Volumes/VM
tmpfs              2097152     8192    2088960     1% /run
''';
      final rows = parseDfPosixAll(out);
      expect(rows.length, 5);
      final data = rows[1];
      expect(data.filesystem, '/dev/disk3s5');
      expect(data.mountPoint, '/System/Volumes/Data');
      expect(data.totalBytes, 1947277312 * 1024);
      expect(data.usedBytes, 724392672 * 1024);
    });

    test('skips the header and blank lines', () {
      final rows = parseDfPosixAll('Filesystem Size Used Avail Capacity Mounted on\n');
      expect(rows, isEmpty);
    });
  });

  group('aggregateDf', () {
    const dfOutput = '''
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/disk3s1s1  1947277312  21625632 1908917076     2% /
/dev/disk3s5    1947277312 724392672 1222884640    38% /System/Volumes/Data
/dev/disk3s2    1947277312    339244 1913377048     1% /System/Volumes/Preboot
/dev/disk3s4    1947277312    125914 1913453612     1% /System/Volumes/VM
/dev/loop0         4194304    2097152    2097152    50% /snap/core
tmpfs              2097152     8192    2088960     1% /run
''';

    test('whole-device capacity is the container capacity, free is derived from the largest sibling', () {
      final disk = aggregateDf(
        rows: parseDfPosixAll(dfOutput),
        home: '/Users/test',
      );
      final capacity = 1947277312 * 1024;
      final used = 724392672 * 1024;
      expect(disk.totalBytes, capacity);
      expect(disk.usedBytes, used);
      expect(disk.freeBytes, capacity - used);
    });

    test('excludes loop and non-block filesystems from volumes', () {
      final disk = aggregateDf(
        rows: parseDfPosixAll(dfOutput),
        home: '/Users/test',
      );
      expect(disk.volumes.length, 4);
      expect(disk.volumes.map((v) => v.filesystem), isNot(contains('/dev/loop0')));
    });

    test('a re-mounted snapshot does not inflate used space', () {
      const remounted = '''
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/disk3s3s1  1947277312  21625632 1908917076     2% /
/dev/disk3s5    1947277312 724392672 1222884640    38% /System/Volumes/Data
/dev/disk3s3    1947277312  21625632 1908917076     2% /System/Volumes/Update/mnt1
''';
      final disk = aggregateDf(
        rows: parseDfPosixAll(remounted),
        home: '/System/Volumes/Data/Users/test',
      );
      final capacity = 1947277312 * 1024;
      final free = 1222884640 * 1024;
      expect(disk.totalBytes, capacity);
      expect(disk.freeBytes, free);
      expect(disk.usedBytes, capacity - free);
      expect(disk.volumes.length, 3);
    });

    test('identifies the filesystem containing home', () {
      final disk = aggregateDf(
        rows: parseDfPosixAll(dfOutput),
        home: '/System/Volumes/Data/Users/test',
      );
      expect(disk.filesystem, '/dev/disk3s5');
    });

    test('returns empty DiskInfo when no block volumes are present', () {
      const noDev = '''
Filesystem Size Used Avail Capacity Mounted on
tmpfs 100 50 50 50% /run
''';
      final disk = aggregateDf(rows: parseDfPosixAll(noDev), home: '/home/u');
      expect(disk.totalBytes, 0);
      expect(disk.volumes, isEmpty);
    });
  });
}