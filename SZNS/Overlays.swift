import AppKit
import SwiftUI
import Combine
import IOKit.ps

private struct Surface: Equatable {
    var layer: Layer
    var frame: CGRect
    var edge: EdgeMount = .top
    var lights: Lights?
    var weather: Weather?
    var lowPower: Bool
    var reducedMotion: Bool
}
private struct SurfaceView: View {
    let spec: Surface
    var body: some View {
        let staticLights = spec.lights.map { ($0.pattern == .steady || $0.pattern == .off || $0.pattern == .every) && $0.pointer == .none } ?? false
        TimelineView(.animation(minimumInterval: spec.lowPower ? 1.0 / 12 : 1.0 / 30,
                                paused: spec.reducedMotion || staticLights)) { tick in
            Canvas { context, size in
                let time = spec.reducedMotion ? 0 : tick.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86400)
                let location = NSEvent.mouseLocation
                let mouse = CGPoint(x: location.x - spec.frame.minX, y: spec.frame.maxY - location.y)
                if let light = spec.lights {
                    LightDrawing.draw(in: context, size: size, lights: light, time: time, edge: spec.edge, pointer: mouse)
                } else if let weather = spec.weather {
                    WeatherDrawing.draw(in: context, size: size, weather: weather, time: time, pointer: mouse)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
private final class DecorationPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
@MainActor
final class Overlays {
    private struct Entry {
        var spec: Surface
        let panel: DecorationPanel
        let host: NSHostingView<SurfaceView>
    }
    private var entries = [String: Entry]()
    private var timer: Timer?
    private var observer: AnyCancellable?
    private let locator = DockLocator()
    private var asleep = false
    private let studio = Studio.shared
    private var nextBatterySample = Date.distantPast
    private var batteryIsLow = false

    private func shouldSavePower(_ power: Power) -> Bool {
        guard power == .automatic else { return power == .always }
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return true }
        if Date() >= nextBatterySample {
            nextBatterySample = Date().addingTimeInterval(30)
            batteryIsLow = false
            if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
               let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
                for source in sources {
                    guard let detail = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                          detail["Power Source State"] as? String == "Battery Power",
                          let charge = detail["Current Capacity"] as? Int,
                          let capacity = detail["Max Capacity"] as? Int, capacity > 0 else { continue }
                    if Double(charge) / Double(capacity) <= 0.2 { batteryIsLow = true }
                }
            }
        }
        return batteryIsLow
    }

    func start() {
        observer = studio.$prefs.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.refresh() }
        let clock = Timer(timeInterval: 0.32, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        clock.tolerance = 0.04
        RunLoop.main.add(clock, forMode: .common); timer = clock
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            ws.addObserver(self, selector: #selector(sleep), name: name, object: nil)
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            ws.addObserver(self, selector: #selector(wake), name: name, object: nil)
        }
        ws.addObserver(self, selector: #selector(refresh), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        refresh()
    }
    @objc private func sleep() { asleep = true; clear() }
    @objc private func wake() { asleep = false; refresh() }
    private func clear() { entries.values.forEach { $0.panel.orderOut(nil) }; entries.removeAll() }

    @objc func refresh() {
        let p = studio.prefs, screens = NSScreen.screens
        guard !asleep, let primary = screens.first, p.scene.dock.enabled || p.scene.menu.enabled || p.scene.desktop.enabled else {
            clear(); return
        }
        let low = shouldSavePower(p.power)
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let needsWindows = p.scene.menu.enabled || (p.scene.dock.enabled && Accessibility.granted)
        let windows = needsWindows ? (CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []) : []
        let dock = p.scene.dock.enabled ? locator.frame(windows: windows, primaryHeight: primary.frame.height) : nil
        var wanted = [String: Surface]()
        for screen in screens {
            let frame = screen.frame
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? NSStringFromRect(frame)
            if p.scene.desktop.enabled {
                wanted[id + ".desktop"] = Surface(layer: .desktop, frame: frame, weather: p.scene.desktop, lowPower: low, reducedMotion: reduced)
            }
            if p.scene.menu.enabled, let barBottom = menuBottom(screen, windows: windows, primaryHeight: primary.frame.height) {
                let h = p.scene.menu.depth
                let strip = CGRect(x: frame.minX, y: barBottom - h, width: frame.width, height: h)
                wanted[id + ".menu"] = Surface(layer: .menu, frame: strip, lights: p.scene.menu, lowPower: low, reducedMotion: reduced)
            }
            if let dock, frame.contains(CGPoint(x: dock.midX, y: dock.midY)) || screens.count == 1,
               let (strip, side) = DisplayGeometry.dockStrip(dock, screen: frame, depth: p.scene.dock.depth) {
                let edge: EdgeMount = side == .left ? .left : side == .right ? .right : .top
                wanted[id + ".dock"] = Surface(layer: .dock, frame: strip, edge: edge, lights: p.scene.dock, lowPower: low, reducedMotion: reduced)
            }
        }
        for key in Array(entries.keys) where wanted[key] == nil { entries.removeValue(forKey: key)?.panel.orderOut(nil) }
        for (key, spec) in wanted { present(key, spec) }
    }
    private func menuBottom(_ screen: NSScreen, windows: [[String: Any]], primaryHeight: CGFloat) -> CGFloat? {
        let screenFrame = screen.frame
        for w in windows where w[kCGWindowLayer as String] as? Int == Int(CGWindowLevelForKey(.mainMenuWindow)) {
            guard let b = w[kCGWindowBounds as String] as? NSDictionary,
                  let quartz = CGRect(dictionaryRepresentation: b as CFDictionary) else { continue }
            let bar = DisplayGeometry.cocoa(quartz, primaryHeight: primaryHeight)
            if abs(bar.width - screenFrame.width) < 4, abs(bar.minX - screenFrame.minX) < 3,
               abs(bar.maxY - screenFrame.maxY) < 3, (12...100).contains(bar.height) { return bar.minY }
        }
        let inset = screenFrame.maxY - screen.visibleFrame.maxY
        return (12...100).contains(inset) ? screen.visibleFrame.maxY : nil
    }
    private func present(_ key: String, _ spec: Surface) {
        if entries[key]?.spec == spec { return }
        let behindApps = spec.layer == .desktop || spec.lights?.aboveApps == false
        let level = behindApps ? CGWindowLevelForKey(.desktopWindow) + (spec.layer == .desktop ? 1 : 2)
                               : CGWindowLevelForKey(spec.layer == .dock ? .dockWindow : .statusWindow) + 1
        if var entry = entries[key] {
            entry.host.rootView = SurfaceView(spec: spec)
            if entry.spec.frame != spec.frame { entry.panel.setFrame(spec.frame, display: true) }
            entry.panel.level = .init(rawValue: Int(level))
            entry.spec = spec; entries[key] = entry
        } else {
            let panel = DecorationPanel(contentRect: spec.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isExcludedFromWindowsMenu = true; panel.animationBehavior = .none
            panel.level = .init(rawValue: Int(level))
            let host = NSHostingView(rootView: SurfaceView(spec: spec))
            host.sizingOptions = []
            panel.contentView = host
            panel.setFrame(spec.frame, display: true); panel.orderFrontRegardless()
            entries[key] = Entry(spec: spec, panel: panel, host: host)
        }
    }
}
