import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "dev.purge.app/disk",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "getDiskInfo" {
        let args = call.arguments as? [String: Any]
        let pathStr = (args?["path"] as? String) ?? NSHomeDirectory()
        let url = URL(fileURLWithPath: pathStr)
        do {
          let values = try url.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
          )
          let free = (values.volumeAvailableCapacityForImportantUsage ?? 0)
          let total = Int64(values.volumeTotalCapacity ?? 0)
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

    super.awakeFromNib()
  }
}
