import SwiftUI

// Reconstruct recent landings on a small height field. Each display has its own
// snowfall clock. The fixed melt window keeps memory and depth bounded.
private struct SnowBank {
    let depths: [Double]
    let maximum: Double

    init(size: CGSize, count: Int, weather: Weather, time: Double, preview: Bool) {
        let w = Double(size.width), h = Double(size.height)
        let bins = max(8, min(96, Int(w / (preview ? 12 : 26))))
        var deposits = Array(repeating: 0.0, count: bins + 1)
        let meltTime = 75.0
        for i in 0..<count {
            let fall = 28 * (0.45 + 0.78 * variation(i, 5))
            let first = (h + 10 - variation(i, 8) * h) / fall
            let period = (h + 20) / fall
            guard time >= first else { continue }
            var landing = first + floor((time - first) / period) * period
            while landing >= first - 0.00001 && time - landing < meltTime {
                let x = WeatherDrawing.fallingX(index: i, time: landing, width: w, wind: weather.wind, sway: 6)
                let position = min(Double(bins), max(0, x / w * Double(bins)))
                let center = Int(position)
                let age = max(0, time - landing)
                let weight = min(1, age * 2) * (1 - age / meltTime) * (preview ? 0.9 : 1.7) * sqrt(weather.size)
                for bin in max(0, center - 2)...min(bins, center + 3) {
                    let distance = abs(Double(bin) - position)
                    deposits[bin] += weight * max(0, 1 - distance / 2.6)
                }
                landing -= period
            }
        }
        let limit = min(h * 0.12, 64)
        maximum = limit
        depths = deposits.map { limit * (1 - exp(-$0 / limit)) }
    }

    func draw(in ctx: GraphicsContext, size: CGSize, tint: Color, opacity: Double) {
        guard depths.contains(where: { $0 > 0.02 }) else { return }
        let h = size.height, step = size.width / Double(depths.count - 1)
        var crest = Path()
        var previous = CGPoint(x: 0, y: h - depths[0])
        crest.move(to: previous)
        for i in 1..<depths.count {
            let next = CGPoint(x: Double(i) * step, y: h - depths[i])
            crest.addQuadCurve(to: CGPoint(x: (previous.x + next.x) / 2, y: (previous.y + next.y) / 2), control: previous)
            previous = next
        }
        crest.addLine(to: previous)
        var bank = crest
        bank.addLine(to: CGPoint(x: size.width, y: h))
        bank.addLine(to: CGPoint(x: 0, y: h))
        bank.closeSubpath()
        var snow = ctx
        snow.opacity = opacity
        snow.fill(bank, with: .linearGradient(Gradient(colors: [.white, tint, tint.opacity(0.78)]),
                                              startPoint: .init(x: 0, y: h - maximum), endPoint: .init(x: 0, y: h)))
        snow.clip(to: bank)
        snow.stroke(crest, with: .color(.white.opacity(0.82)), lineWidth: 2)
    }
}

enum WeatherDrawing {
    fileprivate static func fallingX(index: Int, time: Double, width: Double, wind: Double, sway: Double) -> Double {
        let seed = variation(index, 4), depth = 0.45 + 0.78 * variation(index, 5)
        let x = seed * width + wind * time * 47 * depth + sin(time * 0.8 + seed * 100) * sway
        return x - floor(x / (width + 20)) * (width + 20) - 10
    }

