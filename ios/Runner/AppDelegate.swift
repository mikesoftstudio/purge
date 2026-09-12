import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(
      name: "dev.purge.app/disk",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "getDiskInfo" {
        let args = call.arguments as? [String: Any]
        let path = (args?["path"] as? String) ?? NSHomeDirectory()
        do {
          let attrs = try FileManager.default.attributesOfFileSystem(forPath: path)
          let total = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
          let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
          result([
            "total": total,
            "free": free,
            "used": total - free,
          ])
        } catch {
          result(FlutterError(code: "stat_failed", message: error.localizedDescription, details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
