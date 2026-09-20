enum AppPlatform { macos, linux, windows, android, ios }

enum SafetyTier { safe, moderate, advanced }

enum CategoryKind { caches, files }

enum EntryKind { file, directory }

class ScanEntry {
  const ScanEntry({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.kind,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final EntryKind kind;

  String get id => path;
}

enum CategoryStatus { detected, skipped, cleaning, done, cancelled, error }

class CleanCommand {
  const CleanCommand({
    required this.command,
    required this.args,
    this.shell = false,
    this.label,
  });

  final String command;
  final List<String> args;
  final bool shell;
  final String? label;
}

class HostEnv {
  const HostEnv({
    required this.platform,
    required this.home,
    required this.localAppData,
    required this.tempDir,
    required this.cargoHome,
    required this.mobileCachePaths,
  });

  final AppPlatform platform;
  final String home;
  final String localAppData;
  final String tempDir;
  final String cargoHome;
  final List<String> mobileCachePaths;

  bool get isWindows => platform == AppPlatform.windows;
  bool get isMacos => platform == AppPlatform.macos;
  bool get isDesktop =>
      platform == AppPlatform.macos ||
      platform == AppPlatform.linux ||
      platform == AppPlatform.windows;
}

class CategoryDefinition {
  const CategoryDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.safety,
    required this.tradeoff,
    required this.platforms,
    this.toolRequirement,
    required this.getPaths,
    this.getSizeBytes,
    required this.cleanCommands,
    this.onFailureCommands,
    this.skipReason,
    this.kind = CategoryKind.caches,
    this.perPath = false,
  });

  final String id;
  final String name;
  final String description;
  final SafetyTier safety;
  final String tradeoff;
  final List<AppPlatform> platforms;
  final String? toolRequirement;
  final Future<List<String>> Function(HostEnv env) getPaths;
  final Future<int> Function(HostEnv env)? getSizeBytes;
  final List<CleanCommand> Function(HostEnv env) cleanCommands;
  final List<CleanCommand> Function(HostEnv env)? onFailureCommands;
  final Future<String?> Function(HostEnv env)? skipReason;
  final CategoryKind kind;

  /// When true, each path from [getPaths] becomes its own [ScanResult]
  /// (a card per file/folder) instead of being summed into one result.
  final bool perPath;
}

class PathSize {
  const PathSize({
    required this.path,
    required this.sizeBytes,
    required this.exists,
  });

  final String path;
  final int sizeBytes;
  final bool exists;
}

class ScanResult {
  const ScanResult({
    required this.category,
    required this.paths,
    required this.totalSizeBytes,
    required this.applicable,
    required this.detected,
    this.toolMissing = false,
    this.scanHint,
  });

  final CategoryDefinition category;
  final List<PathSize> paths;
  final int totalSizeBytes;
  final bool applicable;
  final bool detected;
  final bool toolMissing;
  final String? scanHint;

  String get id => category.id;
  String get name => category.name;
  String get description => category.description;
  SafetyTier get safety => category.safety;
  String get tradeoff => category.tradeoff;
}

class ToolInfo {
  const ToolInfo({
    required this.name,
    required this.installed,
    this.version,
  });

  final String name;
  final bool installed;
  final String? version;
}

class DiskVolume {
  const DiskVolume({
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

class DiskInfo {
  const DiskInfo({
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
    required this.home,
    required this.filesystem,
    this.volumes = const [],
  });

  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
  final String home;
  final String filesystem;
  final List<DiskVolume> volumes;

  static const empty = DiskInfo(
    totalBytes: 0,
    usedBytes: 0,
    freeBytes: 0,
    home: '',
    filesystem: 'unknown',
  );
}

class CleanProgressEvent {
  const CleanProgressEvent({
    required this.categoryId,
    required this.status,
    this.label,
    this.freedBytes,
    this.done,
    this.total,
  });

  final String categoryId;
  final String status;
  final String? label;
  final int? freedBytes;

  /// Global progress units (completed / total) when this event was emitted,
  /// so the UI can render a gradual bar instead of jumping per category.
  final int? done;
  final int? total;
}

class CleanSummary {
  const CleanSummary({
    required this.totalFreedBytes,
    required this.cleaned,
    required this.skipped,
    required this.errored,
    required this.startedAt,
    required this.finishedAt,
  });

  final int totalFreedBytes;
  final List<String> cleaned;
  final List<String> skipped;
  final List<String> errored;
  final DateTime startedAt;
  final DateTime finishedAt;
}
