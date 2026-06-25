import SwiftUI

/// Setup screen: child (prefilled) + "what did they do today?" (free text or chips) + lesson chips
/// + the blue Create button. Shows a full-screen calm loader while generating, then hands the
/// finished story back to the caller (which presents the Reader).
struct SetupView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let child: Child
    /// Called with the finished story so the parent can present the Reader.
    var onCreated: (Story) -> Void

    @State private var today = ""
    @State private var lesson: LessonTheme = .kindness
    @State private var longerChapter = false
    @State private var generating = false

    var body: some View {
        NavigationStack {
            ZStack {
                SproutBackground()
                if generating {
                    GeneratingView(name: child.displayName)
                } else {
                    form
                }
            }
            .navigationTitle("Tonight's story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !generating {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(generating)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroFor
                todaySection
                lessonSection
                if store.isPro { proSection }
                createButton
            }
            .padding(20)
        }
    }

    private var heroFor: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.sproutAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tonight's hero").font(.caption).foregroundStyle(.secondary)
                Text(child.displayName).font(.title3.weight(.semibold))
            }
            Spacer()
        }
        .padding(14)
        .background(Color.sproutCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SproutSectionHeader(title: "What did they do today?", symbol: "sun.max")
            TextField("e.g. went to the park and made a new friend",
                      text: $today, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Color.sproutField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            FlowChips(items: TodayChip.allCases.map { ($0.id, $0.label, $0.symbol) },
                      isSelected: { id in today == TodayChip(rawValue: id)?.label }) { id in
                if let chip = TodayChip(rawValue: id) {
                    today = chip.label
                    Haptics.tap()
                }
            }
        }
    }

    private var lessonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SproutSectionHeader(title: "A gentle lesson", symbol: "heart")
            FlowChips(items: LessonTheme.allCases.map { ($0.rawValue, $0.label, $0.symbol) },
                      isSelected: { id in lesson.rawValue == id }) { id in
                if let l = LessonTheme(rawValue: id) {
                    lesson = l
                    Haptics.tap()
                }
            }
        }
    }

    private var proSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SproutSectionHeader(title: "Pro", symbol: "sparkles")
            Toggle(isOn: $longerChapter) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Longer chapter story").font(.subheadline.weight(.medium))
                    Text("A longer, multi-scene tale.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .tint(.sproutAccent)
            .padding(12)
            .background(Color.sproutCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var createButton: some View {
        Button {
            create()
        } label: {
            Text("Create")
                .frame(maxWidth: .infinity)
        }
        .prominentButton()
        .padding(.top, 4)
    }

    private func create() {
        generating = true
        Haptics.soft()
        Task {
            // A short minimum so the calm loader reads as deliberate, not a flash.
            async let generated = appModel.makeStory(for: child,
                                                      today: today,
                                                      lesson: lesson,
                                                      longerChapter: longerChapter)
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            let story = await generated
            generating = false
            dismiss()
            // Defer presentation slightly so the sheet dismiss animation completes cleanly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onCreated(story)
            }
        }
    }
}

// MARK: - Simple wrapping chip row

/// A lightweight flow layout of selectable chips (no external dependency).
struct FlowChips: View {
    /// (id, label, sfSymbol)
    let items: [(String, String, String)]
    let isSelected: (String) -> Bool
    let onTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.0) { item in
                Button { onTap(item.0) } label: {
                    SproutChip(title: item.1, symbol: item.2, selected: isSelected(item.0))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Minimal flow layout that wraps its children onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var x: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                rows.append([])
                totalHeight += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rows[rows.count - 1].append(size)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
