//
//  ChargeHaptics.swift
//  SuperDex
//
//  Haptics for onboarding's card slingshot, matching ChargeEnergyView:
//  • a continuous hum that grows stronger and sharper as the card is
//    pulled back (energy accumulating),
//  • crackle — crisp random taps, more frequent as the charge builds,
//    like the edge lightning,
//  • on release, a big thump that rumbles out with the shockwave.
//
//  Core Haptics; does nothing on devices without a Taptic Engine.
//

import CoreHaptics
import QuartzCore

final class ChargeHaptics {
    private var engine: CHHapticEngine?
    private var hum: CHHapticAdvancedPatternPlayer?
    private var nextCrackle: CFTimeInterval = 0

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            try? self?.engine?.start()
            self?.hum = nil
        }
    }

    /// Call on every pull update. Starts the hum on first use.
    func update(progress: CGFloat) {
        guard let engine else { return }
        if hum == nil { startHum(engine) }

        let p = Float(min(max(progress, 0), 1))
        try? hum?.sendParameters([
            CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0.12 + 0.75 * p * p, relativeTime: 0),
            CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: 0.1 + 0.6 * p, relativeTime: 0)
        ], atTime: CHHapticTimeImmediate)

        // Crackle: from an occasional tick to a rapid buzz of taps.
        let now = CACurrentMediaTime()
        guard p > 0.12, now >= nextCrackle else { return }
        let interval = Double(0.32 - 0.26 * p) * Double.random(in: 0.6...1.4)
        nextCrackle = now + interval
        play(transientIntensity: 0.35 + 0.5 * p * Float.random(in: 0.6...1), sharpness: 0.85)
    }

    /// Pull let go without firing.
    func cancel() {
        stopHum()
    }

    /// The shot fires: everything releases in one big thump that rumbles out.
    func release() {
        stopHum()
        guard let engine else { return }
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
            ], relativeTime: 0.02, duration: 0.45)
        ]
        let fade = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 1),
                .init(relativeTime: 0.45, value: 0)
            ],
            relativeTime: 0.02
        )
        if let pattern = try? CHHapticPattern(events: events, parameterCurves: [fade]) {
            try? engine.start()
            try? engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        }
    }

    // MARK: - Private

    private func startHum(_ engine: CHHapticEngine) {
        // A long continuous event; intensity/sharpness are driven live.
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        ], relativeTime: 0, duration: 60)
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []) else { return }
        try? engine.start()
        hum = try? engine.makeAdvancedPlayer(with: pattern)
        try? hum?.start(atTime: CHHapticTimeImmediate)
    }

    private func stopHum() {
        try? hum?.stop(atTime: CHHapticTimeImmediate)
        hum = nil
        nextCrackle = 0
    }

    private func play(transientIntensity: Float, sharpness: Float) {
        guard let engine else { return }
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: transientIntensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: 0)
        if let pattern = try? CHHapticPattern(events: [event], parameters: []) {
            try? engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        }
    }
}
