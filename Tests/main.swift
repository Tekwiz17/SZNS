import Foundation

// Run with the two Foundation-only production sources. A failed check exits nonzero.
var passed = 0
func check(_ name: String, _ assertion: @autoclosure () throws -> Bool) rethrows {
    guard try assertion() else { fatalError(name) }
    passed += 1
    print("PASS \(name)")
}

let original = Preferences()
let data = try JSONEncoder().encode(original)
try check("Every preference round-trips", try JSONDecoder().decode(Preferences.self, from: data) == original)
check("Four distinct starter scenes", Set(original.looks.map { $0.scene.desktop.effect }).count == 4)
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

