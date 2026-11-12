import SwiftUI

enum WeatherDrawing {
    static func draw(in ctx: GraphicsContext, size: CGSize, weather: Weather, time: Double,
                     pointer: CGPoint? = nil, preview: Bool = false) {
        guard weather.enabled, weather.density > 0, size.width > 0, size.height > 0 else { return }
        let w = size.width, h = size.height
        let colors = weather.colors.isEmpty ? [0xffffff] : weather.colors
        let count = Int(min(700, max(1, w * h / (preview ? 800 : 4700)) * weather.density))
        let t = time * weather.speed
        if weather.effect == .fireworks {
            for i in 0..<max(1, count / 15) {
                let age = t * 0.34 + variation(i, 43)
                let phase = age - floor(age)
                let event = i * 2048 + Int(floor(age))
                let center = CGPoint(x: w * (0.12 + 0.76 * variation(event, 12)),
                                     y: h * (0.13 + 0.51 * variation(event, 14)))
                let color = Color(rgb: colors[Int(variation(event, 4) * 999) % colors.count])
                let reach = min(w, h) * (0.07 + variation(event, 22) * 0.12)
                for k in 0..<28 {
                    let angle = Double(k) * .pi * 2 / 28
                    let spread = pow(phase, 0.68) * reach
                    let drift = weather.wind * phase * 32
                    let x = center.x + cos(angle) * spread + drift
                    let y = center.y + sin(angle) * spread + reach * phase * phase * 0.42
                    var ray = Path()
                    ray.move(to: .init(x: x - cos(angle) * reach * 0.09, y: y - sin(angle) * reach * 0.09))
                    ray.addLine(to: .init(x: x, y: y))
                    ctx.stroke(ray, with: .color(color.opacity((1 - phase) * weather.opacity)),
                               style: .init(lineWidth: max(0.6, weather.size * 0.42), lineCap: .round))
                }
            }
            return
        }
        for i in 0..<count {
            let seed = variation(i, 4)
            let depth = 0.45 + 0.78 * variation(i, 5)
            let speed = weather.effect == .rain ? 145.0 : weather.effect == .fireflies ? 7 : 28
            let sway = weather.effect == .leaves || weather.effect == .petals ? 17.0 : 6
            func wrap(_ value: Double, _ period: Double) -> Double { value - floor(value / period) * period }
            var x = wrap(seed * w + weather.wind * t * 47 * depth + sin(t * 0.8 + seed * 100) * sway, w + 20) - 10
            var y = wrap(variation(i, 8) * h + t * speed * depth, h + 20) - 10
            if let pointer, weather.repel > 0 {
                let dx = x - pointer.x, dy = y - pointer.y
                let distance = hypot(dx, dy)
                let push = max(0, 1 - distance / 92) * weather.repel * 70
                x += push * dx / max(1, distance); y += push * dy / max(1, distance)
            }
            let radius = weather.size * depth * (preview ? 0.8 : 1)
            let color = Color(rgb: colors[i % colors.count])
            var particle = ctx
            particle.opacity = weather.opacity * (0.54 + 0.45 * seed)
            particle.translateBy(x: x, y: y)
            switch weather.effect {
            case .snow:
                if radius > 4 {
                    particle.rotate(by: .radians(t * 0.24 + seed * 7))
                    particle.scaleBy(x: radius * 1.6, y: radius * 1.6)
                    particle.fill(LightDrawing.silhouette(.snowflake), with: .color(color))
                } else {
                    particle.fill(Path(ellipseIn: .init(x: -radius / 2, y: -radius / 2, width: radius, height: radius)), with: .color(color))
                }
            case .leaves, .petals:
                particle.rotate(by: .radians(t * 0.7 + seed * 20))
                particle.scaleBy(x: radius * 2 * (0.4 + 0.6 * abs(cos(t + seed * 9))), y: radius * 2.1)
                particle.fill(LightDrawing.silhouette(weather.effect == .leaves ? .leaf : .egg), with: .color(color))
            case .fireflies:
                particle.opacity *= 0.6 + 0.4 * sin(t + seed * 40)
                let r = radius * 1.7
                particle.fill(Path(ellipseIn: .init(x: -r, y: -r, width: 2*r, height: 2*r)),
                              with: .radialGradient(Gradient(colors: [.white, color.opacity(0.8), .clear]),
                                                    center: .zero, startRadius: 0, endRadius: r))
            case .rain:
                var drop = Path()
                drop.move(to: .zero); drop.addLine(to: .init(x: -weather.wind * radius, y: -radius * 2.8))
                particle.stroke(drop, with: .color(color), style: .init(lineWidth: max(0.7, radius * 0.25), lineCap: .round))
            case .fireworks: break
            }
        }
    }
}

