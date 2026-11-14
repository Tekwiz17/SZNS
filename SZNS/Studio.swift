import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension Color {
    init(rgb: Int) {
        self.init(.sRGB, red: Double((rgb >> 16) & 255) / 255,
                  green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }
    var rgb: Int {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return 0xffffff }
        func channel(_ value: CGFloat) -> Int { Int((min(1, max(0, value)) * 255).rounded()) }
        return (channel(c.redComponent) << 16) | (channel(c.greenComponent) << 8) | channel(c.blueComponent)
    }
}
enum StudioError: LocalizedError {
    case invalidPalette, invalidSVG, missingLook
    var errorDescription: String? {
        switch self {
        case .invalidPalette: return "Choose a SZNS palette with a name and 1–16 RGB colors."
        case .invalidSVG: return "Choose a standalone SVG under 2 MB with a visible silhouette."
        case .missingLook: return "That scene is no longer in Presets. Choose a saved scene in SZNS."
        }
    }
}
@MainActor
final class Studio: ObservableObject {
    static let shared = Studio()
    static let source = URL(string: "https://github.com/Tekwiz17/SZNS")!
    @Published var prefs: Preferences { didSet { queueSave() } }
    @Published var message: String?
    private var pendingSave: DispatchWorkItem?
    private let url: URL
    private var needsRecoveryCopy = false
    init(url: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SZNS/Preferences.json")) {
        self.url = url
        prefs = Preferences()
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                var stored = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: url))
                let upgraded = stored.installCelebrationsIfNeeded()
                let resized = stored.upgradeStockBulbsIfNeeded()
                prefs = stored
                if upgraded || resized { save() }
            }
            catch {
                needsRecoveryCopy = true
                message = "Couldn’t read saved settings. SZNS will keep a recovery copy before saving new settings. \(error.localizedDescription)"
            }
        }
    }
    private func queueSave() {
        pendingSave?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.save() }
        pendingSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }
    func save() {
        pendingSave?.cancel()
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if needsRecoveryCopy {
                let backup = url.deletingLastPathComponent().appendingPathComponent("Preferences-recovery-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: url, to: backup)
                needsRecoveryCopy = false
            }
            try JSONEncoder().encode(prefs).write(to: url, options: .atomic)
        } catch { message = "Couldn’t save settings. \(error.localizedDescription)" }
    }
    func checkForUpdates(silent: Bool = false) async {
        struct Release: Decodable { var tag_name: String }
        guard let endpoint = URL(string: "https://api.github.com/repos/Tekwiz17/SZNS/releases/latest") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: endpoint)
            let status = (response as? HTTPURLResponse)?.statusCode
            if status == 404 {
                if !silent { message = "There are no published SZNS releases yet." }
                return
            }
            guard status == 200 else { throw URLError(.badServerResponse) }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let version = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            if installed.compare(version, options: .numeric) == .orderedAscending {
                if silent {
                    message = "SZNS \(release.tag_name) is available. Open General → About SZNS → Check for updates to view the release."
                } else {
                    NSWorkspace.shared.open(Self.source.appendingPathComponent("releases/latest"))
                }
            } else if !silent { message = "SZNS \(installed) is up to date." }
        } catch { if !silent { message = "Couldn’t check for updates. \(error.localizedDescription)" } }
    }
    func importPalette() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let file = panel.url else { return }
        do {
            var p = try JSONDecoder().decode(Palette.self, from: Data(contentsOf: file))
            p.name = p.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !p.name.isEmpty, (1...16).contains(p.colors.count),
                  p.colors.allSatisfy({ (0...0xffffff).contains($0) }) else { throw StudioError.invalidPalette }
            p.id = UUID()
            prefs.palettes.append(p)
        } catch { message = error.localizedDescription }
    }
    func exportPalette(_ palette: Palette) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = palette.name + ".json"
        guard panel.runModal() == .OK, let file = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(palette).write(to: file, options: .atomic)
        } catch { message = error.localizedDescription }
    }
    func importBulb() -> Data? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.svg]
        guard panel.runModal() == .OK, let file = panel.url else { return nil }
        do {
            let info = try file.resourceValues(forKeys: [.fileSizeKey])
            guard let bytes = info.fileSize, bytes <= 2_000_000, let art = NSImage(contentsOf: file),
                  art.size.width > 0, art.size.height > 0 else { throw StudioError.invalidSVG }
            return try Self.bulbMask(from: art)
        } catch { message = error.localizedDescription; return nil }
    }
    static func bulbMask(from art: NSImage) throws -> Data {
        guard art.size.width > 0, art.size.height > 0 else { throw StudioError.invalidSVG }
        let dim = 128
        guard let bmp = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: dim, pixelsHigh: dim,
                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                   bytesPerRow: 0, bitsPerPixel: 0), let graphics = NSGraphicsContext(bitmapImageRep: bmp)
        else { throw StudioError.invalidSVG }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let canvas = CGRect(x: 0, y: 0, width: dim, height: dim)
        NSColor.clear.setFill()
        canvas.fill(using: .copy)
        let ratio = CGFloat(dim) / max(art.size.width, art.size.height)
        let size = CGSize(width: art.size.width * ratio, height: art.size.height * ratio)
        art.draw(in: CGRect(x: (CGFloat(dim) - size.width) / 2, y: (CGFloat(dim) - size.height) / 2,
                            width: size.width, height: size.height))
        NSGraphicsContext.restoreGraphicsState()
        let visible = (0..<dim).contains { y in
            (0..<dim).contains { x in (bmp.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0 }
        }
        guard visible, let png = bmp.representation(using: .png, properties: [:]) else { throw StudioError.invalidSVG }
        return png
    }

}
