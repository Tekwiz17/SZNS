import SwiftUI

private struct Swatches: View {
    let colors: [Int]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(colors.prefix(6).enumerated()), id: \.offset) { _, value in
                Circle().fill(Color(rgb: value)).overlay(Circle().stroke(.primary.opacity(0.12))).frame(width: 12, height: 12)
            }
        }.accessibilityHidden(true)
    }
}
private enum PresetSheet: Identifiable {
    case newScene, renameScene(Look), preview(Look), editPalette(Palette), newPalette
    var id: String {
        switch self {
        case .newScene: return "new scene"
        case .newPalette: return "new palette"
        case .preview(let p): return "preview-" + p.id.uuidString
        case .renameScene(let p): return p.id.uuidString
        case .editPalette(let p): return p.id.uuidString
        }
    }
}
struct PresetSettings: View {
    @ObservedObject var studio: Studio
    @State private var sheet: PresetSheet?
    @State private var removing: UUID?
    @State private var overwrite: UUID?
    @State private var query = ""
    @State private var favoritesOnly = false

    private var visibleLooks: [Look] {
        studio.prefs.looks.filter { $0.matches(query) && (!favoritesOnly || $0.favorite == true) }
    }
    private var visiblePalettes: [Palette] {
        studio.prefs.palettes.filter { p in
            query.split(whereSeparator: { $0.isWhitespace }).allSatisfy { p.name.localizedCaseInsensitiveContains(String($0)) }
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search scenes, bulbs, effects or palettes", text: $query).textFieldStyle(.plain)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.borderless).accessibilityLabel("Clear search")
                    }
                }
                Toggle("Favorite scenes only", isOn: $favoritesOnly)
            }
            Section {
                if visibleLooks.isEmpty {
                    Text(favoritesOnly && query.isEmpty ? "Star a scene to find it here." : "No matching scenes.")
                        .foregroundStyle(.secondary)
                }
                ForEach(visibleLooks) { look in
                    HStack {
                        Button {
                            if let i = studio.prefs.looks.firstIndex(where: { $0.id == look.id }) {
                                studio.prefs.looks[i].favorite = look.favorite != true
                            }
                        } label: {
                            Image(systemName: look.favorite == true ? "star.fill" : "star")
                                .foregroundStyle(look.favorite == true ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(look.favorite == true ? "Unfavorite " + look.name : "Favorite " + look.name)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(look.name)
                            Text("\(look.scene.menu.bulb.displayName) · \(look.scene.desktop.effect.rawValue)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Swatches(colors: look.scene.menu.colors)
                        Button { sheet = .preview(look) } label: { Image(systemName: "eye") }
                            .buttonStyle(.borderless).help("Preview or mix " + look.name).accessibilityLabel("Preview or mix " + look.name)
                        Button(studio.prefs.scene == look.scene ? "Applied" : "Apply") { studio.prefs.scene = look.scene }
                            .disabled(studio.prefs.scene == look.scene)
                        Menu {
                            Button("Rename…") { sheet = .renameScene(look) }
                            Button("Update from current settings…") { overwrite = look.id }
                            Button("Duplicate") { studio.prefs.looks.append(.init(name: look.name + " Copy", scene: look.scene)) }
                            Divider()
                            Button("Delete…", role: .destructive) { removing = look.id }
                        } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Manage " + look.name)
                    }
                }
                Button { sheet = .newScene } label: { Label("Save current scene…", systemImage: "plus") }
            } header: { Text("Scenes") } footer: {
                Text("A scene saves the Dock, menu bar and desktop together. After adjusting a scene, use its menu to save your changes.")
            }
            Section("Color palettes") {
                ForEach(visiblePalettes) { p in
                    HStack {
                        Text(p.name); Spacer(); Swatches(colors: p.colors)
                        Menu("Apply to") {
                            Button("Menu Bar") { studio.prefs.scene.menu.colors = p.colors; studio.prefs.scene.menu.useTemperature = false }
                            Button("Dock") { studio.prefs.scene.dock.colors = p.colors; studio.prefs.scene.dock.useTemperature = false }
                            Button("Desktop") { studio.prefs.scene.desktop.colors = p.colors }
                        }.fixedSize()
                        Menu {
                            Button("Edit name and colors…") { sheet = .editPalette(p) }
                            Button("Export…") { studio.exportPalette(p) }
                            Button("Delete…", role: .destructive) { removing = p.id }
                        } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Manage " + p.name)
                    }
                }
                if visiblePalettes.isEmpty && !query.isEmpty { Text("No matching palettes.").foregroundStyle(.secondary) }
                HStack {
                    Button { sheet = .newPalette } label: { Label("New palette…", systemImage: "plus") }
                    Spacer()
                    Button("Import palette…") { studio.importPalette() }
                }
            }
        }.formStyle(.grouped)
        .sheet(item: $sheet) { item in
            switch item {
            case .preview(let look):
                MixSceneSheet(look: look, studio: studio)
            case .newScene:
                NameSheet(title: "Save current scene", initial: "My Scene") { studio.prefs.looks.append(.init(name: $0, scene: studio.prefs.scene)) }
            case .renameScene(let look):
                NameSheet(title: "Rename scene", initial: look.name) { name in
                    if let i = studio.prefs.looks.firstIndex(where: { $0.id == look.id }) { studio.prefs.looks[i].name = name }
                }
            case .editPalette(let palette): paletteSheet(palette)
            case .newPalette: paletteSheet(.init(name: "My Palette", colors: studio.prefs.scene.menu.colors))
            }
        }
        .confirmationDialog("Delete this preset?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            presenting: removing) { id in
            Button("Delete preset", role: .destructive) {
                studio.prefs.looks.removeAll { $0.id == id }; studio.prefs.palettes.removeAll { $0.id == id }
            }
        }
        .confirmationDialog("Replace this saved scene with your current settings?",
                            isPresented: Binding(get: { overwrite != nil }, set: { if !$0 { overwrite = nil } }),
                            presenting: overwrite) { id in
            Button("Update scene") {
                if let i = studio.prefs.looks.firstIndex(where: { $0.id == id }) { studio.prefs.looks[i].scene = studio.prefs.scene }
            }
        }
    }
    private func paletteSheet(_ palette: Palette) -> some View {
        EditPaletteView(draft: palette, studio: studio) { updated in
            if let i = studio.prefs.palettes.firstIndex(where: { $0.id == updated.id }) { studio.prefs.palettes[i] = updated }
            else { studio.prefs.palettes.append(updated) }
        }
    }
}
private struct MixSceneSheet: View {
    @Environment(\.dismiss) private var dismiss
    let look: Look
    @ObservedObject var studio: Studio
    @State private var selected = Set(Layer.allCases)

