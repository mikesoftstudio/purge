const _siFactors = {
  'b': 1.0,
  'k': 1e3,
  'kb': 1e3,
  'm': 1e6,
  'mb': 1e6,
  'g': 1e9,
  'gb': 1e9,
  't': 1e12,
  'tb': 1e12,
  'p': 1e15,
  'pb': 1e15,
};

const _binaryFactors = {
  'b': 1.0,
  'k': 1024.0,
  'kb': 1024.0,
  'kib': 1024.0,
  'm': 1024.0 * 1024,
  'mb': 1024.0 * 1024,
  'mib': 1024.0 * 1024,
  'g': 1024.0 * 1024 * 1024,
  'gb': 1024.0 * 1024 * 1024,
  'gib': 1024.0 * 1024 * 1024,
  't': 1024.0 * 1024 * 1024 * 1024,
  'tb': 1024.0 * 1024 * 1024 * 1024,
  'tib': 1024.0 * 1024 * 1024 * 1024,
  'p': 1024.0 * 1024 * 1024 * 1024 * 1024,
  'pb': 1024.0 * 1024 * 1024 * 1024 * 1024,
  'pib': 1024.0 * 1024 * 1024 * 1024 * 1024,
};

int parseHumanSize(String text, Map<String, double> factors) {
  final cleaned = text.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
  final match = RegExp(r'([\d.]+)\s*([a-z]+)?', caseSensitive: false).firstMatch(cleaned);
  if (match == null) return 0;
  final value = double.tryParse(match.group(1)!) ?? double.nan;
  if (value.isNaN || value < 0) return 0;
  final unit = (match.group(2) ?? 'b').toLowerCase();
  final factor = factors[unit] ?? 0;
  if (factor == 0) return 0;
  return (value * factor).round();
}

int parseDockerSize(String text) => parseHumanSize(text, _siFactors);

int parseBinarySize(String text) => parseHumanSize(text, _binaryFactors);

int? parseDuKilobytes(String stdout) {
  final first = stdout.trim().split(RegExp(r'\s+')).first;
  if (first.isEmpty) return null;
  final k = int.tryParse(first);
  if (k == null || k < 0) return null;
  return k;
}

class DfSizes {
  const DfSizes({
    required this.filesystem,
    required this.mountPoint,
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
  });

  final String filesystem;
  final String mountPoint;
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
}

DfSizes? parseDfPosixLine(String line) {
  final match = RegExp(r'^(.*?)\s+(\d+)\s+(\d+)\s+(\d+)\s+\d+%\s+(.*)$').firstMatch(line);
  if (match == null) return null;
  final totalKb = int.tryParse(match.group(2)!);
  final usedKb = int.tryParse(match.group(3)!);
  final availKb = int.tryParse(match.group(4)!);
  if (totalKb == null || usedKb == null || availKb == null) return null;
  if (totalKb < 0 || usedKb < 0 || availKb < 0) return null;
  final filesystem = match.group(1)!.trim();
  return DfSizes(
    filesystem: filesystem.isNotEmpty ? filesystem : match.group(5)!.trim(),
    mountPoint: match.group(5)!.trim(),
    totalBytes: totalKb * 1024,
    usedBytes: usedKb * 1024,
    freeBytes: availKb * 1024,
  );
}

List<DfSizes> parseDfPosixAll(String stdout) {
  final rows = <DfSizes>[];
  var first = true;
  for (final line in stdout.trim().split('\n')) {
    if (line.trim().isEmpty) continue;
    if (first) {
      first = false;
      continue;
    }
    final s = parseDfPosixLine(line);
    if (s != null) rows.add(s);
  }
  return rows;
}

int finiteBytes(int n) => n > 0 ? n : 0;

String formatBytes(int bytes) => _formatByteValue(bytes, const ['B', 'KB', 'MB', 'GB', 'TB'], ' ');

String formatBytesShort(int bytes) => _formatByteValue(bytes, const ['B', 'K', 'M', 'G', 'T'], '');

String _formatByteValue(int bytes, List<String> units, String spacer) {
  if (bytes <= 0) return '0 B';
  var i = (bytes.bitLength - 1) ~/ 10;
  if (i < 0) i = 0;
  if (i >= units.length) i = units.length - 1;
  final value = bytes / (1 << (i * 10));
  final shown = i == 0
      ? value.round().toString()
      : value >= 100
          ? value.toStringAsFixed(0)
          : value >= 10
              ? value.toStringAsFixed(1)
              : value.toStringAsFixed(2);
  return '$shown$spacer${units[i]}';
}
