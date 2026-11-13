import AppKit
import SwiftUI
import ServiceManagement

enum Page: String, CaseIterable {
    case general = "General", presets = "Presets", menu = "Menu Bar", dock = "Dock", desktop = "Desktop"
    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .presets: return "square.stack.3d.up"
        case .menu: return "menubar.rectangle"
        case .dock: return "dock.rectangle"
        case .desktop: return "sparkles"
        }
    }
}
@MainActor
final class Navigation: ObservableObject {
    @Published var page = Page.general
    @Published var showingGuide = false
    @Published var trusted = Accessibility.granted
    @Published var dockStatus = "Locating Dock…"
}

struct NumberRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var unit = ""
    var step = 1.0
    var percent = false
    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 10) {
                Slider(value: $value, in: range, step: step).accessibilityLabel(label)
                Text(percent ? "\(Int((value * 100).rounded()))%" :
                        value.formatted(.number.precision(.fractionLength(0...2))) + unit)
                    .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    .frame(width: unit == " K" ? 74 : 57, alignment: .trailing)
            }.frame(maxWidth: 320)
        }
    }
}

struct EnumRow<T: RawRepresentable & CaseIterable & Hashable>: View where T.RawValue == String {
    let title: String
    @Binding var value: T
    var body: some View {
        Picker(title, selection: $value) { ForEach(Array(T.allCases), id: \.self) { Text($0.rawValue).tag($0) } }
    }
}

struct PaletteEditor: View {
    @Binding var colors: [Int]
    @ObservedObject var studio: Studio
    @State private var naming = false
    var body: some View {
        HStack {
            Text("Colors")
            Spacer()
            Menu("Palettes") {
                ForEach(studio.prefs.palettes) { p in Button(p.name) { colors = p.colors } }
                Divider()
                Button("Save these colors…") { naming = true }
            }.fixedSize()
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 53, maximum: 70), spacing: 6)], alignment: .leading, spacing: 7) {
            ForEach(colors.indices, id: \.self) { i in
                HStack(spacing: 2) {
                    ColorPicker("Color \(i + 1)", selection: Binding(get: {
                        Color(rgb: colors.indices.contains(i) ? colors[i] : 0xffffff)
                    }, set: { if colors.indices.contains(i) { colors[i] = $0.rgb } }), supportsOpacity: false)
                        .labelsHidden()
                    Button {
                        if colors.count > 1 && colors.indices.contains(i) { colors.remove(at: i) }
                    } label: { Image(systemName: "minus.circle").font(.caption) }
                    .buttonStyle(.borderless).disabled(colors.count == 1).accessibilityLabel("Remove color \(i + 1)")
                }
            }
            Button { colors.append(0xffe1a8) } label: { Image(systemName: "plus") }
                .disabled(colors.count >= 16).help("Add a color").accessibilityLabel("Add a color")
        }
        .sheet(isPresented: $naming) {
            NameSheet(title: "Save color palette", initial: "My Palette") { studio.prefs.palettes.append(.init(name: $0, colors: colors)) }
        }
    }
}
struct NameSheet: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    @State private var name: String
    let commit: (String) -> Void
    init(title: String, initial: String, commit: @escaping (String) -> Void) {
        self.title = title; _name = State(initialValue: initial); self.commit = commit
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { commit(name.trimmingCharacters(in: .whitespacesAndNewlines)); dismiss() }
                    .keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(22).frame(width: 350)
    }
}

