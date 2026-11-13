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

    static func main() throws {
        _ = NSApplication.shared
        try checkPreferenceRecovery()
        var firstFrames = Set<Data>()
        for effect in [Effect.ballDrop, .bats, .ghosts, .confetti, .aurora, .meteors, .tide, .pond, .lanterns] {
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
        let cable = strand(.oval, density: 0)
        var bulbs = Set<Data>()
        for design in [Bulb.candyCane, .easterEgg, .graduationCap, .egg, .oval, .prism, .saturn, .jelly, .koi, .skyLantern] {
            let image = strand(design)
            precondition(image != cable && bulbs.insert(image).inserted, "Missing or duplicate \(design.rawValue) design")
            print("PASS rendered distinct \(design.rawValue) strand")
        }
    }
}
