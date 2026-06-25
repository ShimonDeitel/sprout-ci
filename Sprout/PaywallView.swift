import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var restoreMessage: String?

    private let benefits: [(String, String, String)] = [
        ("infinity", "Unlimited stories", "Make a fresh personalized bedtime story every night — no monthly limit."),
        ("person.2.fill", "Every child a hero", "Add as many children as you like, each with their own profile and story library."),
        ("waveform", "More voices & styles", "Switch between calm and cheerful narration and choose the reading speed."),
        ("book.closed.fill", "Longer chapter stories", "Unlock longer, multi-scene chapter stories with recurring named characters."),
        ("square.and.arrow.up", "Keepsake export", "Export a story and its scene to save and share as a keepsake.")
    ]

    var body: some View {
        ZStack {
            SproutBackground()
            ScrollView {
                VStack(spacing: 22) {
                    header
                    benefitList
                    purchaseButton
                    disclosure
                    legalLinks
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.sproutAccent)
            Text("Sprout Pro").font(.largeTitle.weight(.heavy))
            Text("A brand-new bedtime story starring your child, every single night.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 28)
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(benefits, id: \.1) { item in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: item.0)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.sproutAccent)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.1).font(.headline)
                        Text(item.2).font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sproutCard()
    }

    private var purchaseButton: some View {
        VStack(spacing: 10) {
            Button(action: buy) {
                if working {
                    ProgressView().tint(.white)
                } else {
                    Text("Subscribe — \(store.pricePerMonth)")
                }
            }
            .prominentButton()
            .disabled(working || store.purchaseInFlight)

            Button("Restore Purchases") {
                Task {
                    await store.restore()
                    restoreMessage = store.isPro ? "Pro restored." : "No purchase found."
                    if store.isPro { dismiss() }
                }
            }
            .font(.footnote)
            .tint(.sproutAccent)

            if let restoreMessage {
                Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Guideline 3.1.2 disclosure

    private var disclosure: some View {
        Text("Sprout Pro is \(store.pricePerMonth), billed monthly. Your subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your App Store account settings.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6)
    }

    private var legalLinks: some View {
        HStack(spacing: 18) {
            Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Text("·").foregroundStyle(.tertiary)
            Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/cool-apps-legal/sprout/privacy.html")!)
        }
        .font(.caption.weight(.medium))
        .tint(.sproutAccent)
    }

    private func buy() {
        working = true
        Task {
            let ok = await store.purchase()
            working = false
            if ok { Haptics.success(); dismiss() }
        }
    }
}
