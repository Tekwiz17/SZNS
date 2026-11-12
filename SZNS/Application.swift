import AppKit
import Combine
import Carbon
import SwiftUI

@main
@MainActor
enum SZNSApplication {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSToolbarDelegate, NSMenuDelegate {
    private let studio = Studio.shared
    private let nav = Navigation()
    private let overlays = Overlays()
    private var window: NSWindow?
    private var item: NSStatusItem?
    private var subscription: AnyCancellable?
    private var permissionTimer: Timer?
    private var visibility: Visibility?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildAppMenu()
        updateVisibility(studio.prefs.visibility)
        subscription = studio.$prefs.map(\.visibility).removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.updateVisibility($0) }
        overlays.start()
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "automaticReleaseChecks"),
           Date.timeIntervalSinceReferenceDate - defaults.double(forKey: "lastReleaseCheck") > 86400 {
            defaults.set(Date.timeIntervalSinceReferenceDate, forKey: "lastReleaseCheck")
            Task { await studio.checkForUpdates(silent: true) }
        }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                let granted = Accessibility.granted
                if self?.nav.trusted != granted { self?.nav.trusted = granted }
            }
        }
        timer.tolerance = 0.3; RunLoop.main.add(timer, forMode: .common); permissionTimer = timer
        // A login item or a background Shortcut should be able to decorate without stealing focus.
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchedHidden = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
        let finderLaunch = event?.eventID == AEEventID(kAEOpenApplication)
        if !studio.prefs.welcomed || (!launchedHidden && (NSApp.isActive || finderLaunch)) { showSettings() }
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        if window == nil && visibility != nil { showSettings() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(); return false
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { studio.save() }

    private func buildAppMenu() {
        let menu = NSMenu()
        let root = NSMenuItem()
        menu.addItem(root)
        let app = NSMenu(title: "SZNS"); root.submenu = app
        app.addItem(command("Settings…", #selector(showSettings), ","))
        app.addItem(.separator()); app.addItem(command("Quit SZNS", #selector(quit), "q"))
        let editRoot = NSMenuItem(); menu.addItem(editRoot)
        let edit = NSMenu(title: "Edit"); editRoot.submenu = edit
        for (name, action, key) in [("Undo","undo:","z"),("Cut","cut:","x"),("Copy","copy:","c"),("Paste","paste:","v"),("Select All","selectAll:","a")] {
            edit.addItem(withTitle: name, action: NSSelectorFromString(action), keyEquivalent: key)
        }
        let winRoot = NSMenuItem(); menu.addItem(winRoot)
        let win = NSMenu(title: "Window"); winRoot.submenu = win
        win.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        win.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        NSApp.windowsMenu = win; NSApp.mainMenu = menu
    }
    private func command(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self; return entry
    }
    private func updateVisibility(_ value: Visibility) {
        guard visibility != value else { return }
        visibility = value
        NSApp.setActivationPolicy(value.showsDock ? .regular : .accessory)
        if value.showsMenu && item == nil {
            let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            let icon = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "SZNS")
            icon?.isTemplate = true; status.button?.image = icon; status.button?.toolTip = "SZNS"
            let menu = NSMenu(); menu.delegate = self; status.menu = menu; item = status
        } else if !value.showsMenu, let item { NSStatusBar.system.removeStatusItem(item); self.item = nil }
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(command("Settings…", #selector(showSettings), ","))
        menu.addItem(.separator())
        for (i, layer) in Layer.allCases.enumerated() {
            let entry = command(layer == .desktop ? "Desktop effects" : layer.rawValue + " lights", #selector(toggleLayer(_:)))
            let scene = studio.prefs.scene
            let on = layer == .menu ? scene.menu.enabled : layer == .dock ? scene.dock.enabled : scene.desktop.enabled
            entry.tag = i; entry.state = on ? .on : .off; menu.addItem(entry)
        }
        menu.addItem(.separator()); menu.addItem(command("Quit SZNS", #selector(quit), "q"))
    }
    @objc private func toggleLayer(_ sender: NSMenuItem) {
        switch Layer.allCases[sender.tag] {
        case .menu: studio.prefs.scene.menu.enabled.toggle()
        case .dock: studio.prefs.scene.dock.enabled.toggle()
        case .desktop: studio.prefs.scene.desktop.enabled.toggle()
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func showSettings() {
        if window == nil {
            let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 600, height: 620),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.title = "SZNS Settings"; w.toolbarStyle = .preference
            let toolbar = NSToolbar(identifier: "SZNSSettings")
            toolbar.delegate = self; toolbar.displayMode = .iconAndLabel; toolbar.allowsUserCustomization = false
            w.toolbar = toolbar; toolbar.selectedItemIdentifier = .init(nav.page.rawValue)
            w.contentView = NSHostingView(rootView: SettingsView(studio: studio, nav: nav))
            w.contentMinSize = .init(width: 525, height: 455)
            w.center(); w.setFrameAutosaveName("SZNS Settings")
            window = w
        }
        window?.deminiaturize(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if !studio.prefs.welcomed { nav.showingGuide = true }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Page.allCases.map { .init($0.rawValue) }
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarAllowedItemIdentifiers(toolbar) }
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarAllowedItemIdentifiers(toolbar) }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let page = Page(rawValue: id.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = page.rawValue; item.paletteLabel = page.rawValue
        item.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: page.rawValue)
        item.target = self; item.action = #selector(selectPage(_:))
        return item
    }
    @objc private func selectPage(_ sender: NSToolbarItem) {
        if let page = Page(rawValue: sender.itemIdentifier.rawValue) { nav.page = page }
    }
}
