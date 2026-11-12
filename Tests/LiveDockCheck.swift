import AppKit

// Runs only on the disposable CI Mac. Compare the real app window with macOS's
// reserved Dock inset, independently of the app's Dock locator.
let args = CommandLine.arguments
let appPID = Int(args[1])!
let side = args[2]
let expectHidden = side == "hidden"
let screen = NSScreen.screens[0]
let display = screen.frame
let dockPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first!.processIdentifier
let level = Int(CGWindowLevelForKey(.dockWindow))
var lastDiagnostic = ""
var matched = false
for _ in 0..<35 {
    let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
    func frames(pid: Int, layer: Int) -> [CGRect] {
        windows.compactMap { w in
            guard w[kCGWindowOwnerPID as String] as? Int == pid,
                  w[kCGWindowLayer as String] as? Int == layer,
                  let b = w[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: b as CFDictionary)
        }
    }
    let docks = frames(pid: Int(dockPID), layer: level)
    let overlays = frames(pid: appPID, layer: level + 1)
    let visible = screen.visibleFrame
    lastDiagnostic = "screen=\(display) usable=\(visible) Dock windows=\(docks) SZNS strips=\(overlays)"
    if expectHidden { matched = overlays.isEmpty }
    else if let panel = overlays.first, overlays.count == 1 {
        switch side {
        case "left":
            matched = visible.minX > display.minX + 15 && abs(panel.maxX - visible.minX) < 10 && panel.height < display.height
        case "right":
            matched = visible.maxX < display.maxX - 15 && abs(panel.minX - visible.maxX) < 10 && panel.height < display.height
        default:
            matched = visible.minY > display.minY + 15 && abs(panel.minY - (display.maxY - visible.minY)) < 10 && panel.width < display.width
        }
    }
    if matched { break }
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
}
print(lastDiagnostic)
guard matched else {
    FileHandle.standardError.write(Data("Dock check failed for \(side): \(lastDiagnostic)\n".utf8))
    exit(1)
}
print("PASS live Dock placement: \(side)")
