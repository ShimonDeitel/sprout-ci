import SwiftUI

/// Calm full-screen loader shown while a story is being written. The child's name gently breathes
/// to make the wait feel intentional and cozy.
struct GeneratingView: View {
    let name: String

    @State private var pulse = false
    @State private var twinkle = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.sproutAccent.opacity(0.12))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulse ? 1.12 : 0.92)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Color.sproutAccent)
                    .opacity(twinkle ? 1 : 0.6)
            }
            Text("Writing \(name)'s story…")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .scaleEffect(pulse ? 1.03 : 0.97)
            Text("Sprinkling in a little stardust.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                twinkle = true
            }
        }
    }
}
