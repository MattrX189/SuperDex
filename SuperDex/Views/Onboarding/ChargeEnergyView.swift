//
//  ChargeEnergyView.swift
//  SuperDex
//
//  The energy effect for onboarding's card slingshot
//  (OnboardingCardReadyView). While the card is pulled back, energy
//  gathers into it; on release, it all lets go at once.
//
//  • ChargeEnergyBackground — behind the card: aura, rings contracting
//    into the card, curved energy streaks, shards and embers sucked in.
//  • ChargeEdgeLightning — in front: lightning crawling along the card's
//    edges and arcing off it.
//  • EnergyReleaseBurst — on release: flash, shockwaves, rays, bolts.
//
//  Everything is drawn in Canvas. Motion is integrated per frame
//  (EnergyField), never derived from absolute time × speed, so changing
//  the pull never makes things jump.
//

import SwiftUI

// MARK: - Behind the card

struct ChargeEnergyBackground: View {
    /// The card's current on-screen frame (moves and shrinks as it's pulled).
    let card: CGRect
    /// 0…1 how far it's drawn back.
    let progress: CGFloat
    let armed: Bool
    let color: Color
    let field: EnergyField
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(paused: !isActive)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                guard isActive, progress > 0, card != .zero else { return }
                field.step(now: now, card: card, canvasSize: size, progress: progress)
                context.blendMode = .plusLighter

                drawAura(in: &context, size: size, now: now)
                drawRings(in: &context)
                drawStreaks(in: &context)
                drawShardsAndEmbers(in: &context)
                drawRim(in: &context, now: now)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawAura(in context: inout GraphicsContext, size: CGSize, now: TimeInterval) {
        let pulse = armed ? 0.85 + 0.15 * sin(now * 14) : 1
        let reach = max(card.width, card.height) * (0.6 + 0.6 * progress)
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    color.opacity(Double(0.75 * progress) * pulse),
                    color.opacity(Double(0.25 * progress) * pulse),
                    .clear
                ]),
                center: CGPoint(x: card.midX, y: card.minY + card.height * 0.2),
                startRadius: card.width * 0.25,
                endRadius: reach
            )
        )
    }

    /// Ripples contracting into the top of the card.
    private func drawRings(in context: inout GraphicsContext) {
        let center = CGPoint(x: card.midX, y: card.minY + card.height * 0.08)
        let maxRadius = card.width * (0.9 + 0.5 * progress)
        let count = 6
        for index in 0..<count {
            let phase = (field.ringPhase + Double(index) / Double(count)).truncatingRemainder(dividingBy: 1)
            let radius = maxRadius * CGFloat(1 - phase) + card.width * 0.32
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius * 0.62,
                width: radius * 2,
                height: radius * 1.24
            )
            // Brightest mid-way in, fading at both ends.
            let alpha = sin(phase * .pi) * Double(progress) * (armed ? 0.6 : 0.4)
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(color.opacity(alpha)),
                lineWidth: 1.2 + 2.2 * progress
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(alpha * 0.5)),
                lineWidth: 0.8
            )
        }
    }

    /// Curved energy streaks: each streak's recent path, tapering toward its tail.
    private func drawStreaks(in context: inout GraphicsContext) {
        let core = armed ? Color.white : Color.white.opacity(0.85)
        for particle in field.active where particle.kind == .streak {
            let trail = particle.trail
            guard trail.count >= 2 else { continue }
            let fadeIn = min(particle.age / 0.12, 1)
            let speed = hypot(particle.velocity.dx, particle.velocity.dy)
            let energy = fadeIn * min(0.4 + speed / 900, 1)

            for segment in 1..<trail.count {
                let t = Double(segment) / Double(trail.count - 1) // 0 tail → 1 head
                var path = Path()
                path.move(to: trail[segment - 1])
                path.addLine(to: trail[segment])
                let width = (0.4 + 2.4 * t) * Double(0.7 + 0.5 * progress)
                // Colored glow under a thin bright core.
                context.stroke(
                    path,
                    with: .color(color.opacity(energy * t * 0.55)),
                    style: StrokeStyle(lineWidth: width * 2.6, lineCap: .round)
                )
                context.stroke(
                    path,
                    with: .color(core.opacity(energy * t)),
                    style: StrokeStyle(lineWidth: width, lineCap: .round)
                )
            }
        }
    }

    private func drawShardsAndEmbers(in context: inout GraphicsContext) {
        for particle in field.active where particle.kind != .streak {
            let fadeIn = min(particle.age / 0.2, 1)
            switch particle.kind {
            case .shard:
                // Dark crystal fragment with a lit edge.
                let size = particle.size
                var shard = Path()
                shard.move(to: CGPoint(x: 0, y: -size))
                shard.addLine(to: CGPoint(x: size * 0.6, y: -size * 0.1))
                shard.addLine(to: CGPoint(x: size * 0.15, y: size))
                shard.addLine(to: CGPoint(x: -size * 0.55, y: size * 0.2))
                shard.closeSubpath()
                let transform = CGAffineTransform(translationX: particle.position.x, y: particle.position.y)
                    .rotated(by: particle.rotation)
                let placed = shard.applying(transform)
                var dark = context
                dark.blendMode = .normal
                dark.fill(placed, with: .color(Color(red: 0.05, green: 0.05, blue: 0.12).opacity(0.9 * fadeIn)))
                context.stroke(placed, with: .color(color.opacity(0.8 * fadeIn)), lineWidth: 1)
            case .ember:
                let radius = particle.size * 0.35
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: particle.position.x - radius,
                        y: particle.position.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color(Color(red: 1, green: 0.62, blue: 0.3).opacity(0.9 * fadeIn))
                )
            case .streak:
                break
            }
        }
    }

    /// Glowing outline hugging the card's edges (behind it, so it reads as
    /// light spilling from the rim).
    private func drawRim(in context: inout GraphicsContext, now: TimeInterval) {
        let flicker = armed ? 0.8 + 0.2 * sin(now * 31) : 1
        let shape = RoundedRectangle(cornerRadius: 32 * (card.width / 300), style: .continuous)
        for (inset, width, alpha) in [(-2.0, 18.0, 0.12), (-1.0, 9.0, 0.25), (0.0, 3.5, 0.55)] {
            let path = shape.path(in: card.insetBy(dx: inset, dy: inset))
            context.stroke(
                path,
                with: .color((width < 4 ? Color.white : color).opacity(alpha * Double(progress) * flicker)),
                lineWidth: width
            )
        }
    }
}

