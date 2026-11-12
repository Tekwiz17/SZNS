import Foundation

enum Bulb: String, CaseIterable, Codable, Sendable {
    case oval = "Classic", globe = "Globe", diode = "Diode", icicle = "Icicle"
    case heart = "Heart", star = "Star", snowflake = "Snowflake", moon = "Moon"
    case bat = "Bat", ghost = "Ghost", pumpkin = "Pumpkin", clover = "Clover"
    case egg = "Egg", leaf = "Leaf", champagne = "Champagne", cocktail = "Cocktail", wine = "Wine"
    case lantern = "Lantern", digits = "Year digits", year = "Year badge"
    case graduationCap = "Graduation Cap", easterEgg = "Painted Easter Egg", candyCane = "Candy Cane"
    var displayName: String { self == .oval ? "Classic (OG)" : rawValue }
    case blossom = "Blossom", sun = "Sun", shell = "Shell", pine = "Pine", custom = "Imported SVG"
}
enum Pattern: String, CaseIterable, Codable, Sendable {
    case steady = "Always on", off = "Lights out", pulse = "Pulse", twinkle = "Twinkle"
    case chase = "Chase", wave = "Wave", every = "Every Nth"
}
enum Effect: String, CaseIterable, Codable, Sendable {
    case ballDrop = "Midnight Ball Drop", bats = "Flying Bats", ghosts = "Floating Ghosts", confetti = "Confetti"
    case snow = "Snow", leaves = "Leaves", petals = "Petals", fireflies = "Fireflies", fireworks = "Fireworks", rain = "Rain"
}
enum PointerStyle: String, CaseIterable, Codable {
    case none = "None", fade = "Fade", swing = "Sway"
}
enum Visibility: String, CaseIterable, Codable {
    case both = "Dock and menu bar", dock = "Dock only", menu = "Menu bar only", neither = "Neither"
    var showsDock: Bool { self == .dock || self == .both }
    var showsMenu: Bool { self == .menu || self == .both }
}
enum Power: String, CaseIterable, Codable {
    case automatic = "On low battery or in Low Power Mode", always = "Always", never = "Never"
}
struct Lights: Codable, Equatable {
    var enabled = true
    var bulb = Bulb.oval
    var customMask: Data?
    var pattern = Pattern.twinkle
    static let sizeRange = 3.0...64.0
    var size = 22.0, spacing = 34.0, speed = 1.0, variation = 0.35, density = 1.0, interval = 4.0
    var waveLength = 12.0
    var colors = [0xffd795, 0xef986d, 0xfdeac8]
    var useTemperature = false
    var temperature = 3200.0, opacity = 0.92
    var wire = 0x443b36
    var thickness = 1.4, span = 180.0, sag = 12.0
    var aboveApps = true
    var pointer = PointerStyle.none

    // Keep the bulb body inside even a small or partly revealed Dock. The stored
    // size and sag remain available when the Dock grows again.
    func fittingDock(depth: Double) -> Lights {
        var result = self
        let available = max(1, depth - thickness - 2)
        let bodyFactor = (1 + variation * 0.275) * 1.42
        result.size = min(size, available / bodyFactor)
        result.sag = min(sag, max(0, available - result.size * bodyFactor))
        return result
    }

    var depth: Double { ceil(sag + size * 2.4 + thickness + 10) }
}
struct Weather: Codable, Equatable {
    var enabled = true
    var effect = Effect.snow
    var density = 0.42, size = 4.0, speed = 1.0, wind = 0.12, repel = 0.45, opacity = 0.8
    var colors = [0xffffff, 0xd0eaff]
}
struct Scene: Codable, Equatable {
    var menu = Lights()
    var dock = Lights()
    var desktop = Weather()
}
struct Look: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var scene: Scene
}
struct Palette: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var colors: [Int]
}

