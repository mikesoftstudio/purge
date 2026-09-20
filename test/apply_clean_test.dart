import 'package:flutter_test/flutter_test.dart';

import 'package:purge/engine/cleaner.dart';
import 'package:purge/engine/types.dart';

ScanResult _result(
  String id, {
  int size = 0,
  bool detected = false,
  bool applicable = true,
}) {
  final category = CategoryDefinition(
    id: id,
    name: id,
    description: '',
    safety: SafetyTier.safe,
    tradeoff: '',
    platforms: const [AppPlatform.macos],
    getPaths: (_) async => const [],
    cleanCommands: (_) => const [],
  );
  return ScanResult(
    category: category,
    paths: const [],
    totalSizeBytes: size,
    applicable: applicable,
    detected: detected,
  );
}

void main() {
  group('applyCleanToResults', () {
    test('subtracts freed bytes from cleaned categories', () {
      final results = [
        _result('npm', size: 1024, detected: true),
        _result('brew', size: 2048, detected: true),
        _result('docker', size: 4096, detected: true),
      ];
      final events = [
        const CleanProgressEvent(
            categoryId: 'npm', status: 'done', freedBytes: 400),
        const CleanProgressEvent(
            categoryId: 'brew', status: 'done', freedBytes: 2048),
        const CleanProgressEvent(categoryId: 'docker', status: 'error'),
      ];
      final updated = applyCleanToResults(results, events);
      expect(updated[0].totalSizeBytes, 624);
      expect(updated[0].detected, isTrue);
      expect(updated[1].totalSizeBytes, 0);
      expect(updated[1].detected, isFalse);
      expect(updated[2].totalSizeBytes, 4096);
    });

    test('sums repeated events for the same category', () {
      final results = [_result('gradle', size: 1000, detected: true)];
      final events = [
        const CleanProgressEvent(categoryId: 'gradle', status: 'done', freedBytes: 300),
        const CleanProgressEvent(categoryId: 'gradle', status: 'done', freedBytes: 200),
      ];
      final updated = applyCleanToResults(results, events);
      expect(updated.single.totalSizeBytes, 500);
    });

    test('ignores events for unknown categories', () {
      final results = [_result('pip', size: 100, detected: true)];
      final events = [
        const CleanProgressEvent(categoryId: 'nope', status: 'done', freedBytes: 100),
      ];
      final updated = applyCleanToResults(results, events);
      expect(updated.single.totalSizeBytes, 100);
    });

    test('returns the same list when nothing was freed', () {
      final results = [_result('go', size: 10, detected: true)];
      final events = <CleanProgressEvent>[];
      expect(applyCleanToResults(results, events), same(results));
    });
  });
}