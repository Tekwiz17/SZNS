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
check("Every celebration has its matching full scene and palette", (Celebration.collection + Celebration.nightScenes).allSatisfy { item in
    original.looks.contains { $0.name == item.name && $0.scene == item.scene } &&
    original.palettes.contains { $0.name == item.name && $0.colors == item.colors }
})
check("The full catalog has unique names", original.looks.count == 19 && Set(original.looks.map(\.name)).count == 19)
let reef = original.looks.first { $0.name == "Moonlit Reef" }!
check("Search by words across name, effect and bulbs", reef.matches("REEF jellyfish shell") && !reef.matches("reef prism"))
var versionOne = original
versionOne.looks = [Look(name: "My saved scene", scene: original.scene, favorite: true)]
versionOne.palettes = []
var v1JSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(versionOne)) as! [String: Any]
v1JSON["celebrationRevision"] = 1
var nextVersion = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: v1JSON))
check("1.1 upgrade adds exactly three scenes and palettes", nextVersion.installCelebrationsIfNeeded() &&
      nextVersion.looks.count == 4 && nextVersion.palettes.count == 3)
check("Existing active scene, favorite and IDs survive", nextVersion.scene == versionOne.scene && nextVersion.looks.first == versionOne.looks.first)
nextVersion.looks.removeLast()
check("Deleted night scenes stay deleted", !nextVersion.installCelebrationsIfNeeded() && nextVersion.looks.count == 3)
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
let display = DockDisplay(frame: primary, usable: primary.insetBy(dx: 0, dy: 68))
check("Reject full-screen Dock event window", display.dockBounds(primary, side: .bottom, useReservedEdge: true) == nil)
let tiles = CGRect(x: 499, y: 8, width: 514, height: 48)
check("Use real tile span and reserved lip", display.dockBounds(tiles, side: .bottom, useReservedEdge: true) ==
      CGRect(x: 499, y: 0, width: 514, height: 68))
check("Ignore floating Dock popup", display.dockBounds(tiles.offsetBy(dx: 0, dy: 90), side: .bottom, useReservedEdge: true) == nil)
check("Reject auto-hide activation sliver", display.dockBounds(CGRect(x: 400, y: 0, width: 300, height: 2), side: .bottom, useReservedEdge: false) == nil)
check("An oversized overlay stays on the Dock", DisplayGeometry.dockStrip(dock, screen: primary, depth: 240)?.0 == dock)
check("Every starter scene has larger bulbs", original.looks.allSatisfy { $0.scene.menu.size >= 22 && $0.scene.dock.size >= 18 })
var big = Lights()
big.size = 64
big.sag = 70
let fit = big.fittingDock(depth: 36)
check("Large bulb fits a shallow Dock without changing its stored size", fit.size < 36 && fit.sag < 1 && big.size == 64)
var oldBulbs = original
var oldWinter = Season.winter.scene
oldWinter.menu.size = 9; oldWinter.dock.size = 7; oldWinter.menu.spacing = 24; oldWinter.dock.spacing = 18
oldBulbs.scene = oldWinter
var edited = oldWinter
edited.dock.size = 14
oldBulbs.looks = [Look(name: "Renamed stock", scene: oldWinter), Look(name: "Custom", scene: edited)]
var bulbJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(oldBulbs)) as! [String: Any]
bulbJSON.removeValue(forKey: "bulbSizeRevision")
var migrated = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: bulbJSON))
check("Upgrade exact stock preset sizes once", migrated.upgradeStockBulbsIfNeeded() && migrated.scene == Season.winter.scene &&
      migrated.looks[0].scene == migrated.scene && migrated.looks[0].id == oldBulbs.looks[0].id && !migrated.upgradeStockBulbsIfNeeded())
check("Preserve custom bulb sizes on upgrade", migrated.looks[1] == oldBulbs.looks[1])
print("\(passed) checks passed")

