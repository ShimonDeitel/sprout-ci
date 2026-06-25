import SwiftUI
import SwiftData

/// Home screen: a big "Make tonight's story" card, a horizontal shelf of past stories, and a
/// child-name chip to switch between kids. First launch routes to creating the first child.
struct TonightView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @Query(sort: \Child.createdAt, order: .forward) private var children: [Child]
    @Query(sort: \Story.createdAt, order: .reverse) private var allStories: [Story]

    @State private var selectedChildID: UUID?
    @State private var showSetup = false
    @State private var showPaywall = false
    @State private var showChildEditor = false
    @State private var editingChild: Child?
    @State private var presentedStory: Story?

    private var selectedChild: Child? {
        if let id = selectedChildID, let c = children.first(where: { $0.id == id }) { return c }
        return children.first
    }

    private var shelfStories: [Story] {
        guard let child = selectedChild else { return [] }
        return allStories.filter { $0.child?.id == child.id }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SproutBackground()
                if children.isEmpty {
                    firstRun
                } else {
                    content
                }
            }
            .navigationTitle("Tonight")
            .toolbar {
                if !children.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ForEach(children) { child in
                                Button {
                                    selectedChildID = child.id
                                    Haptics.tap()
                                } label: {
                                    Label(child.displayName,
                                          systemImage: child.id == selectedChild?.id ? "checkmark" : "person")
                                }
                            }
                            Divider()
                            Button {
                                if appModel.canAddChild { editingChild = nil; showChildEditor = true }
                                else { showPaywall = true }
                            } label: {
                                Label("Add a child", systemImage: "plus")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle")
                                Text(selectedChild?.displayName ?? "Child")
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .sheet(isPresented: $showSetup) {
                if let child = selectedChild {
                    SetupView(child: child) { story in
                        presentedStory = story
                    }
                }
            }
            .sheet(isPresented: $showChildEditor) {
                ChildEditorView(child: editingChild)
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .fullScreenCover(item: $presentedStory) { story in
                ReaderView(story: story)
            }
        }
    }

    // MARK: First run

    private var firstRun: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Color.sproutAccent)
            Text("Welcome to Sprout")
                .font(.title.weight(.bold))
            Text("Add your child and we'll write a brand-new bedtime story starring them — every night.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button("Add your child") { editingChild = nil; showChildEditor = true }
                .prominentButton()
            Spacer()
        }
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                makeCard
                if !store.isPro {
                    freeMeter
                }
                shelfSection
            }
            .padding(20)
        }
    }

    private var makeCard: some View {
        Button {
            if appModel.canCreateStory { showSetup = true }
            else { showPaywall = true }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Make tonight's story")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("A new story starring \(selectedChild?.displayName ?? "your child").")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(Color.sproutAccent, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var freeMeter: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(Color.sproutAccent)
            Text("\(appModel.monthlyStoriesRemaining) of \(AppModel.freeStoriesPerMonth) free stories left this month")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Go Pro") { showPaywall = true }
                .font(.footnote.weight(.semibold))
                .tint(.sproutAccent)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.sproutCard, in: Capsule())
    }

    private var shelfSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SproutSectionHeader(title: "Story shelf", symbol: "books.vertical")
            if shelfStories.isEmpty {
                EmptyStateView(symbol: "book.closed",
                               title: "No stories yet",
                               message: "Tap “Make tonight's story” to create the first one.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(shelfStories) { story in
                            Button { presentedStory = story } label: {
                                ShelfCard(story: story)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - Shelf card

struct ShelfCard: View {
    let story: Story
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SceneCover(imageData: story.sceneImageData,
                       seed: story.id.uuidString,
                       symbol: story.lessonTheme.symbol)
                .frame(width: 150, height: 110)
            Text(story.displayTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)
            Text(TimeFmt.relative(story.createdAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 150, alignment: .leading)
    }
}
