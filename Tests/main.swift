import Foundation
import CoreGraphics

// Run with the two production sources. A failed check exits nonzero.
var passed = 0
func check(_ name: String, _ assertion: @autoclosure () throws -> Bool) rethrows {
    guard try assertion() else { fatalError(name) }
    passed += 1
    print("PASS \(name)")
}

let original = Preferences()
let data = try JSONEncoder().encode(original)
try check("Every preference round-trips", try JSONDecoder().decode(Preferences.self, from: data) == original)
check("Original four seasonal scenes remain available", Season.allCases.allSatisfy { season in
    original.looks.contains { $0.name == season.rawValue && $0.scene == season.scene }
})
check("Every celebration has its matching full scene and palette", Celebration.collection.allSatisfy { item in
    original.looks.contains { $0.name == item.name && $0.scene == item.scene } &&
    original.palettes.contains { $0.name == item.name && $0.colors == item.colors }
})
check("The full catalog has unique names", original.looks.count == 16 && Set(original.looks.map(\.name)).count == 16)
let partyEffects: [String: Effect] = ["4th of July": .fireworks, "Midnight Countdown": .ballDrop,
                                      "Halloween Black & Orange": .bats, "Halloween Witch": .ghosts, "Tassel Toss": .confetti]
check("Celebrations use their corresponding desktop effects", partyEffects.allSatisfy { name, effect in
    original.looks.first(where: { $0.name == name })?.scene.desktop.effect == effect
})

// Reproduce the exact preference-file shape shipped before the collection was added.
var legacy = original
legacy.looks = [Look(name: "Candy Cane", scene: Season.summer.scene)]
legacy.palettes = [Palette(name: "Candy Cane", colors: [0x010203])]
legacy.scene = Season.autumn.scene
legacy.visibility = .neither
legacy.welcomed = true
var oldJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
oldJSON.removeValue(forKey: "celebrationRevision")
let oldData = try JSONSerialization.data(withJSONObject: oldJSON)
var upgraded = try JSONDecoder().decode(Preferences.self, from: oldData)
check("Installed collection on a pre-update preference file", upgraded.installCelebrationsIfNeeded())
check("Upgrade preserves user presets, IDs, active scene and preferences",
      upgraded.looks.first == legacy.looks.first && upgraded.palettes.first == legacy.palettes.first &&
      upgraded.scene == legacy.scene && upgraded.visibility == .neither && upgraded.welcomed)
check("Upgrade preserves intentional deletions of original presets", !upgraded.looks.contains { $0.name == "First Frost" })
check("Same-name user entries remain independently selectable",
      upgraded.looks.contains { $0.name == "Candy Cane (SZNS)" } && upgraded.palettes.contains { $0.name == "Candy Cane (SZNS)" })
upgraded.looks.removeLast()
upgraded.palettes.removeLast()
var reopened = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(upgraded))
check("Reopening does not duplicate or resurrect deleted presets", !reopened.installCelebrationsIfNeeded() && reopened == upgraded)
check("All starter palettes are valid", original.palettes.allSatisfy { !$0.colors.isEmpty && $0.colors.allSatisfy { (0...0xffffff).contains($0) } })
check("Four visibility modes", Visibility.allCases.map { [$0.showsDock, $0.showsMenu] } == [[true,true],[true,false],[false,true],[false,false]])
var custom = original.scene
custom.menu.size = 27
check("Editing a scene preserves its saved snapshot", original.looks.last?.scene.menu.size != custom.menu.size)
custom.dock.customMask = Data([0, 8, 13])
let snapshot = Look(name: "My Studio", scene: custom)
let saved = try JSONEncoder().encode(snapshot)
try check("Custom mask survives scene storage", try JSONDecoder().decode(Look.self, from: saved) == snapshot)
for pattern in Pattern.allCases {
    var lights = Lights()
    lights.pattern = pattern
    check("Valid intensity for \(pattern.rawValue)", (0..<128).allSatisfy {
        (0...1.000001).contains(brightness(lights, index: $0, time: Double($0) / 3))
    })
}
let primary = CGRect(x: 0, y: 0, width: 1512, height: 982)
let secondary = CGRect(x: -1440, y: 982, width: 1440, height: 900)
let dock = CGRect(x: 500, y: 0, width: 512, height: 64)
check("Bottom Dock follows its upper edge", DisplayGeometry.dockStrip(dock, screen: primary, depth: 24)?.0 == CGRect(x: 500,y: 40,width: 512,height: 24))
let ax = CGRect(x: -1440, y: -800, width: 74, height: 450)
let left = DisplayGeometry.cocoa(ax, primaryHeight: primary.height)
check("AX conversion handles higher, negative-X screen", left == CGRect(x: -1440,y: 1332,width: 74,height: 450))
check("Left Dock follows its inner edge", DisplayGeometry.dockStrip(left, screen: secondary, depth: 24)?.0.minX == left.maxX - 24)
let right = CGRect(x: 1450, y: 120, width: 62, height: 600)
check("Right Dock follows its inner edge", DisplayGeometry.dockStrip(right, screen: primary, depth: 24)?.1 == .right)
check("Hidden Dock produces no strip", DisplayGeometry.dockStrip(dock.offsetBy(dx: 0, dy: -63), screen: primary, depth: 24) == nil)
check("Dock is excluded from other displays", DisplayGeometry.dockStrip(left, screen: primary, depth: 24) == nil)
print("\(passed) checks passed")

