import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let statusItemController = StatusItemController()

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    guard
      let windows = NSApp.windows.first(where: { $0.contentViewController is FlutterViewController }),
      let flutterViewController = windows.contentViewController as? FlutterViewController
    else {
      return
    }
    statusItemController.attach(messenger: flutterViewController.engine.binaryMessenger)
  }
}

/// Menu-bar status item that mirrors Purge's scan summary and offers
/// Scan now / Open Purge / Quit actions.
class StatusItemController: NSObject {
  private let channelName = "purge/tray"

  private var statusItem: NSStatusItem?
  private var summaryText = "Purge"
  private var scanChannel: FlutterMethodChannel?

  func attach(messenger: FlutterBinaryMessenger) {
    scanChannel = FlutterMethodChannel(
      name: channelName, binaryMessenger: messenger)
    scanChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "updateSummary":
        if let args = call.arguments as? [String: Any] {
          self?.updateSummary(bytes: args["reclaimable"] as? Int64 ?? 0,
                              freeBytes: args["free"] as? Int64 ?? 0,
                              scanning: args["scanning"] as? Bool ?? false)
        }
        result(nil)
      case "reset":
        self?.reset()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    buildStatusItem()
  }

  private func buildStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.imagePosition = .imageLeading
    updateIcon(for: 0)
    if let button = item.button {
      button.target = self
      button.action = #selector(showMenu(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    statusItem = item
  }

  private func updateIcon(for reclaimable: Int64) {
    guard let button = statusItem?.button else { return }
    let size = NSSize(width: 16, height: 16)
    let image = NSImage(size: size)
    image.lockFocus()
    let dot = NSBezierPath(ovalIn: NSRect(x: 4, y: 4, width: 8, height: 8))
    if reclaimable > 0 {
      NSColor.black.setFill()
      dot.fill()
    } else {
      NSColor.black.setStroke()
      dot.lineWidth = 1.5
      dot.stroke()
    }
    image.unlockFocus()
    image.isTemplate = true
    button.image = image
  }

  private func updateSummary(bytes: Int64, freeBytes: Int64, scanning: Bool) {
    updateIcon(for: bytes)
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.allowedUnits = [.useAll]
    let free = formatter.string(fromByteCount: freeBytes)
    let status: String
    if scanning {
      status = "Scanning…"
    } else if bytes > 0 {
      status = "\(formatter.string(fromByteCount: bytes)) reclaimable"
    } else {
      status = "nothing found"
    }
    summaryText = "\(status) · \(free) free"
  }

  private func reset() {
    updateSummary(bytes: 0, freeBytes: 0, scanning: false)
  }

  @objc private func showMenu(_ sender: Any?) {
    guard let button = statusItem?.button else { return }
    let menu = NSMenu()
    menu.addItem(withTitle: summaryText, action: nil, keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(withTitle: "Scan now", action: #selector(scanNow), keyEquivalent: "r")
    menu.addItem(withTitle: "Open Purge", action: #selector(openPurge), keyEquivalent: "o")
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit Purge", action: #selector(quitPurge), keyEquivalent: "q")
    statusItem?.menu = menu
    button.performClick(nil)
  }

  @objc private func scanNow() {
    statusItem?.menu = nil
    scanChannel?.invokeMethod("scan", arguments: nil)
  }

  @objc private func openPurge() {
    statusItem?.menu = nil
    NSApp.activate(ignoringOtherApps: true)
    if let window = NSApp.windows.first(where: { $0.isVisible }) {
      window.makeKeyAndOrderFront(nil)
    }
  }

  @objc private func quitPurge() {
    statusItem?.menu = nil
    NSApp.terminate(nil)
  }
}