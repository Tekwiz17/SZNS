import AppKit
import ApplicationServices

enum Accessibility {
    static var granted: Bool { AXIsProcessTrusted() }
    static func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

final class DockLocator {
    private var pid: pid_t = 0
    private var list: AXUIElement?

    private func read(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute, &result) == .success ? result : nil
    }
    private func rect(_ element: AXUIElement) -> CGRect? {
        guard let p = read(element, kAXPositionAttribute as CFString),
              let s = read(element, kAXSizeAttribute as CFString),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &origin),
              AXValueGetValue(s as! AXValue, .cgSize, &size), size.width > 2, size.height > 2 else { return nil }
        return CGRect(origin: origin, size: size)
    }
    private func dockList(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        if read(element, kAXRoleAttribute as CFString) as? String == (kAXListRole as String) { return element }
        guard depth < 3, let children = read(element, kAXChildrenAttribute as CFString) as? [AXUIElement] else { return nil }
        for child in children.prefix(32) {
            if let found = dockList(in: child, depth: depth + 1) { return found }
        }
        return nil
    }
    struct Match {
        let bounds: CGRect
        let display: CGRect
        let side: DockSide
    }

    func frame(windows: [[String: Any]], displays: [DockDisplay], primaryHeight: CGFloat, mouse: CGPoint) -> Match? {
        guard let process = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            list = nil
            return nil
        }
        if pid != process.processIdentifier { list = nil; pid = process.processIdentifier }
        let defaults = UserDefaults.standard.persistentDomain(forName: "com.apple.dock")
        let side = DockSide(rawValue: defaults?["orientation"] as? String ?? "") ?? .bottom
        let autoHides = defaults?["autohide"] as? Bool ?? false

        func match(_ quartz: CGRect, fromAX: Bool) -> Match? {
            let rect = DisplayGeometry.cocoa(quartz, primaryHeight: primaryHeight)
            guard let display = DisplayGeometry.dockDisplay(for: rect, in: displays),
                  let bounds = display.dockBounds(rect, side: side, useReservedEdge: !autoHides) else { return nil }
            // Some Dock versions keep reporting their resting AX coordinates after hiding.
            // With no reserved inset or visible shelf window, the pointer must be over the shelf.
            if fromAX && display.reservedDepth(side) < 5 && !bounds.insetBy(dx: -2, dy: -2).contains(mouse) {
                return nil
            }
            return Match(bounds: bounds, display: display.frame, side: side)
        }

        // Dock.app also owns a screen-sized hit-testing surface at this exact level.
        // Use only visible shelf-shaped windows pinned to the configured edge.
        let dockLevel = Int(CGWindowLevelForKey(.dockWindow))
        let surfaces: [Match] = windows.compactMap { info in
            guard info[kCGWindowOwnerPID as String] as? Int32 == pid,
                  info[kCGWindowLayer as String] as? Int == dockLevel,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let values = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: values as CFDictionary) else { return nil }
            return match(rect, fromAX: false)
        }
        if let visible = surfaces.max(by: { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }) {
            return visible
        }

        guard Accessibility.granted else { list = nil; return nil }
        if list == nil {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.12)
            list = dockList(in: app)
        }
        guard let list else { return nil }
        if let bounds = rect(list), let result = match(bounds, fromAX: true) { return result }

        // The list container can be unpositioned. The tiles still carry individual AX frames.
        guard let children = read(list, kAXChildrenAttribute as CFString) as? [AXUIElement] else {
            self.list = nil
            return nil
        }
        let items = children.compactMap { element -> CGRect? in
            guard let bounds = rect(element), bounds.width <= 256, bounds.height <= 256 else { return nil }
            return bounds
        }
        guard !items.isEmpty else { self.list = nil; return nil }
        let span = items.reduce(CGRect.null) { $0.union($1) }
        let padded = side == .bottom ? span.insetBy(dx: -5, dy: 0) : span.insetBy(dx: 0, dy: -5)
        return match(padded, fromAX: true)
    }
}
