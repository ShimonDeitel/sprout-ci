import Foundation
import AVFoundation
import SwiftUI

/// On-device, offline narration using AVSpeechSynthesizer. Speaks the story sentence by sentence so
/// the Reader can highlight the current sentence, and supports pause/resume. Zero TTS cost, fully
/// offline once a story is cached.
@MainActor
final class Narrator: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false
    @Published private(set) var isPaused = false
    /// Index of the sentence currently being spoken (-1 when idle).
    @Published private(set) var currentSentence: Int = -1

    private let synth = AVSpeechSynthesizer()
    private var sentences: [String] = []
    private var index = 0
    private var style: VoiceStyle = .calm
    private var speed: Float = 0.5   // 0...1 normalized; mapped to AVSpeechUtterance rate

    override init() {
        super.init()
        synth.delegate = self
    }

    /// Begin narrating a story from the top.
    func start(sentences: [String], style: VoiceStyle, speed: Double) {
        stop()
        guard !sentences.isEmpty else { return }
        self.sentences = sentences
        self.style = style
        self.speed = Float(min(max(speed, 0), 1))
        self.index = 0
        configureSession()
        isSpeaking = true
        isPaused = false
        speakCurrent()
        Haptics.tap()
    }

    /// Toggle play/pause. If nothing is loaded, this is a no-op (caller starts instead).
    func togglePause() {
        guard isSpeaking else { return }
        if isPaused {
            synth.continueSpeaking()
            isPaused = false
        } else {
            synth.pauseSpeaking(at: .word)
            isPaused = true
        }
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        isSpeaking = false
        isPaused = false
        currentSentence = -1
        index = 0
        sentences = []
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
    }

    private func speakCurrent() {
        guard index < sentences.count else { finish(); return }
        currentSentence = index
        let utterance = AVSpeechUtterance(string: sentences[index])
        // Map normalized speed (0...1) into a gentle bedtime range around the default rate.
        let base = AVSpeechUtteranceDefaultSpeechRate
        let low = base * 0.6
        let high = base * 1.0
        utterance.rate = (low + (high - low) * speed) * style.rateMultiplier
        utterance.pitchMultiplier = style.pitch
        utterance.postUtteranceDelay = 0.25
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(utterance)
    }

    private func finish() {
        isSpeaking = false
        isPaused = false
        currentSentence = -1
        index = 0
    }
}

extension Narrator: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.isSpeaking else { return }
            self.index += 1
            if self.index < self.sentences.count {
                self.speakCurrent()
            } else {
                self.finish()
            }
        }
    }
}