    static func draw(in ctx: GraphicsContext, size: CGSize, weather: Weather, time: Double,
                     pointer: CGPoint? = nil, preview: Bool = false, effectAge: Double? = nil) {
        guard weather.hasVisibleEffect, size.width > 0, size.height > 0 else { return }
        let w = Double(size.width), h = Double(size.height)
        let colors = weather.colors.isEmpty ? [0xffffff] : weather.colors
        let count = max(1, Int(min(700, w * h / (preview ? 800 : 4700) * weather.density)))
        let t = ([Effect.snow, .leaves].contains(weather.effect) ? max(0, effectAge ?? time) : time) * weather.speed
        if weather.effect == .aurora {
            aurora(in: ctx, size: size, weather: weather, time: t, colors: colors)
            return
        }
        if weather.effect == .meteors {
            meteorShower(in: ctx, size: size, weather: weather, time: t, colors: colors)
            return
        }
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
        if weather.effect == .ballDrop {
            drawBallDrop(in: ctx, size: size, weather: weather, time: t, colors: colors)
            return
        }
        let flying = [.bats, .ghosts, .tide, .pond, .lanterns, .bubbles].contains(weather.effect)
        let number = flying ? max(1, count / 5) : count
        for i in 0..<number {
            let seed = variation(i, 4)
            let depth = 0.45 + 0.78 * variation(i, 5)
            let speed = weather.effect == .rain ? 145.0 : weather.effect == .fireflies ? 7 : 28
            let sway = weather.effect == .leaves || weather.effect == .petals ? 17.0 : 6
            func wrap(_ value: Double, _ period: Double) -> Double { value - floor(value / period) * period }
            var x = fallingX(index: i, time: t, width: w, wind: weather.wind, sway: sway)
            var y = wrap(variation(i, 8) * h + t * speed * depth, h + 20) - 10
            if weather.effect == .bats {
                let direction = i.isMultiple(of: 2) ? 1.0 : -1.0
                x = wrap(seed * w + t * (direction * 52 * depth + weather.wind * 30), w + 48) - 24
                y = variation(i, 8) * h + sin(t * 1.5 + seed * 18) * 10 * depth + sin(t * 0.37 + seed * 51) * 17
            } else if weather.effect == .pond {
                let heading = i.isMultiple(of: 2) ? 1.0 : -1.0
                x = wrap(seed * w + t * depth * (heading * 22 + weather.wind * 9), w + 64) - 32
                y = (0.12 + 0.76 * variation(i, 8)) * h + sin(t * 0.42 + seed * 15) * min(34, h * 0.10)
            } else if [.ghosts, .tide, .lanterns, .bubbles].contains(weather.effect) {
                y = wrap(variation(i, 8) * h - t * 19 * depth, h + 40) - 20
                x = wrap(seed * w + weather.wind * t * 20 + sin(t * 0.74 + seed * 30) * 16, w + 32) - 16
            }
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
                // Recent impacts spread into short, fading ripples at the desktop edge.
                let sinceImpact = wrap(variation(i, 8) * h + t * speed * depth - h - 10, h + 20) / (speed * depth)
                if sinceImpact < 0.45 {
                    let phase = sinceImpact / 0.45
                    let hit = fallingX(index: i, time: t - sinceImpact, width: w, wind: weather.wind, sway: sway)
                    let reach = max(2, radius * 2.3) * (0.2 + phase)
                    let ring = CGRect(x: hit - reach, y: h - 2 - reach * 0.15, width: reach * 2, height: reach * 0.3)
                    ctx.stroke(Path(ellipseIn: ring), with: .color(color.opacity((1 - phase) * weather.opacity)), lineWidth: 0.9)
                }
                var drop = Path()
                drop.move(to: .zero); drop.addLine(to: .init(x: -weather.wind * radius, y: -radius * 2.8))
                particle.stroke(drop, with: .color(color), style: .init(lineWidth: max(0.7, radius * 0.25), lineCap: .round))
            case .confetti:
                particle.rotate(by: .radians(t * (1.2 + seed) + seed * 14))
                let width = radius * (0.2 + 0.8 * abs(cos(t * 2 + seed * 11)))
                particle.fill(Path(roundedRect: CGRect(x: -width / 2, y: -radius, width: width, height: radius * 2),
                                   cornerRadius: radius * 0.15), with: .color(color))
            case .bats:
                let flap = 0.48 + 0.52 * abs(sin(t * 5.4 + seed * 34))
                particle.rotate(by: .degrees(sin(t * 1.5 + seed * 18) * 12))
                particle.scaleBy(x: radius * 3, y: radius * 2.8 * flap)
                let bat = LightDrawing.silhouette(.bat)
                particle.fill(bat, with: .color(color))
                particle.stroke(bat, with: .color(.white.opacity(0.4)), lineWidth: 0.045)
            case .ghosts:
                particle.rotate(by: .degrees(sin(t + seed * 15) * 10))
                particle.scaleBy(x: radius * 2.6, y: radius * 2.8)
                particle.fill(LightDrawing.silhouette(.ghost), with: .color(color))
                for eye in [-0.17, 0.08] {
                    particle.fill(Path(ellipseIn: CGRect(x: eye, y: -0.14, width: 0.095, height: 0.16)),
                                  with: .color(Color(rgb: 0x302842)))
                }
            case .pond:
                let direction = i.isMultiple(of: 2) ? 1.0 : -1.0
                particle.scaleBy(x: direction, y: 1)
                particle.rotate(by: .degrees(16 * cos(t * 0.42 + seed * 15) + 4 * sin(t * 2 + seed)))
                particle.scaleBy(x: radius * 4.4, y: radius * 3.7)
                particle.fill(LightDrawing.silhouette(.koi), with: .color(color))
                LightDrawing.paintDetails(in: particle, design: .koi)
                let wake = (t * 0.5 + seed).truncatingRemainder(dividingBy: 1)
                let ripple = CGRect(x: -0.50 - wake * 0.65, y: -0.06 - 0.18 * wake,
                                    width: 0.16 + wake * 0.5, height: 0.12 + wake * 0.36)
                particle.stroke(Path(ellipseIn: ripple), with: .color(color.opacity(0.46 * (1 - wake))), lineWidth: 0.023)
            case .bubbles:
                let r = radius * (1.4 + seed)
                particle.scaleBy(x: r, y: r)
                let bubble = Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2))
                particle.fill(bubble, with: .radialGradient(Gradient(colors: [.clear, color.opacity(0.09), color.opacity(0.52)]),
                                                            center: .init(x: -0.13, y: -0.14), startRadius: 0.2, endRadius: 1.2))
                particle.stroke(bubble, with: .color(color.opacity(0.75)), lineWidth: 0.065)
                var glint = Path()
                glint.addArc(center: .zero, radius: 0.77, startAngle: .degrees(215), endAngle: .degrees(263), clockwise: false)
                particle.stroke(glint, with: .color(.white.opacity(0.9)), style: .init(lineWidth: 0.09, lineCap: .round))
            case .lanterns:
                particle.rotate(by: .degrees(8 * sin(t * 0.7 + seed * 9)))
                particle.scaleBy(x: radius * 3.7, y: radius * 3.7)
                particle.fill(Path(ellipseIn: .init(x: -0.8, y: -0.7, width: 1.6, height: 1.65)),
                              with: .radialGradient(Gradient(colors: [color.opacity(0.4), .clear]),
                                                    center: .init(x: 0, y: 0.11), startRadius: 0, endRadius: 0.83))
                particle.fill(LightDrawing.silhouette(.skyLantern), with: .color(color))
                LightDrawing.paintDetails(in: particle, design: .skyLantern)
            case .tide:
                let pulse = sin(t * 1.8 + seed * 22)
                let length = radius * 3.5
                particle.rotate(by: .degrees(sin(t * 0.5 + seed * 18) * 14))
                particle.scaleBy(x: length * (1 - 0.10 * pulse), y: length * (1 + 0.13 * pulse))
                let jelly = LightDrawing.silhouette(.jelly)
                particle.fill(jelly, with: .linearGradient(Gradient(colors: [color.opacity(0.35), color, color.opacity(0.55)]),
                                                           startPoint: .init(x: 0, y: -0.5), endPoint: .init(x: 0, y: 0.5)))
                particle.stroke(jelly, with: .color(color.opacity(0.72)), lineWidth: 0.027)
            case .fireworks, .ballDrop, .aurora, .meteors: break
            }
        }
        if weather.effect == .leaves && weather.leafPilesEnabled {
            drawSettledLeaves(in: ctx, size: size, weather: weather, time: t, count: count, colors: colors, preview: preview)
        }
        if weather.pumpkinsEnabled {
            drawPumpkins(in: ctx, size: size, weather: weather, time: t, preview: preview)
        }
        if weather.accumulatesSnow {
            SnowBank(size: size, count: count, weather: weather, time: t, preview: preview)
                .draw(in: ctx, size: size, tint: Color(rgb: colors.last!), opacity: weather.opacity)
        }
    }

    private static func drawSettledLeaves(in ctx: GraphicsContext, size: CGSize, weather: Weather,
                                          time: Double, count: Int, colors: [Int], preview: Bool) {
        let w = Double(size.width), h = Double(size.height)
        let bins = max(6, min(100, Int(w / (preview ? 14 : 28))))
        var heights = Array(repeating: 0.0, count: bins)
        let cap = min(h * 0.07, 36)
        let leaf = LightDrawing.silhouette(.leaf)
        // Track the most recent landing from each sampled trajectory. The work
        // per frame stays bounded even after the app has run for days.
        let stride = max(1, (count + 179) / 180)
        for i in Swift.stride(from: 0, to: count, by: stride) {
            let depth = 0.45 + 0.78 * variation(i, 5)
            let fall = 28 * depth
            let first = (h + 10 - variation(i, 8) * h) / fall
            guard time >= first else { continue }
            let period = (h + 20) / fall
            let age = (time - first).truncatingRemainder(dividingBy: period)
            let lifetime = min(period, 48)
            guard age < lifetime else { continue }
            let hit = fallingX(index: i, time: time - age, width: w, wind: weather.wind, sway: 17)
            let x = hit + weather.wind * min(age, 4) * 2
            let bin = max(0, min(bins - 1, Int(x / w * Double(bins))))
            let r = min(cap, max(2, weather.size * depth * (preview ? 0.8 : 1)))
            let fade = min(1, age * 3, (lifetime - age) * 0.7)
            let y = h - r * 0.42 - min(cap, heights[bin])
            var paint = ctx
            paint.opacity = weather.opacity * fade
            paint.translateBy(x: x, y: y)
            paint.rotate(by: .degrees(-24 + variation(i, 25) * 48))
            paint.scaleBy(x: r * 2.4, y: r * 1.25)
            paint.fill(leaf, with: .color(Color(rgb: colors[i % colors.count])))
            paint.stroke(leaf, with: .color(.black.opacity(0.28)), lineWidth: 0.055)
            heights[bin] += r * 0.45 * fade
        }
    }

    private static func drawPumpkins(in ctx: GraphicsContext, size: CGSize, weather: Weather,
                                     time: Double, preview: Bool) {
        let w = Double(size.width), h = Double(size.height)
        let unit = min(w * 0.105, h * 0.15, (17 + weather.size * 2.8) * (preview ? 0.64 : 1))
        let count = weather.density < 0.25 ? 1 : weather.density < 0.75 ? 2 : 3
        for i in 0..<count {
            let scale = unit * [1.0, 0.82, 0.64][i]
            var p = ctx
            p.opacity = weather.opacity
            let x = [0.09, 0.89, 0.155][i] * w
            p.translateBy(x: x, y: h - scale * 0.42 - 1)
            p.scaleBy(x: scale, y: scale)
            let glow = 0.81 + 0.10 * sin(time * 2.1 + Double(i)) + 0.05 * sin(time * 3.6 + Double(i * 3))
            p.fill(Path(ellipseIn: .init(x: -0.87, y: -0.86, width: 1.74, height: 1.74)),
                   with: .radialGradient(Gradient(colors: [Color.orange.opacity(0.30 * glow), .clear]),
                                         center: .zero, startRadius: 0.18, endRadius: 0.87))
            var stem = Path()
            stem.move(to: .init(x: 0, y: -0.32))
            stem.addQuadCurve(to: .init(x: 0.10, y: -0.54), control: .init(x: -0.02, y: -0.47))
            p.stroke(stem, with: .color(Color(rgb: 0x716144)), style: .init(lineWidth: 0.085, lineCap: .round))
            for lobe in [-2, 2, -1, 1, 0] {
                let offset = abs(Double(lobe))
                let rect = CGRect(x: Double(lobe) * 0.145 - 0.23, y: -0.39 + 0.026 * offset,
                                  width: 0.46, height: 0.80 - 0.054 * offset)
                p.fill(Path(ellipseIn: rect), with: .linearGradient(Gradient(colors: [
                    Color(rgb: 0xf8ab4c), Color(rgb: 0xc86028), Color(rgb: 0x853b25)
                ]), startPoint: .init(x: 0, y: -0.4), endPoint: .init(x: 0.15, y: 0.42)))
                p.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.13)), lineWidth: 0.018)
            }
            var face = Path()
            for eye in [-0.18, 0.18] {
                face.move(to: .init(x: eye, y: -0.17))
                face.addLine(to: .init(x: eye + 0.085, y: -0.02))
                face.addLine(to: .init(x: eye - 0.085, y: -0.02))
                face.closeSubpath()
            }
            face.move(to: .init(x: -0.27, y: 0.07))
            face.addQuadCurve(to: .init(x: 0.27, y: 0.07), control: .init(x: 0, y: 0.38))
            face.addLine(to: .init(x: 0.09, y: 0.13))
            face.addLine(to: .init(x: 0.08, y: 0.19))
            face.addLine(to: .init(x: 0.00, y: 0.19))
            face.addLine(to: .init(x: -0.01, y: 0.13))
            face.closeSubpath()
            p.fill(face, with: .color(Color(rgb: 0xffdd81).opacity(glow)))
            p.stroke(face, with: .color(Color(rgb: 0x854024)), lineWidth: 0.025)
        }
    }

    private static func aurora(in ctx: GraphicsContext, size: CGSize, weather: Weather, time: Double, colors: [Int]) {
        let layers = 1 + Int(weather.density * 4)
        let height = size.height
        let drift = time * (0.08 + weather.wind * 0.12)
        for band in 0..<layers {
            let offset = Double(band) * 1.38
            let tint = Color(rgb: colors[band % colors.count])
            let baseline = height * (0.28 + Double(band) * 0.045)
            let reach = height * (0.09 + weather.size * 0.009)
            var ribbon = Path()
            var top = [CGPoint]()
            for step in 0...64 {
                let u = Double(step) / 64
                let fold = sin(u * 7.8 + drift + offset) + 0.38 * sin(u * 13 - time * 0.12 + offset)
                let lower = CGPoint(x: u * size.width, y: baseline + fold * height * 0.064)
                if step == 0 { ribbon.move(to: lower) } else { ribbon.addLine(to: lower) }
                top.append(CGPoint(x: lower.x, y: lower.y - reach * (0.75 + 0.25 * sin(u * 18 + offset + drift))))
            }
            for point in top.reversed() { ribbon.addLine(to: point) }
            ribbon.closeSubpath()
            // Each vertical column fades up from its own fold in the curtain.
            var clipped = ctx
            clipped.clip(to: ribbon)
            let stripe = size.width / 64
            for step in 0..<64 {
                let upper = top[step]
                let u = Double(step) / 64
                let depth = reach * (0.75 + 0.25 * sin(u * 18 + offset + drift))
                let lowerY = upper.y + depth
                let glow = weather.opacity * (0.23 + 0.10 * cos(u * 35 + offset))
                let gradient = Gradient(stops: [.init(color: .clear, location: 0),
                    .init(color: tint.opacity(glow * 0.6), location: 0.58),
                    .init(color: tint.opacity(glow), location: 0.88), .init(color: .clear, location: 1)])
                clipped.fill(Path(CGRect(x: upper.x, y: 0, width: stripe + 0.25, height: height)),
                             with: .linearGradient(gradient, startPoint: upper, endPoint: CGPoint(x: upper.x, y: lowerY)))
            }
        }
    }

    private static func meteorShower(in ctx: GraphicsContext, size: CGSize, weather: Weather, time: Double, colors: [Int]) {
        let width = size.width, height = size.height
        let sky = min(width, height)
        // The faint star field stays visible between shooting stars and under Reduce Motion.
        for i in 0..<Int(6 + 48 * weather.density) {
            let r = (0.5 + variation(i, 3)) * (0.7 + weather.size * 0.09)
            let star = CGRect(x: variation(i, 18) * width, y: variation(i, 13) * height, width: 2*r, height: 2*r)
            ctx.fill(Path(ellipseIn: star), with: .color(Color(rgb: colors[i % colors.count]).opacity(weather.opacity * 0.46)))
        }
        for i in 0..<(1 + Int(weather.density * 5)) {
            let cycle = time * 0.25 + Double(i) * 0.37 + 0.17
            let phase = cycle - floor(cycle)
            guard phase < 0.48 else { continue }
            let u = phase / 0.48
            let seed = Int(floor(cycle)) * 7 + i
            let run = sky * (0.22 + weather.wind * 0.23)
            let fall = sky * 0.23
            let end = CGPoint(x: width * (0.12 + 0.62 * variation(seed, 9)) + run * u,
                              y: height * (0.08 + 0.54 * variation(seed, 16)) + fall * u)
            let tail = CGPoint(x: end.x - run * 0.32, y: end.y - fall * 0.32)
            let color = Color(rgb: colors[i % colors.count])
            var stream = Path()
            stream.move(to: tail)
            stream.addLine(to: end)
            var ray = ctx
            ray.opacity = weather.opacity * sin(.pi * u)
            ray.stroke(stream, with: .linearGradient(Gradient(colors: [.clear, color]), startPoint: tail, endPoint: end),
                       style: .init(lineWidth: max(0.8, weather.size * 0.42), lineCap: .round))
            let dot = weather.size * 0.62
            ray.fill(Path(ellipseIn: .init(x: end.x-dot/2, y: end.y-dot/2, width: dot, height: dot)), with: .color(.white))
        }
    }

    // A twelve-second celebration: the faceted ball descends, lands, then scatters sparks.
    private static func drawBallDrop(in context: GraphicsContext, size: CGSize, weather: Weather,
                                     time: Double, colors: [Int]) {
        let phase = time.truncatingRemainder(dividingBy: 12) / 12
        let descent = min(1, phase / 0.72)
        let eased = descent * descent * (3 - 2 * descent)
        let r = min(size.height * 0.12, 7 + weather.size * 2.3)
        let top = max(r + 3, size.height * 0.12), bottom = size.height * 0.72
        let x = size.width * 0.5, y = top + eased * (bottom - top)
        var ctx = context
        ctx.opacity = weather.opacity * min(1, (1 - phase) / 0.08)
        var pole = Path()
        pole.move(to: CGPoint(x: x, y: top)); pole.addLine(to: CGPoint(x: x, y: bottom + r))
        ctx.stroke(pole, with: .color(.white.opacity(0.35)), lineWidth: max(1, r * 0.09))
        let orb = Path(ellipseIn: CGRect(x: x-r, y: y-r, width: 2*r, height: 2*r))
        let halo = Path(ellipseIn: CGRect(x: x-2*r, y: y-2*r, width: 4*r, height: 4*r))
        ctx.fill(halo, with: .radialGradient(Gradient(colors: [Color(rgb: colors[0]).opacity(0.65), .clear]),
                                             center: CGPoint(x: x, y: y), startRadius: 0, endRadius: 2*r))
        var facets = ctx
        facets.clip(to: orb)
        facets.fill(orb, with: .color(Color(rgb: 0x484451)))
        let tile = r * 0.36
        for row in -3...3 {
            for col in -4...4 {
                let index = (row + 3) * 9 + col + 4
                let gleam = 0.58 + 0.42 * sin(time * 2 + Double(index) * 2.4)
                let origin = x + (Double(col) + sin(time + Double(row) * 0.24) * 0.45) * tile
                let facet = CGRect(x: origin, y: y + Double(row) * tile, width: tile * 0.91, height: tile * 0.9)
                facets.fill(Path(facet), with: .color(Color(rgb: colors[index % colors.count]).opacity(gleam)))
            }
        }
        ctx.stroke(orb, with: .color(.white.opacity(0.75)), lineWidth: max(0.7, r * 0.06))
        if phase >= 0.72 {
            let age = (phase - 0.72) / 0.28
            let reach = min(size.width * 0.36, size.height * 0.31)
            for i in 0..<Int(10 + weather.density * 70) {
                let angle = variation(i, 11) * .pi * 2
                let distance = (0.4 + variation(i, 9)) * reach * age
                let dx = cos(angle) * distance + weather.wind * age * reach * 0.32
                let dy = sin(angle) * distance + age * age * reach * 0.5
                let dot = max(1, r * 0.17)
                ctx.fill(Path(ellipseIn: CGRect(x: x + dx, y: bottom + dy, width: dot, height: dot)),
                         with: .color(Color(rgb: colors[i % colors.count]).opacity(1 - age)))
            }
        }
    }
}

