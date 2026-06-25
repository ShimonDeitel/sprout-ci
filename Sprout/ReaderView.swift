import SwiftUI

/// Reader: the illustrated scene up top, the large story text below with the current narrated
/// sentence highlighted, and a round blue Play button (on-device AVSpeechSynthesizer). Tap to pause.
struct ReaderView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("sprout.voiceStyle") private var voiceStyleRaw = VoiceStyle.calm.rawValue
    @AppStorage("sprout.narrationSpeed") private var narrationSpeed = 0.5
    @AppStorage("sprout.autoplay") private var autoplayNarration = true

    let story: Story

    @StateObject private var narrator = Narrator()
    @State private var showShare = false
    @State private var shareItems: [Any] = []

    private var voiceStyle: VoiceStyle {
        store.isPro ? (VoiceStyle(rawValue: voiceStyleRaw) ?? .calm) : .calm
    }
    private var speed: Double { store.isPro ? narrationSpeed : 0.5 }

    private var sentences: [String] { story.sentences }

    var body: some View {
        ZStack {
            SproutBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SceneCover(imageData: story.sceneImageData,
                               seed: story.id.uuidString,
                               symbol: story.lessonTheme.symbol,
                               cornerRadius: 24)
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)

                    Text(story.displayTitle)
                        .font(.largeTitle.weight(.bold))

                    HStack(spacing: 8) {
                        MetaChip(symbol: story.lessonTheme.symbol, text: story.lessonTheme.label,
                                 tint: .sproutAccent)
                        MetaChip(symbol: "clock", text: TimeFmt.clock(story.durationSeconds))
                    }

                    storyText
                        .padding(.bottom, 120)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.immediately)

            VStack { Spacer(); playBar }
        }
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topLeading) {
            Button { narrator.stop(); dismiss() } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .overlay(alignment: .topTrailing) { topButtons }
        .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
        .onAppear {
            if autoplayNarration {
                narrator.start(sentences: sentences, style: voiceStyle, speed: speed)
            }
        }
        .onDisappear { narrator.stop() }
    }

    private var topButtons: some View {
        HStack(spacing: 14) {
            Button {
                appModel.toggleFavorite(story)
                Haptics.tap()
            } label: {
                Image(systemName: story.isFavorite ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(story.isFavorite ? Color.sproutAccent : .secondary)
            }
            if store.isPro {
                Button { exportKeepsake() } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }

    private var storyText: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(sentences.enumerated()), id: \.offset) { idx, sentence in
                Text(sentence)
                    .font(.system(.title3, design: .serif))
                    .lineSpacing(6)
                    .foregroundStyle(idx == narrator.currentSentence ? Color.sproutAccent : .primary)
                    .animation(.easeInOut(duration: 0.2), value: narrator.currentSentence)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var playBar: some View {
        HStack(spacing: 16) {
            Button {
                if narrator.isSpeaking {
                    narrator.togglePause()
                } else {
                    narrator.start(sentences: sentences, style: voiceStyle, speed: speed)
                }
            } label: {
                Image(systemName: playSymbol)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(Color.sproutAccent, in: Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(narrator.isSpeaking ? (narrator.isPaused ? "Paused" : "Reading aloud") : "Tap to read aloud")
                    .font(.subheadline.weight(.semibold))
                Text(voiceStyle.label + " voice")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if narrator.isSpeaking {
                Button {
                    narrator.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var playSymbol: String {
        if !narrator.isSpeaking { return "play.fill" }
        return narrator.isPaused ? "play.fill" : "pause.fill"
    }

    private func exportKeepsake() {
        let text = "\(story.displayTitle)\n\n\(story.bodyText)\n\n— Created with Sprout"
        shareItems = [text]
        showShare = true
        Haptics.tap()
    }
}
