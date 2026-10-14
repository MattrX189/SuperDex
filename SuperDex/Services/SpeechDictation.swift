//
//  SpeechDictation.swift
//  SuperDex
//
//  Live on-device dictation for interactions: streams the mic into
//  SFSpeechRecognizer and publishes the running transcript + input level.
//

import AVFoundation
import Foundation
import Speech
import UIKit

@Observable
final class SpeechDictation {
    enum Status: Equatable {
        case idle, requesting, listening, denied, unavailable
    }

    private(set) var status: Status = .idle
    /// Transcript of the current listening session only.
    private(set) var transcript = ""
    /// Smoothed mic level, 0...1, for the waveform/pulse.
    private(set) var level: Float = 0

    var isListening: Bool { status == .listening }

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: .current)
        ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func toggle() async {
        if isListening { stop() } else { await start() }
    }

    func start() async {
        guard status != .listening, status != .requesting else { return }
        status = .requesting
        transcript = ""

        guard await Self.requestSpeechAuthorization(),
              await AVAudioApplication.requestRecordPermission() else {
            status = .denied
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            status = .unavailable
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            self.request = request

            Self.installTap(on: engine.inputNode, request: request) { [weak self] level in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.level = self.level * 0.6 + level * 0.4
                }
            }
            engine.prepare()
            try engine.start()
            status = .listening
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            task = Self.startRecognition(recognizer: recognizer, request: request) { [weak self] text, isDone in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let text { self.transcript = text }
                    if isDone { self.stop() }
                }
            }
        } catch {
            print("Dictation failed to start: \(error.localizedDescription)")
            stop()
            status = .unavailable
        }
    }

    func stop() {
        let wasListening = status == .listening
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        // End audio but let the task deliver its final, punctuated result.
        request?.endAudio()
        request = nil
        task = nil
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if status == .listening || status == .requesting { status = .idle }
        if wasListening { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    // MARK: - Off-main helpers (audio + recognition callbacks run on background threads)

    nonisolated private static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    nonisolated private static func installTap(
        on input: AVAudioInputNode,
        request: SFSpeechAudioBufferRecognitionRequest,
        onLevel: @escaping @Sendable (Float) -> Void
    ) {
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            onLevel(normalizedLevel(of: buffer))
        }
    }

    nonisolated private static func startRecognition(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onUpdate: @escaping @Sendable (String?, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            onUpdate(result?.bestTranscription.formattedString, (result?.isFinal ?? false) || error != nil)
        }
    }

    nonisolated private static func normalizedLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<count { sum += samples[i] * samples[i] }
        let rms = (sum / Float(count)).squareRoot()
        // Map roughly -50dB...0dB onto 0...1.
        let db = 20 * log10(max(rms, 0.000_01))
        return min(max((db + 50) / 50, 0), 1)
    }
}