// MARK: - In front of the card

/// Lightning crawling along the card's top and sides and arcing off it.
/// Bolts are regenerated every few frames so they flicker like real arcs.
struct ChargeEdgeLightning: View {
    let card: CGRect
    let progress: CGFloat
    let armed: Bool
    let color: Color
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(paused: !isActive)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                guard isActive, progress > 0.12, card != .zero else { return }
                context.blendMode = .plusLighter

                // New shapes ~16 times a second.
                var random = SeededRandom(seed: UInt64(now * 16))
                let visibleBottom = min(card.maxY, size.height) - 10
                let boltCount = Int(1 + 9 * progress) + (armed ? 3 : 0)

                for _ in 0..<boltCount {
                    let startFraction = random.next()
                    let start = edgePoint(startFraction, visibleBottom: visibleBottom)
                    let end: CGPoint
                    if random.next() < 0.3 {
                        // Arc jumping off the edge.
                        let outward = outwardNormal(for: start)
                        let reach = 25 + 70 * Double(progress) * random.next()
                        end = CGPoint(
                            x: start.x + outward.dx * reach + (random.next() - 0.5) * 40,
                            y: start.y + outward.dy * reach + (random.next() - 0.5) * 40
                        )
                    } else {
                        // Crawling a short way along the edge from where it started.
                        let along = (0.04 + 0.08 * random.next()) * (random.next() < 0.5 ? -1 : 1)
                        end = edgePoint(min(max(startFraction + along, 0), 1), visibleBottom: visibleBottom)
                    }
                    // Jitter scales with the bolt's length so short crawls stay tight to the edge.
                    let length = hypot(end.x - start.x, end.y - start.y)
                    let bolt = LightningBolt.path(from: start, to: end, jitter: min(Double(length) * 0.18, 14), random: &random)
                    let intensity = Double(progress) * (0.55 + 0.45 * random.next())
                    context.stroke(bolt, with: .color(color.opacity(intensity * 0.5)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    context.stroke(bolt, with: .color(.white.opacity(intensity)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// A point on the card's left edge → top → right edge, by fraction 0…1.
    private func edgePoint(_ fraction: Double, visibleBottom: CGFloat) -> CGPoint {
        let sideLength = max(Double(visibleBottom - card.minY), 0)
        let topLength = Double(card.width)
        let total = sideLength * 2 + topLength
        var distance = fraction * total
        if distance < sideLength {
            return CGPoint(x: card.minX, y: visibleBottom - CGFloat(distance))
        }
        distance -= sideLength
        if distance < topLength {
            return CGPoint(x: card.minX + CGFloat(distance), y: card.minY)
        }
        distance -= topLength
        return CGPoint(x: card.maxX, y: card.minY + CGFloat(distance))
    }

    private func outwardNormal(for point: CGPoint) -> CGVector {
        if abs(point.x - card.minX) < 1 { return CGVector(dx: -1, dy: 0) }
        if abs(point.x - card.maxX) < 1 { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: 0, dy: -1)
    }
}

// MARK: - Release

/// The stored energy letting go: a flash, two shockwaves, light rays and a
/// few bolts, all from where the card was released. Plays once from `start`.
struct EnergyReleaseBurst: View {
    let center: CGPoint
    let start: Date
    let color: Color

    private let duration: TimeInterval = 0.9

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                guard elapsed >= 0, elapsed < duration else { return }
                let t = elapsed / duration
                context.blendMode = .plusLighter

                // Flash.
                let flash = max(0, 1 - elapsed / 0.22)
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.55 * flash)))

                // Shockwaves.
                for (delay, thickness) in [(0.0, 26.0), (0.08, 12.0)] {
                    let local = max(0, (elapsed - delay) / (duration - delay))
                    guard local > 0 else { continue }
                    let radius = 40 + CGFloat(1 - pow(1 - local, 3)) * size.height * 0.9
                    let alpha = (1 - local) * 0.9
                    let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    context.stroke(ring, with: .color(color.opacity(alpha * 0.6)), lineWidth: thickness * (1 - local) + 2)
                    context.stroke(ring, with: .color(.white.opacity(alpha)), lineWidth: 2)
                }

                // Rays streaming out past the screen edges.
                var random = SeededRandom(seed: 7)
                let exitDistance = Double(hypot(size.width, size.height))
                for index in 0..<28 {
                    let angle = Double(index) / 28 * 2 * .pi + random.next() * 0.2
                    let inner = 30 + t * t * exitDistance
                    let outer = inner + 60 + random.next() * 160
                    var ray = Path()
                    ray.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                    ray.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                    context.stroke(ray, with: .color(.white.opacity((1 - t * t) * 0.8)), style: StrokeStyle(lineWidth: 2.5 * (1 - t) + 0.8, lineCap: .round))
                }

                // Bolts for the first moment.
                if elapsed < 0.3 {
                    var boltRandom = SeededRandom(seed: UInt64(elapsed * 30) + 11)
                    for _ in 0..<7 {
                        let angle = boltRandom.next() * 2 * .pi
                        let length = 120 + boltRandom.next() * 200
                        let end = CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
                        let bolt = LightningBolt.path(from: center, to: end, jitter: 22, random: &boltRandom)
                        context.stroke(bolt, with: .color(color.opacity(0.6)), lineWidth: 5)
                        context.stroke(bolt, with: .color(.white), lineWidth: 1.5)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Particles

/// Energy particles sucked into the card: curved streaks, dark shards and
/// a few embers. Each has a real position and velocity in screen space and
/// is pulled toward its own point on the card's top/left/right edge —
/// harder the further the card is drawn back. Targets move with the card;
/// particles in flight don't, so they curve after it. On arrival a particle
/// slips behind the card and respawns farther out.
final class EnergyField {
    enum Kind { case streak, shard, ember }
    enum Edge { case top, left, right }

    struct Particle {
        var kind: Kind
        var edge: Edge
        /// 0…1 along its target edge.
        var along: CGFloat
        var position: CGPoint
        var velocity: CGVector
        var trail: [CGPoint] = []
        var age: Double = 0
        var size: CGFloat = 6
        var rotation: CGFloat = 0
        var spin: CGFloat = 0
    }

    private(set) var particles: [Particle] = []
    private var activeCount = 0
    private var lastTime: TimeInterval?
    /// Integrated, so ring speed can follow the pull without jumping.
    private(set) var ringPhase: Double = 0

    var active: ArraySlice<Particle> { particles.prefix(activeCount) }

    func step(now: TimeInterval, card: CGRect, canvasSize: CGSize, progress: CGFloat) {
        let dt = min(now - (lastTime ?? now), 1.0 / 30)
        lastTime = now
        ringPhase = (ringPhase + dt * (0.35 + 1.1 * Double(progress))).truncatingRemainder(dividingBy: 1)

        let visibleBottom = min(card.maxY, canvasSize.height) - 24
        let count = Int(12 + 44 * progress)
        while particles.count < count {
            particles.append(spawn(card: card, visibleBottom: visibleBottom, width: canvasSize.width))
        }
        activeCount = count

        let basePull = 900 + 2600 * Double(progress)
        let baseMaxSpeed = 450 + 1350 * Double(progress)
        for index in 0..<activeCount {
            var particle = particles[index]
            let weight = particle.kind == .shard ? 0.55 : 1  // shards are heavier
            let target = targetPoint(particle, card: card, visibleBottom: visibleBottom)
            let dx = Double(target.x - particle.position.x)
            let dy = Double(target.y - particle.position.y)
            let distance = max(hypot(dx, dy), 0.001)

            if distance < 10 || card.insetBy(dx: 4, dy: 4).contains(particle.position) {
                particles[index] = spawn(card: card, visibleBottom: visibleBottom, width: canvasSize.width)
                continue
            }

            let pull = basePull * weight
            var vx = Double(particle.velocity.dx) + dx / distance * pull * dt
            var vy = Double(particle.velocity.dy) + dy / distance * pull * dt
            let drag = pow(0.3, dt)
            vx *= drag
            vy *= drag
            let maxSpeed = baseMaxSpeed * weight
            let speed = hypot(vx, vy)
            if speed > maxSpeed {
                vx *= maxSpeed / speed
                vy *= maxSpeed / speed
            }
            particle.velocity = CGVector(dx: vx, dy: vy)
            particle.position.x += CGFloat(vx * dt)
            particle.position.y += CGFloat(vy * dt)
            particle.rotation += particle.spin * CGFloat(dt)
            particle.age += dt
            if particle.kind == .streak {
                particle.trail.append(particle.position)
                if particle.trail.count > 10 { particle.trail.removeFirst(particle.trail.count - 10) }
            }
            particles[index] = particle
        }
    }

    private func targetPoint(_ particle: Particle, card: CGRect, visibleBottom: CGFloat) -> CGPoint {
        let sideSpan = max(visibleBottom - card.minY, 0)
        switch particle.edge {
        case .top:   return CGPoint(x: card.minX + card.width * particle.along, y: card.minY)
        case .left:  return CGPoint(x: card.minX, y: card.minY + sideSpan * particle.along)
        case .right: return CGPoint(x: card.maxX, y: card.minY + sideSpan * particle.along)
        }
    }

    private func spawn(card: CGRect, visibleBottom: CGFloat, width: CGFloat) -> Particle {
        let kindRoll = Double.random(in: 0..<1)
        let kind: Kind = kindRoll < 0.78 ? .streak : (kindRoll < 0.92 ? .shard : .ember)
        let edgeRoll = CGFloat.random(in: 0..<1)
        let edge: Edge = edgeRoll < 0.24 ? .top : (edgeRoll < 0.62 ? .left : .right)
        var particle = Particle(
            kind: kind,
            edge: edge,
            along: .random(in: 0.05...0.95),
            position: .zero,
            velocity: .zero
        )
        let target = targetPoint(particle, card: card, visibleBottom: visibleBottom)

        let angle: Double
        switch edge {
        case .top:   angle = -Double.pi * Double.random(in: 0.1...0.9)
        case .left:  angle = Double.pi + Double.random(in: -0.6...0.4)
        case .right: angle = Double.random(in: -0.4...0.6)
        }
        let reach = Double(width) * Double.random(in: 0.4...0.85)
        particle.position = CGPoint(
            x: target.x + CGFloat(cos(angle) * reach),
            y: target.y + CGFloat(sin(angle) * reach)
        )
        // Sideways launch so the paths sweep in on curves.
        // Curve upward-inward from the sides (like energy being drawn in),
        // gently enough that streaks arc rather than loop.
        let swirl = Double.random(in: 50...130) * (edge == .right ? -1 : (edge == .left ? 1 : (Bool.random() ? 1 : -1)))
        particle.velocity = CGVector(dx: -sin(angle) * swirl, dy: cos(angle) * swirl)
        particle.trail = [particle.position]
        particle.size = kind == .shard ? .random(in: 4...10) : .random(in: 4...7)
        particle.rotation = .random(in: 0...(2 * .pi))
        particle.spin = .random(in: -6...6)
        return particle
    }
}

// MARK: - Helpers

enum LightningBolt {
    /// A jagged path from `start` to `end` by midpoint displacement.
    static func path(from start: CGPoint, to end: CGPoint, jitter: Double, random: inout SeededRandom) -> Path {
        var points = [start, end]
        var spread = jitter
        for _ in 0..<4 {
            var next: [CGPoint] = [points[0]]
            for index in 1..<points.count {
                let a = points[index - 1], b = points[index]
                let dx = b.x - a.x, dy = b.y - a.y
                let length = max(hypot(dx, dy), 0.001)
                let offset = (random.next() - 0.5) * 2 * spread
                let mid = CGPoint(
                    x: (a.x + b.x) / 2 - dy / length * offset,
                    y: (a.y + b.y) / 2 + dx / length * offset
                )
                next.append(mid)
                next.append(b)
            }
            points = next
            spread *= 0.55
        }
        var path = Path()
        path.addLines(points)
        return path
    }
}

/// Small deterministic RNG, so a bolt shape stays put for its frame bucket.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }

    /// 0…1
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}
