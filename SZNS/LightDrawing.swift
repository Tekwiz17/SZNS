import SwiftUI
import AppKit

enum EdgeMount { case top, left, right }

enum LightDrawing {
    private static let calendarYear = String(Calendar.current.component(.year, from: Date()))
    private static let maskCache: NSCache<NSData, NSImage> = {
        let cache = NSCache<NSData, NSImage>()
        cache.countLimit = 32
        return cache
    }()

    // The same path describes both the wire and the sockets, keeping each bulb attached.
    static func draw(in context: GraphicsContext, size: CGSize, lights: Lights, time: Double,
                     edge: EdgeMount = .top, pointer: CGPoint? = nil) {
        var ctx = context
        var mouse = pointer
        var width = size.width
        switch edge {
        case .top: break
        case .left:
            width = size.height
            ctx.translateBy(x: size.width, y: 0)
            ctx.rotate(by: .degrees(90))
            mouse = pointer.map { CGPoint(x: $0.y, y: size.width - $0.x) }
        case .right:
            width = size.height
            ctx.translateBy(x: 0, y: size.height)
            ctx.rotate(by: .degrees(-90))
            mouse = pointer.map { CGPoint(x: size.height - $0.y, y: $0.x) }
        }
        guard width > 2, lights.enabled else { return }
        ctx.opacity = lights.opacity
        let spans = max(1, Int((width / max(10, lights.span)).rounded()))
        let segment = width / Double(spans)
        let top = lights.thickness / 2 + 1
        var cable = Path()
        cable.move(to: CGPoint(x: 0, y: top))
        for i in 0..<spans {
            let end = Double(i + 1) * segment
            cable.addQuadCurve(to: CGPoint(x: end, y: top),
                               control: CGPoint(x: end - segment / 2, y: top + lights.sag * 2))
        }
        ctx.stroke(cable, with: .color(Color(rgb: lights.wire)), lineWidth: lights.thickness)
        let count = max(1, Int(width / max(lights.size + 2, lights.spacing)))
        let available = lights.colors.isEmpty ? [0xffe3ab] : lights.colors
        let kelvin = temperatureColor(lights.temperature)
        for i in 0..<count where variation(i, 6) <= lights.density {
            let x = (Double(i) + 0.5) * width / Double(count)
            let u = (x / segment).truncatingRemainder(dividingBy: 1)
            let y = top + 4 * lights.sag * u * (1 - u)
            let length = lights.size * (1 + lights.variation * (variation(i, 2) - 0.5) * 0.55)
            let level = brightness(lights, index: i, time: time)
            let color = lights.useTemperature ? kelvin : Color(rgb: available[i % available.count])
            var bulb = ctx
            bulb.translateBy(x: x, y: y)
            if let mouse, lights.pointer != .none {
                let distance = hypot(mouse.x - x, mouse.y - y)
                let influence = max(0, 1 - distance / 68)
                if lights.pointer == .fade { bulb.opacity *= 1 - influence * 0.9 }
                else { bulb.rotate(by: .degrees(influence * (mouse.x < x ? -32 : 32))) }
            }
            let neck = max(2, length * 0.28)
            bulb.fill(Path(roundedRect: CGRect(x: -neck / 2, y: 0, width: neck, height: neck * 1.3),
                           cornerRadius: neck / 4), with: .color(Color(rgb: lights.wire)))
            bulb.translateBy(x: 0, y: neck + length * 0.52)
            if level > 0.15 {
                let radius = length * 0.98
                bulb.fill(Path(ellipseIn: CGRect(x: -radius, y: -radius, width: 2 * radius, height: 2 * radius)),
                          with: .radialGradient(Gradient(colors: [color.opacity(0.42 * level), .clear]),
                                                center: .zero, startRadius: 0, endRadius: radius))
            }
            bulb.scaleBy(x: length, y: length)
            if lights.bulb == .custom, let data = lights.customMask {
                let key = data as NSData
                if let art = maskCache.object(forKey: key) ?? NSImage(data: data) {
                    maskCache.setObject(art, forKey: key)
                    var mask = bulb.resolve(Image(nsImage: art).renderingMode(.template))
                    mask.shading = .color(color.opacity(0.22 + 0.78 * level))
                    bulb.draw(mask, in: CGRect(x: -0.5, y: -0.5, width: 1, height: 1))
                }
            } else if lights.bulb == .year || lights.bulb == .digits {
                let str = lights.bulb == .year ? String(calendarYear.prefix(2)) + "\n" + String(calendarYear.suffix(2))
                                               : String(Array(calendarYear)[i % calendarYear.count])
                let label = Text(str).font(.system(size: lights.bulb == .year ? 0.55 : 1, weight: .black))
                    .foregroundColor(color.opacity(0.25 + 0.75 * level))
                bulb.draw(label, at: .zero)
            } else {
                let shape = silhouette(lights.bulb)
                bulb.fill(shape, with: .color(Color(rgb: 0x474342)))
                bulb.opacity *= 0.15 + level * 0.85
                bulb.fill(shape, with: .linearGradient(Gradient(colors: [color, color, color.opacity(0.62)]),
                                                        startPoint: CGPoint(x: -0.35, y: -0.4),
                                                        endPoint: CGPoint(x: 0.4, y: 0.5)))
                if [.oval, .globe, .diode, .egg, .icicle].contains(lights.bulb) {
                    bulb.fill(Path(ellipseIn: CGRect(x: -0.16, y: -0.21, width: 0.09, height: 0.22)),
                              with: .color(.white.opacity(0.68)))
                }
            }
        }
    }