enum Layer: String, CaseIterable, Sendable { case menu = "Menu Bar", dock = "Dock", desktop = "Desktop" }

struct ScenePreview: View {
    var scene: Scene
    var focus: Layer? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { tick in
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let t = reduceMotion ? 0 : tick.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86400)
                let area = CGRect(origin: .zero, size: size)
                let sky: [Color] = {
                    switch scene.desktop.effect {
                    case .petals: return [Color(rgb: 0x504668), Color(rgb: 0xd09699)]
                    case .leaves: return [Color(rgb: 0x413943), Color(rgb: 0xd49562)]
                    case .fireflies: return [Color(rgb: 0x193f4c), Color(rgb: 0x799285)]
                    default: return [Color(rgb: 0x203951), Color(rgb: 0x7b9fab)]
                    }
                }()
                ctx.fill(Path(area), with: .linearGradient(Gradient(colors: sky), startPoint: .zero, endPoint: CGPoint(x: w * 0.8, y: h * 1.3)))
                let moon = CGRect(x: w * 0.74, y: h * 0.23, width: h * 0.2, height: h * 0.2)
                ctx.fill(Path(ellipseIn: moon), with: .color(Color(rgb: 0xffe5b7).opacity(0.86)))
                for j in 0..<3 {
                    let base = h * (0.55 + Double(j) * 0.13)
                    var ridge = Path()
                    ridge.move(to: CGPoint(x: 0, y: h))
                    for k in 0...90 {
                        let u = Double(k) / 90
                        let waves = sin(u * 6 + Double(j) * 2) * 0.09 + sin(u * 14 + Double(j)) * 0.045
                        ridge.addLine(to: .init(x: w * u, y: base + h * waves))
                    }
                    ridge.addLine(to: .init(x: w, y: h)); ridge.closeSubpath()
                    ctx.fill(ridge, with: .color(Color(rgb: 0x112f38).opacity(0.26 + Double(j) * 0.16)))
                }
                if focus == nil || focus == .desktop {
                    WeatherDrawing.draw(in: ctx, size: size, weather: scene.desktop, time: t, preview: true)
                }
                if focus == nil || focus == .menu {
                    var strip = ctx
                    strip.fill(Path(CGRect(x: 0, y: 0, width: w, height: 10)), with: .color(.black.opacity(0.22)))
                    strip.translateBy(x: 0, y: 10)
                    LightDrawing.draw(in: strip, size: size, lights: scene.menu, time: t)
                }
                if focus == nil || focus == .dock {
                    let dockWidth = min(w * 0.66, 300), x = (w - dockWidth) / 2, y = h - 35
                    let dock = CGRect(x: x, y: y, width: dockWidth, height: 28)
                    ctx.fill(Path(roundedRect: dock, cornerRadius: 8), with: .color(.white.opacity(0.23)))
                    for i in 0..<7 {
                        let dx = x + (Double(i) + 0.5) * dockWidth / 7
                        let tint = [0x7fbaca, 0xffd0ac, 0xa0c4aa, 0xcab9cf][i % 4]
                        ctx.fill(Path(roundedRect: .init(x: dx - 7,y: y + 7,width: 14,height: 14), cornerRadius: 4),
                                 with: .color(Color(rgb: tint)))
                    }
                    var string = ctx
                    string.translateBy(x: x, y: y)
                    LightDrawing.draw(in: string, size: .init(width: dockWidth, height: 28), lights: scene.dock, time: t)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Preview of the current \(focus?.rawValue ?? "seasonal scene") settings")
    }
}
