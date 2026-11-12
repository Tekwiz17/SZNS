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
    func frame(windows: [[String: Any]], primaryHeight: CGFloat) -> CGRect? {
        guard Accessibility.granted, let process = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            list = nil; return nil
        }
        if pid != process.processIdentifier { list = nil; pid = process.processIdentifier }
        if list == nil {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.12)
            list = dockList(in: app)
        }
        guard let list else { return nil }
        guard let bounds = rect(list) else { self.list = nil; return nil }
        // Match the actual Dock surface when it is animating, magnified, or auto-hidden.
        let dockLevel = Int(CGWindowLevelForKey(.dockWindow))
        let surfaces: [CGRect] = windows.compactMap { info in
            guard info[kCGWindowOwnerPID as String] as? Int32 == pid,
                  info[kCGWindowLayer as String] as? Int == dockLevel,
                  let values = info[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: values as CFDictionary),
                  min(r.width, r.height) > 1, max(r.width, r.height) >= 24 else { return nil }
            return r
        }
        let visibleSurface = surfaces.filter { $0.intersects(bounds.insetBy(dx: -16, dy: -16)) }
            .min { abs($0.midX - bounds.midX) + abs($0.midY - bounds.midY) <
                   abs($1.midX - bounds.midX) + abs($1.midY - bounds.midY) }
        let autohide = UserDefaults.standard.persistentDomain(forName: "com.apple.dock")?["autohide"] as? Bool ?? false
        if autohide && visibleSurface == nil { return nil }
        return DisplayGeometry.cocoa(visibleSurface ?? bounds, primaryHeight: primaryHeight)
    }
}
