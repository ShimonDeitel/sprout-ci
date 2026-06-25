import SwiftUI

// MARK: - Section header

/// A small uppercase section label used inside forms and detail screens.
struct SproutSectionHeader: View {
    let title: String
    var symbol: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.sproutAccent)
            }
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Selectable chip

/// A flat selectable pill used for the "what did they do today" and "lesson" choices.
struct SproutChip: View {
    let title: String
    var symbol: String? = nil
    let selected: Bool
    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol).font(.footnote.weight(.semibold))
            }
            Text(title).font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .foregroundStyle(selected ? Color.white : .primary)
        .background(selected ? Color.sproutAccent : Color.sproutCard, in: Capsule())
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)
            Text(title).font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Meta chip

struct MetaChip: View {
    let symbol: String
    let text: String
    var tint: Color = .secondary
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.caption2.weight(.semibold))
            Text(text).font(.caption.weight(.medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.sproutField, in: Capsule())
    }
}

// MARK: - Pro lock row

struct ProLockRow: View {
    let title: String
    let subtitle: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.headline)
                .foregroundStyle(Color.sproutAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color.sproutCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Soft storybook scene cover
// Deterministic SF-Symbol + soft-gradient cover for a story. Used when there's no AI illustration,
// and as the thumbnail in the shelf / library. Colors derive from the story id so each cover is
// distinct but always gentle.

struct SceneCover: View {
    /// Optional AI-generated image data; when present it's shown instead of the drawn fallback.
    var imageData: Data? = nil
    /// Stable seed (story id string) so the drawn cover is deterministic per story.
    var seed: String = ""
    var symbol: String = "sparkles"
    var cornerRadius: CGFloat = 18

    private var hue: Double {
        let h = abs(seed.hashValue)
        return Double(h % 360) / 360.0
    }

    var body: some View {
        Group {
            if let imageData, let ui = UIImage(data: imageData) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.28, brightness: 0.96),
                            Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1.0),
                                  saturation: 0.34, brightness: 0.88)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: symbol)
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
