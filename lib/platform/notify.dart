import 'dart:io';

/// Posts a system notification using the platform's native mechanism.
/// Returns `true` when a notification was delivered.
///
/// - macOS: `osascript` → Notification Center (no native changes required).
/// - Linux: `notify-send`.
/// - Other platforms: no-op.
Future<bool> notifySystem(String title, String message) async {
  try {
    if (Platform.isMacOS) {
      final cleanTitle = _escaped(message);
      final cleanBody = _escaped(title);
      final r = await Process.run('osascript', [
        '-e',
        'display notification "$cleanBody" with title "$cleanTitle"',
      ]);
      return r.exitCode == 0;
    }
    if (Platform.isLinux) {
      final r = await Process.run('notify-send', [title, message]);
      return r.exitCode == 0;
    }
  } catch (_) {}
  return false;
}

String _escaped(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', ' ');