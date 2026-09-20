import 'dart:io';

import 'package:flutter/services.dart';

/// Bridges to the macOS menu-bar status item (see `StatusItemController.swift`).
///
/// All calls are defensive: if the channel is not registered (non-macOS, or the
/// native side failed to start) they silently no-op so the app keeps working.
class TrayBridge {
  TrayBridge._();

  static const _channel = MethodChannel('purge/tray');

  /// Listens for "scan" commands sent from the status item's menu.
  static void setScanHandler(void Function() onScan) {
    if (!Platform.isMacOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'scan') onScan();
    });
  }

  static Future<void> updateSummary({
    required int reclaimableBytes,
    required int freeBytes,
    required bool scanning,
  }) async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('updateSummary', {
        'reclaimable': reclaimableBytes,
        'free': freeBytes,
        'scanning': scanning,
      });
    } catch (_) {}
  }

  static Future<void> reset() async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('reset');
    } catch (_) {}
  }
}