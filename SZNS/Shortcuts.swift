import AppIntents
import Foundation

extension Layer: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Decoration"
    static var caseDisplayRepresentations: [Layer: DisplayRepresentation] = [.menu: "Menu Bar", .dock: "Dock", .desktop: "Desktop"]
}
enum SwitchAction: String, AppEnum {
    case on, off, toggle
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Switch"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.on: "Turn on", .off: "Turn off", .toggle: "Toggle"]
}
struct SetDecorationIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch SZNS Decoration"
    static var description = IntentDescription("Turn the menu bar lights, Dock lights, or desktop effects on or off.")
    @Parameter(title: "Action") var action: SwitchAction
    @Parameter(title: "Decoration") var layer: Layer
    static var parameterSummary: some ParameterSummary { Summary("\(\.$action) \(\.$layer)") }
    @MainActor func perform() async throws -> some IntentResult {
        let studio = Studio.shared
        func next(_ old: Bool) -> Bool { action == .toggle ? !old : action == .on }
        switch layer {
        case .menu: studio.prefs.scene.menu.enabled = next(studio.prefs.scene.menu.enabled)
        case .dock: studio.prefs.scene.dock.enabled = next(studio.prefs.scene.dock.enabled)
        case .desktop: studio.prefs.scene.desktop.enabled = next(studio.prefs.scene.desktop.enabled)
        }
        studio.save()
        return .result()
    }
}
struct SceneChoice: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "SZNS Scene"
    static var defaultQuery = SceneQuery()
    var id: UUID
    var name: String
    var displayRepresentation: DisplayRepresentation { .init(title: "\(name)") }
}
struct SceneQuery: EntityStringQuery {
    @MainActor func suggestedEntities() async throws -> [SceneChoice] {
        Studio.shared.prefs.looks.map { SceneChoice(id: $0.id, name: $0.name) }
    }
    func entities(for identifiers: [UUID]) async throws -> [SceneChoice] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
    func entities(matching string: String) async throws -> [SceneChoice] {
        try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}
struct ApplySceneIntent: AppIntent {
    static var title: LocalizedStringResource = "Apply SZNS Scene"
    @Parameter(title: "Scene") var scene: SceneChoice
    static var parameterSummary: some ParameterSummary { Summary("Apply \(\.$scene)") }
    @MainActor func perform() async throws -> some IntentResult {
        let studio = Studio.shared
        guard let look = studio.prefs.looks.first(where: { $0.id == scene.id }) else { throw StudioError.missingLook }
        studio.prefs.scene = look.scene; studio.save()
        return .result()
    }
}

extension Effect: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Desktop Effect"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .snow: "Snow", .leaves: "Leaves", .petals: "Petals", .fireflies: "Fireflies", .fireworks: "Fireworks", .rain: "Rain"
    ]
}
struct SetWeatherIntent: AppIntent {
    static var title: LocalizedStringResource = "Set SZNS Desktop Effect"
    @Parameter(title: "Effect") var effect: Effect
    @Parameter(title: "Amount (%)", default: 45, inclusiveRange: (0, 100)) var amount: Int
    @Parameter(title: "Size (points)", default: 4, inclusiveRange: (1, 16)) var size: Int
    @Parameter(title: "Speed (%)", default: 100, inclusiveRange: (10, 300)) var speed: Int
    @Parameter(title: "Wind (left −100 to right 100)", default: 0, inclusiveRange: (-100, 100)) var wind: Int
    @Parameter(title: "Pointer repulsion (%)", default: 45, inclusiveRange: (0, 100)) var repel: Int
    @MainActor func perform() async throws -> some IntentResult {
        let studio = Studio.shared
        var desktop = studio.prefs.scene.desktop
        desktop.enabled = true; desktop.effect = effect; desktop.density = Double(amount) / 100
        desktop.size = Double(size); desktop.speed = Double(speed) / 100
        desktop.wind = Double(wind) / 100; desktop.repel = Double(repel) / 100
        studio.prefs.scene.desktop = desktop; studio.save()
        return .result()
    }
}
enum StrandChoice: String, AppEnum {
    case dock, menu
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Light String"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.dock: "Dock", .menu: "Menu Bar"]
}
extension Pattern: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Light Pattern"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .steady: "Always on", .off: "Lights out", .pulse: "Pulse", .twinkle: "Twinkle", .chase: "Chase", .wave: "Wave", .every: "Every Nth"
    ]
}
struct SetLightPatternIntent: AppIntent {
    static var title: LocalizedStringResource = "Set SZNS Light Pattern"
    @Parameter(title: "String") var strand: StrandChoice
    @Parameter(title: "Pattern") var pattern: Pattern
    @Parameter(title: "Speed (%)", default: 100, inclusiveRange: (10, 300)) var speed: Int
    @Parameter(title: "Variation (%)", default: 35, inclusiveRange: (0, 100)) var variation: Int
    @MainActor func perform() async throws -> some IntentResult {
        let studio = Studio.shared
        let path: WritableKeyPath<Scene, Lights> = strand == .dock ? \.dock : \.menu
        var lights = studio.prefs.scene[keyPath: path]
        lights.pattern = pattern; lights.speed = Double(speed) / 100; lights.variation = Double(variation) / 100
        studio.prefs.scene[keyPath: path] = lights; studio.save()
        return .result()
    }
}


enum StrandSetting: String, AppEnum {
    case size, spacing, density, opacity, temperature, thickness, span, sag, interval, wavelength
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Strand Setting"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .size: "Bulb size (points)", .spacing: "Bulb distance (points)", .density: "Density (%)",
        .opacity: "Opacity (%)", .temperature: "Temperature (kelvin)", .thickness: "Cable thickness (points)",
        .span: "Cable drop width (points)", .sag: "Cable drop height (points)",
        .interval: "Pattern interval (bulbs)", .wavelength: "Wavelength (bulbs)"
    ]
    var limits: ClosedRange<Double> {
        switch self {
        case .size: return 3...28
        case .spacing: return 8...90
        case .density, .opacity: return 5...100
        case .temperature: return 1800...10000
        case .thickness: return 0.5...5
        case .span: return 30...520
        case .sag: return 0...70
        case .interval: return 2...24
        case .wavelength: return 2...48
        }
    }
}
struct SetStrandValueIntent: AppIntent {
    static var title: LocalizedStringResource = "Adjust SZNS Light Setting"
    @Parameter(title: "String") var strand: StrandChoice
    @Parameter(title: "Setting") var setting: StrandSetting
    @Parameter(title: "Value") var value: Double
    static var parameterSummary: some ParameterSummary { Summary("Set \(\.$strand) \(\.$setting) to \(\.$value)") }
    @MainActor func perform() async throws -> some IntentResult {
        let range = setting.limits
        guard range.contains(value) else {
            throw NSError(domain: "SZNS", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Choose a value from \(range.lowerBound) to \(range.upperBound)."])
        }
        let studio = Studio.shared
        let path: WritableKeyPath<Scene, Lights> = strand == .dock ? \.dock : \.menu
        var light = studio.prefs.scene[keyPath: path]
        switch setting {
        case .size: light.size = value
        case .spacing: light.spacing = value
        case .density: light.density = value / 100
        case .opacity: light.opacity = value / 100
        case .temperature: light.temperature = value; light.useTemperature = true
        case .thickness: light.thickness = value
        case .span: light.span = value
        case .sag: light.sag = value
        case .interval: light.interval = value.rounded()
        case .wavelength: light.waveLength = value.rounded()
        }
        studio.prefs.scene[keyPath: path] = light; studio.save()
        return .result()
    }
}
