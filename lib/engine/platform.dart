import 'dart:io';

import 'types.dart';

AppPlatform detectPlatform() {
  if (Platform.isMacOS) return AppPlatform.macos;
  if (Platform.isWindows) return AppPlatform.windows;
  if (Platform.isAndroid) return AppPlatform.android;
  if (Platform.isIOS) return AppPlatform.ios;
  if (Platform.isLinux) {
    if (Platform.environment.containsKey('TERMUX_VERSION')) {
      return AppPlatform.android;
    }
    if (Directory('/data/data/com.termux/files/home').existsSync()) {
      return AppPlatform.android;
    }
    if (Directory('/var/mobile').existsSync()) return AppPlatform.ios;
    return AppPlatform.linux;
  }
  return AppPlatform.linux;
}

const _pretty = {
  AppPlatform.macos: 'macOS',
  AppPlatform.linux: 'Linux',
  AppPlatform.windows: 'Windows',
  AppPlatform.android: 'Android',
  AppPlatform.ios: 'iOS',
};

String platformLabel(AppPlatform p) => _pretty[p] ?? 'Device';

String deviceNoun(AppPlatform p) {
  switch (p) {
    case AppPlatform.macos:
      return 'Mac';
    case AppPlatform.windows:
      return 'PC';
    default:
      return 'device';
  }
}

bool get canSpawnProcesses =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;