struct ScenePreview: View {
    var scene: Scene
    var focus: Layer? = nil
    @AppStorage("useWallpaperPreview") private var useWallpaper = false
    @State private var wallpaper: NSImage?
    @State private var effectStarted = ProcessInfo.processInfo.systemUptime
    init(scene: Scene, focus: Layer? = nil) {
        self.scene = scene
        self.focus = focus
    }
    private func loadWallpaper() {
        guard useWallpaper, let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let original = NSImage(contentsOf: url), original.size.width > 0, original.size.height > 0 else {
            wallpaper = nil; return
        }
        let scale = min(1, 900 / max(original.size.width, original.size.height))
        let size = CGSize(width: original.size.width * scale, height: original.size.height * scale)
        let thumb = NSImage(size: size)
        thumb.lockFocus()
        original.draw(in: CGRect(origin: .zero, size: size))
        thumb.unlockFocus()
        wallpaper = thumb
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { tick in
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let t = reduceMotion ? 0 : ProcessInfo.processInfo.systemUptime
                let area = CGRect(origin: .zero, size: size)
                let sky: [Color] = {
                    switch scene.desktop.effect {
                    case .lanterns: return [Color(rgb: 0x29253d), Color(rgb: 0x945b50)]
                    case .bubbles: return [Color(rgb: 0x174050), Color(rgb: 0x559388)]
                    case .pond: return [Color(rgb: 0x173e3c), Color(rgb: 0x517c71)]
                    case .aurora, .meteors: return [Color(rgb: 0x10182e), Color(rgb: 0x354961)]
                    case .tide: return [Color(rgb: 0x123d50), Color(rgb: 0x142634)]
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
                if useWallpaper, let wallpaper {
                    let scale = max(w / wallpaper.size.width, h / wallpaper.size.height)
                    let dw = wallpaper.size.width * scale, dh = wallpaper.size.height * scale
                    ctx.draw(Image(nsImage: wallpaper), in: CGRect(x: (w - dw)/2, y: (h - dh)/2, width: dw, height: dh))
                }
                if focus == nil || focus == .desktop {
                    let effectAge = reduceMotion ? 40 : 8 + ProcessInfo.processInfo.systemUptime - effectStarted
                    WeatherDrawing.draw(in: ctx, size: size, weather: scene.desktop, time: t, preview: true, effectAge: effectAge)
                }
                if focus == nil || focus == .menu {
                    var strip = ctx
                    strip.fill(Path(CGRect(x: 0, y: 0, width: w, height: 10)), with: .color(.black.opacity(0.22)))
                    strip.translateBy(x: 0, y: 10)
                    LightDrawing.draw(in: strip, size: size, lights: scene.menu, time: t)
                }
                if focus == nil || focus == .dock {
                    let dockHeight = focus == .dock ? min(h - 16, max(32, scene.dock.depth)) : 32
                    let dockWidth = min(w * 0.76, 410), x = (w - dockWidth) / 2, y = h - dockHeight - 5
                    let dock = CGRect(x: x, y: y, width: dockWidth, height: dockHeight)
                    ctx.fill(Path(roundedRect: dock, cornerRadius: 8), with: .color(.white.opacity(0.23)))
                    for i in 0..<7 {
                        let dx = x + (Double(i) + 0.5) * dockWidth / 7
                        let tint = [0x7fbaca, 0xffd0ac, 0xa0c4aa, 0xcab9cf][i % 4]
                        ctx.fill(Path(roundedRect: .init(x: dx - 7,y: y + dockHeight / 2 - 7,width: 14,height: 14), cornerRadius: 4),
                                 with: .color(Color(rgb: tint)))
                    }
                    var string = ctx
                    string.translateBy(x: x, y: y)
                    LightDrawing.draw(in: string, size: .init(width: dockWidth, height: dockHeight), lights: scene.dock.fittingDock(depth: dockHeight), time: t)
                }
            }
        }
        .onAppear { loadWallpaper() }
        .onChange(of: scene.desktop.effect) { _, _ in effectStarted = ProcessInfo.processInfo.systemUptime }
        .onChange(of: useWallpaper) { _, _ in loadWallpaper() }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Preview of the current \(focus?.rawValue ?? "seasonal scene") settings")
    }
}