struct LightSettings: View {
    @Binding var light: Lights
    let layer: Layer
    @ObservedObject var studio: Studio
    @ObservedObject var nav: Navigation
    var body: some View {
        Form {
            Section {
                Toggle("Enable \(layer.rawValue) lights", isOn: $light.enabled)
                Picker("Placement", selection: $light.aboveApps) {
                    Text(layer == .dock ? "Whenever the Dock is visible" : "Above apps").tag(true)
                    Text(layer == .dock ? "While using Finder" : "Desktop only").tag(false)
                }
                if layer == .dock { LabeledContent("Dock tracking", value: nav.dockStatus) }
                if layer == .dock && !nav.trusted {
                    Button("Allow precise Dock tracking…") { Accessibility.request(); Accessibility.openSettings() }
                }
            }
            Section("Bulbs") {
                Picker("Design", selection: $light.bulb) {
                    ForEach(Bulb.allCases.filter { $0 != .custom || light.customMask != nil }, id: \.self) { b in Text(b.displayName).tag(b) }
                }
                LabeledContent("Custom design") {
                    Button("Import SVG…") {
                        if let mask = studio.importBulb() { light.customMask = mask; light.bulb = .custom }
                    }.help("The SVG silhouette takes on the colors of your lights.")
                }
                NumberRow(label: "Size", value: $light.size, range: Lights.sizeRange, unit: " pt")
                NumberRow(label: "Distance", value: $light.spacing, range: 8...90, unit: " pt")
                NumberRow(label: "Density", value: $light.density, range: 0.05...1, step: 0.05, percent: true)
                NumberRow(label: "Opacity", value: $light.opacity, range: 0.05...1, step: 0.05, percent: true)
            }
            Section("Animation") {
                EnumRow(title: "Pattern", value: $light.pattern)
                if [.chase, .every].contains(light.pattern) {
                    NumberRow(label: "Repeat every", value: $light.interval, range: 2...24, unit: " bulbs")
                }
                if light.pattern == .wave {
                    NumberRow(label: "Wavelength", value: $light.waveLength, range: 2...48, unit: " bulbs")
                }
                NumberRow(label: "Speed", value: $light.speed, range: 0.1...3, unit: "×", step: 0.1)
                NumberRow(label: "Variation", value: $light.variation, range: 0...1, step: 0.05, percent: true)
                EnumRow(title: "Near the pointer", value: $light.pointer)
            }
            Section("Light color") {
                Picker("Color source", selection: $light.useTemperature) {
                    Text("Palette").tag(false); Text("Temperature").tag(true)
                }
                if light.useTemperature {
                    NumberRow(label: "Temperature", value: $light.temperature, range: 1800...10000, unit: " K", step: 100)
                } else { PaletteEditor(colors: $light.colors, studio: studio) }
            }
            Section("Cable") {
                ColorPicker("Color", selection: Binding(get: { Color(rgb: light.wire) }, set: { light.wire = $0.rgb }), supportsOpacity: false)
                NumberRow(label: "Thickness", value: $light.thickness, range: 0.5...5, unit: " pt", step: 0.1)
                NumberRow(label: "Drop width", value: $light.span, range: 30...520, unit: " pt", step: 5)
                NumberRow(label: "Drop height", value: $light.sag, range: 0...70, unit: " pt")
            }
        }.formStyle(.grouped)
    }
}

struct DesktopSettings: View {
    @ObservedObject var studio: Studio
    var body: some View {
        Form {
            Section {
                Toggle("Enable desktop effects", isOn: $studio.prefs.scene.desktop.enabled)
                EnumRow(title: "Effect", value: $studio.prefs.scene.desktop.effect)
                LabeledContent("Placement", value: "Desktop only")
            }
            Section(studio.prefs.scene.desktop.effect == .aurora ? "Curtains" : "Particles") {
                NumberRow(label: "Amount", value: $studio.prefs.scene.desktop.density, range: 0...1, step: 0.05, percent: true)
                NumberRow(label: "Size", value: $studio.prefs.scene.desktop.size, range: 1...16, unit: " pt", step: 0.5)
                NumberRow(label: "Speed", value: $studio.prefs.scene.desktop.speed, range: 0.1...3, unit: "×", step: 0.1)
                NumberRow(label: "Opacity", value: $studio.prefs.scene.desktop.opacity, range: 0.05...1, step: 0.05, percent: true)
                NumberRow(label: "Wind (left to right)", value: $studio.prefs.scene.desktop.wind, range: -1...1, step: 0.05, percent: true)
                if ![Effect.fireworks, .ballDrop, .aurora, .meteors].contains(studio.prefs.scene.desktop.effect) {
                    NumberRow(label: "Pointer repulsion", value: $studio.prefs.scene.desktop.repel, range: 0...1, step: 0.05, percent: true)
                }
            }
            Section("Effect colors") { PaletteEditor(colors: $studio.prefs.scene.desktop.colors, studio: studio) }
        }.formStyle(.grouped)
    }
}

