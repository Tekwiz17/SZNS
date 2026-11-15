import AppKit
import ScreenCaptureKit

@main
@MainActor
enum LiveAnimationCheck {
    static func pixels(_ window: SCWindow) async throws -> Data {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = max(1, Int(window.frame.width))
        config.height = max(1, Int(window.frame.height))
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        var data = Data(count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                    bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }

    static func main() async throws {
        _ = NSApplication.shared
        precondition(!NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, "Runner has Reduce Motion enabled")
        let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SZNS/Preferences.json")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        var prefs = Preferences()
        prefs.scene.menu.pattern = .pulse
        prefs.scene.dock.pattern = .pulse
        prefs.scene.desktop.effect = .snow
        prefs.scene.desktop.density = 0.8
        // The welcome sheet supplies a visible production ScenePreview too.
        prefs.welcomed = false
        try JSONEncoder().encode(prefs).write(to: file, options: .atomic)
        let child = Process()
        child.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
        try child.run()
        defer {
            if child.isRunning { kill(child.processIdentifier, SIGKILL) }
            child.waitUntilExit()
        }
        try await Task.sleep(for: .seconds(4))
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let appWindows = content.windows.filter { $0.owningApplication?.processID == child.processIdentifier }
        let levels: [(String, Int)] = [
            ("menu bar", Int(CGWindowLevelForKey(.statusWindow)) + 1),
            ("Dock", Int(CGWindowLevelForKey(.dockWindow)) + 1),
            ("desktop", Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        ]
        let windowInfo = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        var targets = [(String, SCWindow)]()
        for (name, level) in levels {
            guard let entry = windowInfo.first(where: {
                $0[kCGWindowOwnerPID as String] as? Int == Int(child.processIdentifier) &&
                $0[kCGWindowLayer as String] as? Int == level
            }), let id = entry[kCGWindowNumber as String] as? UInt32,
                let window = appWindows.first(where: { $0.windowID == id }) else { fatalError("Missing " + name + " window") }
            targets.append((name, window))
        }
        // A sheet may be represented at the normal or modal window level.
        let previews = appWindows.filter { $0.windowLayer >= 0 && $0.frame.width >= 450 && $0.frame.height >= 300 }
        precondition(!previews.isEmpty, "Missing visible settings preview")
        for (i, window) in previews.enumerated() { targets.append(("preview \(i)", window)) }
        var changed = Set<String>()
        var initial = [String: Data]()
        for (name, window) in targets { initial[name] = try await pixels(window) }
        for _ in 0..<4 {
            try await Task.sleep(for: .milliseconds(450))
            for (name, window) in targets {
                let next = try await pixels(window)
                let first = initial[name]!
                precondition(first.count == next.count, "Window changed dimensions during motion check")
                let difference = zip(first, next).filter { abs(Int($0) - Int($1)) > 8 }.count
                if difference > 120 { changed.insert(name) }
            }
        }
        for (name, _) in levels { precondition(changed.contains(name), "Frozen live " + name + " animation") }
        precondition(changed.contains(where: { $0.hasPrefix("preview ") }), "Frozen live settings preview")
        print("PASS live pixels change in menu bar, Dock, desktop and settings preview")
    }
}