enum Season: String, CaseIterable {
    case spring = "Cherry Orchard", summer = "Firefly Hour", autumn = "Amber Grove", winter = "First Frost"
    var colors: [Int] {
        switch self {
        case .spring: return [0xffb9c9, 0xffe5d0, 0xc6df99]
        case .summer: return [0xffcf63, 0xffec9a, 0x9de2b2]
        case .autumn: return [0xe98d47, 0xffcb77, 0xb85d42]
        case .winter: return [0xd4f2ff, 0xffdb9f, 0x91cfea]
        }
    }
    var scene: Scene {
        var scene = Scene()
        scene.menu.colors = colors
        switch self {
        case .spring: scene.menu.bulb = .blossom; scene.desktop.effect = .petals
        case .summer: scene.menu.bulb = .globe; scene.desktop.effect = .fireflies
        case .autumn: scene.menu.bulb = .leaf; scene.desktop.effect = .leaves
        case .winter: scene.menu.bulb = .icicle; scene.desktop.effect = .snow
        }
        scene.dock = scene.menu
        scene.dock.sag = 2
        scene.dock.span = 90
        scene.dock.size = 18
        scene.dock.spacing = 27
        scene.desktop.colors = self == .winter ? [0xf2faff, 0xbce2f9] : colors
        return scene
    }
}
// A celebration supplies both a complete scene and a reusable palette.
struct Celebration {
    let name: String
    let colors: [Int]
    let menu: Bulb
    let dock: Bulb
    let pattern: Pattern
    let effect: Effect
    var particles: [Int]? = nil
    var speed = 1.0
    var size = 5.0

    static let collection: [Celebration] = [
        .init(name: "Candy Cane", colors: [0xd92036, 0xfff7e9], menu: .candyCane, dock: .diode,
              pattern: .chase, effect: .snow, particles: [0xfff7e9, 0xffe4dc], speed: 0.7),
        .init(name: "Christmas Bulbs", colors: [0xe53a42, 0xffce52, 0x32b978, 0x4189ec, 0xf59636],
              menu: .oval, dock: .oval, pattern: .twinkle, effect: .snow, particles: [0xfff5e4]),
        .init(name: "Christmas Red & Green", colors: [0xe12d44, 0x188653], menu: .pine, dock: .oval,
              pattern: .steady, effect: .snow, particles: [0xf3fff9], speed: 0.65),
        .init(name: "4th of July", colors: [0xf34c55, 0xfffaf0, 0x4389f5], menu: .star, dock: .globe,
              pattern: .chase, effect: .fireworks),
        .init(name: "Fall Leaves", colors: [0xae442c, 0xdf7432, 0xf7b94c, 0xaa6735],
              menu: .leaf, dock: .pumpkin, pattern: .wave, effect: .leaves, speed: 0.8, size: 7),
        .init(name: "Easter Pastel", colors: [0xffbad1, 0xbce9d7, 0xcbbaf4, 0xffeaa4, 0xb6def9],
              menu: .easterEgg, dock: .blossom, pattern: .pulse, effect: .petals, speed: 0.65),
        .init(name: "Halloween Black & Orange", colors: [0x211e28, 0xff872f], menu: .pumpkin, dock: .bat,
              pattern: .twinkle, effect: .bats, particles: [0x332d43, 0xef964e], size: 7),
        .init(name: "Halloween Witch", colors: [0x91e765, 0x9754cf], menu: .moon, dock: .ghost,
              pattern: .wave, effect: .ghosts, particles: [0xe2ffd5, 0xd6b9f7], speed: 0.7, size: 8),
        .init(name: "Midnight Countdown", colors: [0xffd477, 0x9bdcff, 0xe9edff], menu: .star, dock: .digits,
              pattern: .chase, effect: .ballDrop, size: 8),
        .init(name: "Tassel Toss", colors: [0x463a75, 0xffce6c, 0xfff0cf], menu: .graduationCap, dock: .star,
              pattern: .wave, effect: .confetti, size: 6),
        .init(name: "Love Letters", colors: [0xc33b65, 0xffa8bf, 0xffead7], menu: .heart, dock: .blossom,
              pattern: .pulse, effect: .petals, speed: 0.6),
        .init(name: "Summer Solstice", colors: [0xffb34e, 0xffea8d, 0x68ccb4], menu: .sun, dock: .shell,
              pattern: .steady, effect: .fireflies, speed: 0.7)
    ]