    private static func temperatureColor(_ kelvin: Double) -> Color {
        let t = max(10, min(100, kelvin / 100))
        let r = t <= 66 ? 255 : 329.7 * pow(t - 60, -0.1332)
        let g = t <= 66 ? 99.47 * log(t) - 161.12 : 288.1 * pow(t - 60, -0.0755)
        let b = t >= 66 ? 255 : t <= 19 ? 0 : 138.52 * log(t - 10) - 305.04
        func unit(_ x: Double) -> Double { min(255, max(0, x)) / 255 }
        return Color(red: unit(r), green: unit(g), blue: unit(b))
    }

    private static func polygon(_ points: [(Double, Double)]) -> Path {
        Path { p in
            for (i, pt) in points.enumerated() {
                let point = CGPoint(x: pt.0, y: pt.1)
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            p.closeSubpath()
        }
    }
    private static func radial(_ tips: Int, inset: Double) -> Path {
        polygon((0..<(2 * tips)).map { i in
            let a = Double(i) * .pi / Double(tips) - .pi / 2
            let r = i.isMultiple(of: 2) ? 0.52 : inset
            return (r * cos(a), r * sin(a))
        })
    }
    private static let silhouettes = Dictionary(uniqueKeysWithValues: Bulb.allCases.map { ($0, buildSilhouette($0)) })
    static func silhouette(_ kind: Bulb) -> Path { silhouettes[kind] ?? Path() }

    private static func buildSilhouette(_ kind: Bulb) -> Path {
        func oval(_ w: Double, _ h: Double) -> Path {
            Path(ellipseIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        }
        switch kind {
        case .globe: return oval(0.95, 0.95)
        case .oval, .custom: return oval(0.69, 1)
        case .egg:
            return Path { p in
                p.move(to: .init(x: 0, y: -0.55))
                p.addCurve(to: .init(x: 0, y: 0.5), control1: .init(x: 0.27, y: -0.57), control2: .init(x: 0.75, y: 0.49))
                p.addCurve(to: .init(x: 0, y: -0.55), control1: .init(x: -0.75, y: 0.49), control2: .init(x: -0.27, y: -0.57))
            }
        case .diode: return Path(roundedRect: .init(x: -0.28, y: -0.5, width: 0.56, height: 1), cornerRadius: 0.23)
        case .icicle: return polygon([(-0.24,-0.49),(0.26,-0.44),(0.13,0.12),(0,0.61),(-0.15,0.2)])
        case .star: return radial(5, inset: 0.24)
        case .sun: var p = radial(12, inset: 0.32); p.addEllipse(in: .init(x: -0.32,y: -0.32,width: 0.64,height: 0.64)); return p
        case .snowflake:
            var p = Path()
            for i in 0..<6 {
                var branch = Path()
                branch.move(to: .zero); branch.addLine(to: .init(x: 0, y: -0.52))
                for y in [-0.24, -0.37] {
                    branch.move(to: .init(x: -0.12, y: y - 0.1)); branch.addLine(to: .init(x: 0, y: y))
                    branch.addLine(to: .init(x: 0.12, y: y - 0.1))
                }
                p.addPath(branch.strokedPath(.init(lineWidth: 0.07, lineCap: .round)), transform: .init(rotationAngle: Double(i) * .pi / 3))
            }
            return p
        case .leaf: return polygon([(0,-0.58),(0.12,-0.27),(0.34,-0.38),(0.23,-0.05),(0.48,-0.13),(0.4,0.01),(0.53,0.06),(0.18,0.29),(0.21,0.38),(0.04,0.34),(0.03,0.55),(-0.03,0.55),(-0.05,0.32),(-0.24,0.38),(-0.20,0.27),(-0.5,0.04),(-0.4,0),(-0.46,-0.15),(-0.23,-0.05),(-0.32,-0.38),(-0.12,-0.27)])
        case .heart:
            return Path { p in
                p.move(to: .init(x: 0, y: 0.49))
                p.addCurve(to: .init(x: 0, y: -0.24), control1: .init(x: -0.94, y: -0.21), control2: .init(x: -0.28, y: -0.7))
                p.addCurve(to: .init(x: 0, y: 0.49), control1: .init(x: 0.28, y: -0.7), control2: .init(x: 0.94, y: -0.21))
            }
        case .blossom, .clover, .pumpkin:
            var p = Path()
            let n = kind == .clover ? 4 : 5
            for i in 0..<n {
                let a = Double(i) * 2 * .pi / Double(n)
                let x = kind == .pumpkin ? Double(i - 2) * 0.12 : cos(a) * 0.25
                let y = kind == .pumpkin ? 0 : sin(a) * 0.25
                p.addEllipse(in: .init(x: x - 0.23, y: y - (kind == .pumpkin ? 0.4 : 0.24), width: 0.46, height: kind == .pumpkin ? 0.78 : 0.48))
            }
            if kind == .pumpkin { p.addRect(.init(x: -0.04, y: -0.51, width: 0.1, height: 0.2)) }
            return p
        case .bat: return polygon([(-0.6,-0.33),(-0.24,-0.20),(-0.12,-0.06),(-0.09,-0.28),(0,-0.14),(0.1,-0.28),(0.13,-0.06),(0.25,-0.22),(0.6,-0.33),(0.49,0.15),(0.33,0.07),(0.16,0.18),(0,0.36),(-0.17,0.18),(-0.32,0.07),(-0.49,0.15)])
        case .ghost:
            var p = Path()
            p.move(to: .init(x: -0.4, y: 0.42)); p.addLine(to: .init(x: -0.38, y: -0.08))
            p.addQuadCurve(to: .init(x: 0.38, y: -0.08), control: .init(x: 0, y: -0.88))
            for (x,y) in [(0.4,0.45),(0.21,0.32),(0,0.49),(-0.18,0.32)] { p.addLine(to: .init(x: x,y: y)) }
            p.closeSubpath(); return p
        case .moon:
            return Path { p in
                p.move(to: .init(x: 0.24,y: -0.47))
                p.addCurve(to: .init(x: 0.38,y: 0.36), control1: .init(x: -0.68,y: -0.54), control2: .init(x: -0.58,y: 0.87))
                p.addCurve(to: .init(x: 0.24,y: -0.47), control1: .init(x: -0.1,y: 0.38), control2: .init(x: -0.28,y: -0.19))
            }
        case .lantern: var p = oval(0.9, 0.8); p.addRect(.init(x: -0.25,y: -0.47,width: 0.5,height: 0.12)); p.addRect(.init(x: -0.12,y: 0.31,width: 0.24,height: 0.22)); return p
        case .pine: return polygon([(0,-0.56),(0.3,-0.15),(0.16,-0.15),(0.41,0.16),(0.24,0.16),(0.49,0.39),(0.09,0.39),(0.09,0.53),(-0.09,0.53),(-0.09,0.39),(-0.49,0.39),(-0.24,0.16),(-0.41,0.16),(-0.16,-0.15),(-0.3,-0.15)])
        case .shell: return polygon([(-0.16,0.43),(-0.52,-0.04),(-0.41,-0.30),(-0.2,-0.42),(0,-0.49),(0.2,-0.42),(0.41,-0.3),(0.52,-0.04),(0.16,0.43)])
        case .champagne, .cocktail, .wine:
            let w = kind == .champagne ? 0.18 : kind == .cocktail ? 0.49 : 0.31
            let bowl = kind == .cocktail ? 0.15 : w * 0.96
            return polygon([(-w,-0.49),(w,-0.49),(bowl,-0.14),(0.05,0.09),(0.04,0.36),(0.22,0.46),(-0.22,0.46),(-0.04,0.36),(-0.05,0.09),(-bowl,-0.14)])
        case .year, .digits: return oval(1,1)
        }
    }
}
