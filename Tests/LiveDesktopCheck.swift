import AppKit

@main
@MainActor
enum LiveDesktopCheck {
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        guard let screen = NSScreen.screens.first else { fatalError("Missing display") }
        let cover = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        cover.isOpaque = true
        cover.backgroundColor = .black
        cover.level = .normal
        cover.orderFrontRegardless()
        defer { cover.orderOut(nil) }

        let executable = URL(fileURLWithPath: CommandLine.arguments[1])
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SZNS/Preferences.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        for effect in [Effect.leaves, .bats] {
            var prefs = Preferences()
            prefs.welcomed = true
            prefs.scene.menu.enabled = false
            prefs.scene.dock.enabled = false
            prefs.scene.desktop.effect = effect
            prefs.scene.desktop.pumpkinsEnabled = true
            try JSONEncoder().encode(prefs).write(to: url, options: .atomic)
            let child = Process()
            child.executableURL = executable
            try child.run()
            defer {
                if child.isRunning { kill(child.processIdentifier, SIGKILL) }
                child.waitUntilExit()
            }
            let desktopLevel = Int(CGWindowLevelForKey(.desktopWindow)) + 1
            let deadline = Date().addingTimeInterval(12)
            var verified = false
            repeat {
                RunLoop.current.run(until: Date().addingTimeInterval(0.15))
                let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
                guard let coverIndex = windows.firstIndex(where: { $0[kCGWindowNumber as String] as? Int == cover.windowNumber }) else { continue }
                let panels = windows.indices.filter { index in
                    let w = windows[index]
                    guard w[kCGWindowOwnerPID as String] as? Int == Int(child.processIdentifier),
                          let b = w[kCGWindowBounds as String] as? NSDictionary,
                          let rect = CGRect(dictionaryRepresentation: b as CFDictionary) else { return false }
                    return abs(rect.width - screen.frame.width) < 2 && abs(rect.height - screen.frame.height) < 2
                }
                // WindowServer lists front to back. The full-screen decoration must
                // sit below the separate opaque app window and above the wallpaper.
                verified = !panels.isEmpty && panels.allSatisfy { index in
                    index > coverIndex && windows[index][kCGWindowLayer as String] as? Int == desktopLevel
                }
            } while !verified && child.isRunning && Date() < deadline
            precondition(verified, "Desktop decoration was missing or above the covering app window")
            print("PASS \(effect.rawValue) and jack-o’-lanterns sit behind a separate normal window")
        }
    }
}
