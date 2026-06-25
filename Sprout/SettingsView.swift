import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @AppStorage("sprout.theme") private var themeRaw = AppTheme.system.rawValue
    @AppStorage("sprout.voiceStyle") private var voiceStyleRaw = VoiceStyle.calm.rawValue
    @AppStorage("sprout.narrationSpeed") private var narrationSpeed = 0.5
    @AppStorage("sprout.autoplay") private var autoplayNarration = true

    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var restoreMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                proSection
                narrationSection
                appearanceSection
                privacySection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("Delete all data?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { appModel.deleteAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes every child profile and saved story from this device. This can't be undone.")
            }
        }
    }

    // MARK: Pro

    private var proSection: some View {
        Section {
            if store.isPro {
                Label("Sprout Pro is active", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.sproutAccent)
            } else {
                Button { showPaywall = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sprout Pro").font(.headline)
                            Text("Unlimited stories · more children · voices")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(store.pricePerMonth).font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.sproutAccent)
                    }
                }
                Text("\(appModel.monthlyStoriesRemaining) of \(AppModel.freeStoriesPerMonth) free stories left this month.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Restore Purchases") {
                Task {
                    await store.restore()
                    restoreMessage = store.isPro ? "Pro restored." : "No purchase found to restore."
                }
            }
            if let restoreMessage {
                Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Narration

    private var narrationSection: some View {
        Section {
            Toggle("Autoplay narration", isOn: $autoplayNarration)

            if store.isPro {
                Picker("Voice style", selection: $voiceStyleRaw) {
                    ForEach(VoiceStyle.allCases) { v in Text(v.label).tag(v.rawValue) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reading speed").font(.subheadline)
                    Slider(value: $narrationSpeed, in: 0...1)
                        .tint(.sproutAccent)
                }
            } else {
                Button { showPaywall = true } label: {
                    HStack {
                        Text("Voice style & speed")
                        Spacer()
                        Text("Calm").foregroundStyle(.secondary)
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(Color.sproutAccent)
                    }
                }
                .tint(.primary)
            }
        } header: {
            Text("Narration")
        } footer: {
            Text(store.isPro
                 ? "Narration is read aloud on-device — it works fully offline."
                 : "Free stories narrate in a calm voice. Pro unlocks a cheerful voice and speed control.")
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: Binding(
                get: { themeRaw },
                set: { themeRaw = $0 })) {
                ForEach(AppTheme.allCases) { t in Text(t.label).tag(t.rawValue) }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Privacy

    private var privacySection: some View {
        Section {
            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Label("Delete all data", systemImage: "trash")
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Stories, profiles and narration stay on your device. Only the details you type for a story (your child's first name, today's note and the lesson) are sent to write the story — nothing else.")
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            HStack { Text("Stories"); Spacer(); Text("\(appModel.totalStories)").foregroundStyle(.secondary) }
            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                Label("Terms of Use", systemImage: "doc.text")
            }
            Link(destination: URL(string: "https://shimondeitel.github.io/cool-apps-legal/sprout/privacy.html")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            HStack { Text("Version"); Spacer(); Text("1.0").foregroundStyle(.secondary) }
        }
    }
}

// MARK: - Share sheet (used for keepsake export)

import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