    private func detail(_ layer: Layer) -> String {
        switch layer {
        case .menu: return look.scene.menu.enabled ? look.scene.menu.bulb.displayName : "Off"
        case .dock: return look.scene.dock.enabled ? look.scene.dock.bulb.displayName : "Off"
        case .desktop: return look.scene.desktop.enabled ? look.scene.desktop.effect.rawValue : "Off"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(look.name).font(.title2.weight(.semibold))
            ScenePreview(scene: studio.prefs.scene.mixing(look.scene, layers: selected))
                .frame(height: 180)
            Text("Choose which layers to apply").font(.headline)
            ForEach(Layer.allCases, id: \.self) { layer in
                Toggle(isOn: Binding(get: { selected.contains(layer) }, set: { on in
                    if on { selected.insert(layer) } else { selected.remove(layer) }
                })) {
                    HStack {
                        Text(layer.rawValue)
                        Spacer()
                        Text(detail(layer)).foregroundStyle(.secondary)
                    }
                }.toggleStyle(.checkbox)
            }
            Divider()
            HStack {
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(selected.count == Layer.allCases.count ? "Apply Scene" : "Apply Selected Layers") {
                    studio.prefs.scene = studio.prefs.scene.mixing(look.scene, layers: selected)
                    dismiss()
                }.keyboardShortcut(.defaultAction).disabled(selected.isEmpty)
            }
        }.padding(22).frame(width: 460)
    }
}

private struct EditPaletteView: View {
    @Environment(\.dismiss) var dismiss
    @State var draft: Palette
    @ObservedObject var studio: Studio
    var commit: (Palette) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Color palette").font(.headline)
            TextField("Name", text: $draft.name).textFieldStyle(.roundedBorder)
            PaletteEditor(colors: $draft.colors, studio: studio)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    commit(draft); dismiss()
                }.keyboardShortcut(.defaultAction).disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(22).frame(width: 380)
    }
}