struct GeneralSettings: View {
    @ObservedObject var studio: Studio
    @ObservedObject var nav: Navigation
    @AppStorage("useWallpaperPreview") private var useWallpaper = false
    @AppStorage("automaticReleaseChecks") private var automaticUpdates = false
    @State private var login = SMAppService.mainApp.status == .enabled
    @State private var approvalNeeded = SMAppService.mainApp.status == .requiresApproval
    var body: some View {
        Form {
            Section("On your Mac") {
                EnumRow(title: "Show SZNS in", value: $studio.prefs.visibility)
                if studio.prefs.visibility == .neither {
                    Text("To reopen Settings, launch SZNS from Finder or Spotlight.").font(.callout).foregroundStyle(.secondary)
                }
                Toggle("Launch at login", isOn: Binding(get: { login }, set: { enable in
                    do {
                        if enable { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch { studio.message = error.localizedDescription }
                    login = SMAppService.mainApp.status == .enabled
                    approvalNeeded = SMAppService.mainApp.status == .requiresApproval
                }))
                if approvalNeeded { Button("Approve in Login Items…") { SMAppService.openSystemSettingsLoginItems() } }
                EnumRow(title: "Save power", value: $studio.prefs.power)
                Toggle("Use my wallpaper in previews", isOn: $useWallpaper)
            }
            Section("Accessibility") {
                LabeledContent("Dock tracking") {
                    if nav.trusted { Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                    else { Button("Grant access…") { Accessibility.request(); Accessibility.openSettings() } }
                }
                Text("SZNS reads the Dock’s position so its lights follow it between displays. Menu bar lights and desktop effects work independently.")
                    .foregroundStyle(.secondary).font(.callout)
            }
            Section("About") {
                LabeledContent("SZNS", value: "By Tekwiz17")
                Link("Source code on GitHub", destination: Studio.source)
                Toggle("Check for updates automatically", isOn: $automaticUpdates)
                Button("Check for updates…") { Task { await studio.checkForUpdates() } }
                Button("Replay welcome guide…") { nav.showingGuide = true }
                Button("Quit SZNS") { NSApp.terminate(nil) }
            }
        }.formStyle(.grouped)
    }
}

struct SettingsView: View {
    @ObservedObject var studio: Studio
    @ObservedObject var nav: Navigation
    var body: some View {
        VStack(spacing: 0) {
            if nav.page != .presets {
                let focus: Layer? = nav.page == .menu ? .menu : nav.page == .dock ? .dock : nav.page == .desktop ? .desktop : nil
                ScenePreview(scene: studio.prefs.scene, focus: focus)
                    .frame(height: focus == .dock ? min(230, max(110, studio.prefs.scene.dock.depth + 24)) : focus == .menu ? min(240, max(110, studio.prefs.scene.menu.depth + 12)) : 110).padding(.horizontal, 20).padding(.top, 14)
            }
            switch nav.page {
            case .general: GeneralSettings(studio: studio, nav: nav)
            case .presets: PresetSettings(studio: studio)
            case .menu: LightSettings(light: $studio.prefs.scene.menu, layer: .menu, studio: studio, nav: nav)
            case .dock: LightSettings(light: $studio.prefs.scene.dock, layer: .dock, studio: studio, nav: nav)
            case .desktop: DesktopSettings(studio: studio)
            }
        }
        .frame(minWidth: 510, minHeight: 435)
        .sheet(isPresented: $nav.showingGuide) { WelcomeView(studio: studio, nav: nav) }
        .alert("SZNS", isPresented: Binding(get: { studio.message != nil }, set: { if !$0 { studio.message = nil } })) {
            Button("OK") { studio.message = nil }
        } message: { Text(studio.message ?? "") }
    }
}
