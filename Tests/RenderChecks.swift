import AppKit
import SwiftUI

@main
@MainActor
enum RenderChecks {
    static func pixels(_ draw: @escaping (GraphicsContext, CGSize) -> Void) -> Data {
        let width = 256, height = 144
        let view = Canvas { ctx, size in draw(ctx, size) }.frame(width: CGFloat(width), height: CGFloat(height))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.cgImage else { fatalError("Could not render the scene") }
        var pixels = Data(count: width * height * 4)
        pixels.withUnsafeMutableBytes { raw in
            let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }

    static func checkPreferenceRecovery() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Preferences.json")
        let damaged = Data("{ incomplete settings".utf8)
        try damaged.write(to: url)
        let studio = Studio(url: url)
        precondition(studio.message != nil)
        studio.save()
        studio.save()
        let names = try fm.contentsOfDirectory(atPath: dir.path)
        let copies = names.filter { $0.hasPrefix("Preferences-recovery-") && $0.hasSuffix(".json") }
        precondition(copies.count == 1, "Expected one recovery copy after two saves, found \(names)")
        let preserved = try Data(contentsOf: dir.appendingPathComponent(copies[0]))
        let saved = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: url))
        precondition(preserved == damaged, "Original settings bytes changed")
        precondition(saved == studio.prefs, "Written defaults do not match the active settings")
        print("PASS original unreadable preferences preserved across repeated saves")
    }

    static func checkSnowPiles() {
        func frame(age: Double, piles: Bool, density: Double = 0.8, effect: Effect = .snow) -> Data {
            var weather = Weather()
            weather.effect = effect
            weather.pilesEnabled = piles
            weather.density = density
            return pixels { ctx, size in
                WeatherDrawing.draw(in: ctx, size: size, weather: weather, time: age, preview: true, effectAge: age)
            }
        }
        func pilePixels(at age: Double) -> Int {
            let snow = frame(age: age, piles: true), flakes = frame(age: age, piles: false)
            var changed = 0
            for index in stride(from: 0, to: snow.count, by: 4) where snow[index..<index+4] != flakes[index..<index+4] {
                let row = index / (4 * 256)
                precondition(row < 19 || row >= 144 - 19, "Snow bank exceeded its desktop-edge depth limit")
                changed += 1
            }
            return changed
        }
        precondition(pilePixels(at: 0) == 0 && pilePixels(at: 32) > pilePixels(at: 2), "Snow did not build from recent landings")
        precondition(pilePixels(at: 3600) > 0, "Snow disappeared after prolonged snowfall")
        precondition(frame(age: 40, piles: true) == frame(age: 40, piles: true), "Reduced Motion bank is unstable")
        precondition(frame(age: 40, piles: true, density: 0).allSatisfy { $0 == 0 }, "Zero snowfall left a bank")
        precondition(frame(age: 40, piles: true, effect: .rain) == frame(age: 40, piles: false, effect: .rain), "Snow leaked into rain")
        print("PASS snow growth, bounded depth, stationary frame, opt-out and zero amount")
    }

    static func checkAutumnGround() {
        var weather = Weather()
        weather.effect = .leaves
        weather.colors = [0xbe582d, 0xf4aa46, 0xba303b]
        weather.density = 0.82
        weather.size = 8
        func render(_ weather: Weather, age: Double) -> Data {
            pixels { ctx, size in WeatherDrawing.draw(in: ctx, size: size, weather: weather,
                                                      time: 123, preview: true, effectAge: age) }
        }
        var bare = weather
        bare.leafPilesEnabled = false
        precondition(render(weather, age: 0) == render(bare, age: 0), "Leaves jumped when piles were toggled")
        let settled = render(weather, age: 18), falling = render(bare, age: 18)
        precondition(settled != falling, "Settled leaves missing")
        func checkGroundOnly(_ a: Data, _ b: Data, maxRows: Int) {
            for i in stride(from: 0, to: a.count, by: 4) where a[i..<i+4] != b[i..<i+4] {
                let row = i / (256 * 4)
                precondition(row < maxRows || row >= 144 - maxRows, "Ground decoration displaced falling particles")
            }
        }
        checkGroundOnly(settled, falling, maxRows: 22)
        var lit = weather
        lit.pumpkinsEnabled = true
        let lanterns = render(lit, age: 18)
        precondition(lanterns != settled && lanterns == render(lit, age: 18), "Missing or unstable jack-o’-lanterns")
        checkGroundOnly(lanterns, settled, maxRows: 38)
        lit.density = 0
        precondition(render(lit, age: 18).allSatisfy { $0 == 0 }, "Zero density left decorations on screen")
        print("PASS leaf landings, independent pumpkins, ground bounds and still frames")
    }

    static func checkImportedBulbsAndColors() throws {
        let empty = NSImage(size: .init(width: 20, height: 20), flipped: false) { _ in true }
        do {
            _ = try Studio.bulbMask(from: empty)
            fatalError("Blank imported bulb was accepted")
        } catch StudioError.invalidSVG { }
        let narrow = NSImage(size: .init(width: 10, height: 20), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            return true
        }
        let png = try Studio.bulbMask(from: narrow)
        let bitmap = NSBitmapImageRep(data: png)!
        precondition(bitmap.colorAt(x: 0, y: 64)?.alphaComponent == 0, "Custom bulb padding is opaque")
        precondition(bitmap.colorAt(x: 64, y: 64)?.alphaComponent == 1, "Visible custom bulb disappeared")
        let extended = Color(nsColor: NSColor(srgbRed: 1.2, green: -0.1, blue: 0.5, alpha: 1))
        precondition(extended.rgb == 0xff0080, "Extended color channels overflowed the RGB palette")
        print("PASS empty bulb rejection, transparent padding and bounded RGB colors")
    }

    static func main() throws {
        _ = NSApplication.shared
        try checkPreferenceRecovery()
        try checkImportedBulbsAndColors()
        checkSnowPiles()
        checkAutumnGround()
        var firstFrames = Set<Data>()
        for effect in [Effect.ballDrop, .bats, .ghosts, .confetti, .aurora, .meteors, .tide, .pond, .lanterns, .bubbles, .rain] {
            var weather = Weather()
            weather.effect = effect
            weather.size = 8
            func frame(_ time: Double) -> Data {
                pixels { ctx, size in
                    WeatherDrawing.draw(in: ctx, size: size, weather: weather, time: time, preview: true)
                }
            }
            let still = frame(0)
            precondition(still.contains { $0 != 0 } && still == frame(0), "Empty or unstable Reduce Motion frame")
            let first = frame(2), later = frame(10)
            precondition(first.contains { $0 != 0 } && later.contains { $0 != 0 }, "Empty \(effect.rawValue) frame")
            precondition(first != later && firstFrames.insert(first).inserted, "Missing motion or duplicate effect")
            print("PASS rendered two distinct \(effect.rawValue) frames")
        }
        var sparseSnow = Weather()
        sparseSnow.density = 0.05
        let sparse = pixels { ctx, size in
            WeatherDrawing.draw(in: ctx, size: size, weather: sparseSnow, time: 1)
        }
        precondition(sparse.contains { $0 != 0 }, "Low-density weather disappeared")
        func strand(_ design: Bulb, density: Double = 1) -> Data {
            var lights = Lights()
            lights.bulb = design
            lights.pattern = .steady
            lights.density = density
            lights.size = 18
            return pixels { ctx, size in LightDrawing.draw(in: ctx, size: size, lights: lights, time: 0) }
        }
        var digits = Lights()
        digits.bulb = .digits
        digits.pattern = .steady
        func yearFrame(_ year: Int) -> Data {
            pixels { ctx, size in LightDrawing.draw(in: ctx, size: size, lights: digits, time: 0, displayedYear: year) }
        }
        precondition(yearFrame(2026) != yearFrame(2027), "Static year bulbs did not change at New Year")
        print("PASS steady year bulbs reflect a calendar rollover")
        let cable = strand(.oval, density: 0)
        var bulbs = Set<Data>()
        for design in [Bulb.candyCane, .easterEgg, .graduationCap, .egg, .oval, .prism, .saturn, .jelly, .koi, .skyLantern, .seaGlass] {
            let image = strand(design)
            precondition(image != cable && bulbs.insert(image).inserted, "Missing or duplicate \(design.rawValue) design")
            print("PASS rendered distinct \(design.rawValue) strand")
        }
    }
}
