import AppKit
import ApplicationServices

// Runs only on the disposable CI Mac. Compare the real app window with macOS's
// reserved Dock inset, independently of the app's Dock locator.
let args = CommandLine.arguments
let appPID = Int(args[1])!
let side = args[2]
let expectHidden = side == "hidden"
let reveal = side == "reveal"
let screen = NSScreen.screens[0]
let display = screen.frame
let dockPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first!.processIdentifier
let level = Int(CGWindowLevelForKey(.dockWindow))
func movePointer(x: CGFloat, y: CGFloat) {
    let point = CGPoint(x: x, y: y)
    CGWarpMouseCursorPosition(point)
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
}
if expectHidden { movePointer(x: display.midX, y: display.midY) }
func approachRightEdge() {
    let y = display.height / 2
    let source = CGEventSource(stateID: .hidSystemState)
    movePointer(x: display.width - 42, y: y)
    // Deliver an actual approach and outward motion. Warping straight to the
    // last point can bypass the Dock's edge activation on a freshly started Dock.
    var previous = display.width - 42
    for distance: CGFloat in [24, 12, 4, 1, 0.5, 0.5] {
        let x = display.width - distance
        let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                            mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)
        event?.setIntegerValueField(.mouseEventDeltaX, value: Int64(max(1, x - previous)))
        event?.post(tap: .cghidEventTap)
        RunLoop.current.run(until: Date().addingTimeInterval(0.04))
        previous = x
    }
}
// The Dock can retain a full-screen input window while its shelf is hidden.
// Read the actual Accessibility list on this single-display CI Mac.
func shelfFrame() -> CGRect? {
    func read(_ element: AXUIElement, _ key: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, key, &value) == .success ? value : nil
    }
    let dock = AXUIElementCreateApplication(dockPID)
    guard let roots = read(dock, kAXChildrenAttribute as CFString) as? [AXUIElement],
          let list = roots.first(where: { read($0, kAXRoleAttribute as CFString) as? String == "AXList" }) else { return nil }
    var origin = CGPoint.zero, size = CGSize.zero
    guard let s = read(list, kAXSizeAttribute as CFString), CFGetTypeID(s) == AXValueGetTypeID(),
          AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
    if size == .zero { return .zero }
    if let p = read(list, kAXPositionAttribute as CFString), CFGetTypeID(p) == AXValueGetTypeID(),
       AXValueGetValue(p as! AXValue, .cgPoint, &origin) { return CGRect(origin: origin, size: size) }
    return nil
}
var lastDiagnostic = ""
var measuredLength: CGFloat?
var matched = false
for attempt in 0..<50 {
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
    let shelf = (reveal || expectHidden) ? shelfFrame() : nil
    let visibleShelf = shelf.map { $0.intersection(display).width >= 5 && $0.height > 50 } ?? false
    if reveal && !visibleShelf && attempt.isMultiple(of: 10) { approachRightEdge() }
    if expectHidden { matched = overlays.isEmpty && ((shelf != nil && !visibleShelf) || docks.isEmpty) }
    else if let panel = overlays.first, overlays.count == 1 {
        switch side {
        case "reveal":
            matched = visibleShelf && panel.maxX <= display.maxX + 1 && panel.maxX > display.maxX - 18 && panel.width > 8 && panel.height > 50 && panel.height <= display.height
        case "left":
            matched = visible.minX > display.minX + 15 && abs(panel.maxX - visible.minX) < 10 && panel.height <= display.height
        case "right":
            matched = visible.maxX < display.maxX - 15 && abs(panel.minX - visible.maxX) < 10 && panel.height <= display.height
        default:
            matched = visible.minY > display.minY + 15 && abs(panel.minY - (display.maxY - visible.minY)) < 10 && panel.width <= display.width && panel.height < display.height / 3
        }
    }
    if matched {
        if let overlay = overlays.first { measuredLength = side == "bottom" ? overlay.width : overlay.height }
        break
    }
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
}
print(lastDiagnostic)
guard matched else {
    let dock = AXUIElementCreateApplication(dockPID)
    func attribute(_ element: AXUIElement, _ key: CFString) -> CFTypeRef? {
        var result: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, key, &result)
        return result
    }
    if let roots = attribute(dock, kAXChildrenAttribute as CFString) as? [AXUIElement] {
        for root in roots {
            var pos = CGPoint.zero, size = CGSize.zero
            if let v = attribute(root, kAXPositionAttribute as CFString), CFGetTypeID(v) == AXValueGetTypeID() {
                AXValueGetValue(v as! AXValue, .cgPoint, &pos)
            }
            if let v = attribute(root, kAXSizeAttribute as CFString), CFGetTypeID(v) == AXValueGetTypeID() {
                AXValueGetValue(v as! AXValue, .cgSize, &size)
            }
            print("Dock AX root role=\(String(describing: attribute(root, kAXRoleAttribute as CFString))) pos=\(pos) size=\(size)")
        }
    }
    print("AX trusted in probe: \(AXIsProcessTrusted())")
    FileHandle.standardError.write(Data("Dock check failed for \(side): \(lastDiagnostic)\n".utf8))
    exit(1)
}
if let measuredLength, args.count > 3 {
    let url = URL(fileURLWithPath: args[3])
    if FileManager.default.fileExists(atPath: url.path) {
        let initial = try Double(String(contentsOf: url, encoding: .utf8))
        guard let initial, measuredLength < initial - 10 else { fatalError("Strand did not shrink with the Dock") }
        print("PASS live resize from \(initial) to \(measuredLength) points")
    } else { try String(Double(measuredLength)).write(to: url, atomically: true, encoding: .utf8) }
}
print("PASS live Dock placement: \(side)")