    var scene: Scene {
        var scene = Scene()
        scene.menu.bulb = menu
        scene.menu.pattern = pattern
        scene.menu.colors = colors
        scene.menu.speed = speed
        scene.menu.size = 24
        scene.menu.spacing = 36
        scene.dock = scene.menu
        scene.dock.bulb = dock
        scene.dock.sag = 2
        scene.dock.span = 90
        scene.dock.size = 20
        scene.dock.spacing = 30
        scene.desktop.effect = effect
        scene.desktop.size = size
        scene.desktop.speed = speed
        scene.desktop.colors = particles ?? colors
        return scene
    }
}
struct Preferences: Codable, Equatable {
    var scene = Season.winter.scene
    var looks = Season.allCases.map { Look(name: $0.rawValue, scene: $0.scene) }
    var palettes = Season.allCases.map { Palette(name: $0.rawValue, colors: $0.colors) }
    var visibility = Visibility.both
    var power = Power.automatic
    var welcomed = false
    // An absent revision identifies a preferences file written before the celebrations shipped.
    private(set) var celebrationRevision: Int?

    private(set) var bulbSizeRevision: Int?

    init() {
        installCelebrationsIfNeeded()
        bulbSizeRevision = 1
    }

    // Replace only the exact stock scenes shipped in v1. A user's chosen bulb size,
    // imported mask, renamed look, and Shortcuts identifier survive this upgrade.
    @discardableResult
    mutating func upgradeStockBulbsIfNeeded() -> Bool {
        guard (bulbSizeRevision ?? 0) < 1 else { return false }
        let stock = Season.allCases.map { ($0.scene, 9.0, 7.0, 24.0, 18.0) } +
                    Celebration.collection.map { ($0.scene, 12.0, 9.0, 29.0, 21.0) }
        for (revised, ms, ds, spacing, dockSpacing) in stock {
            var old = revised
            old.menu.size = ms
            old.dock.size = ds
            old.menu.spacing = spacing
            old.dock.spacing = dockSpacing
            if scene == old { scene = revised }
            for i in looks.indices where looks[i].scene == old { looks[i].scene = revised }
        }
        bulbSizeRevision = 1
        return true
    }

    @discardableResult
    mutating func installCelebrationsIfNeeded() -> Bool {
        guard (celebrationRevision ?? 0) < 1 else { return false }
        for item in Celebration.collection {
            // Keep a user-created preset with the same name independently selectable.
            let lookName = looks.contains { $0.name == item.name } ? item.name + " (SZNS)" : item.name
            let paletteName = palettes.contains { $0.name == item.name } ? item.name + " (SZNS)" : item.name
            looks.append(Look(name: lookName, scene: item.scene))
            palettes.append(Palette(name: paletteName, colors: item.colors))
        }
        celebrationRevision = 1
        return true
    }
}

func variation(_ index: Int, _ salt: Int = 0) -> Double {
    var bits = UInt64(truncatingIfNeeded: index) &* 0x9e3779b97f4a7c15 &+ UInt64(salt)
    bits = (bits ^ (bits >> 30)) &* 0xbf58476d1ce4e5b9
    bits = (bits ^ (bits >> 27)) &* 0x94d049bb133111eb
    return Double(bits ^ (bits >> 31)) / Double(UInt64.max)
}
func brightness(_ lights: Lights, index: Int, time: Double) -> Double {
    let phase = time * lights.speed
    let offset = variation(index, 13) * lights.variation
    switch lights.pattern {
    case .steady: return 1
    case .off: return 0
    case .pulse: return 0.55 + 0.45 * sin(phase * 2 + offset)
    case .twinkle: return 0.58 + 0.42 * sin(phase * (1 + offset) + variation(index, 21) * 14)
    case .chase: return (index + Int(phase * 3)) % max(2, Int(lights.interval)) == 0 ? 1 : 0.16
    case .wave: return 0.57 + 0.43 * sin(phase * 2 - Double(index) * (2 * .pi / max(2, lights.waveLength)) + offset)
    case .every: return index % max(2, Int(lights.interval)) == 0 ? 1 : 0.1
    }
}

