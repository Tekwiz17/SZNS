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

    static func main() {
        _ = NSApplication.shared
        var firstFrames = Set<Data>()
        for effect in [Effect.ballDrop, .bats, .ghosts, .confetti] {
            var weather = Weather()
            weather.effect = effect
            weather.size = 8
            func frame(_ time: Double) -> Data {
                pixels { ctx, size in
                    WeatherDrawing.draw(in: ctx, size: size, weather: weather, time: time, preview: true)
                }
            }
            let first = frame(2), later = frame(10)
            precondition(first.contains { $0 != 0 } && later.contains { $0 != 0 }, "Empty \(effect.rawValue) frame")
            precondition(first != later && firstFrames.insert(first).inserted, "Missing motion or duplicate effect")
            print("PASS rendered two distinct \(effect.rawValue) frames")
        }
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
        for design in [Bulb.candyCane, .easterEgg, .graduationCap, .egg, .oval] {
            let image = strand(design)
            precondition(image != cable && bulbs.insert(image).inserted, "Missing or duplicate \(design.rawValue) design")
            print("PASS rendered distinct \(design.rawValue) strand")
        }
    }
}
