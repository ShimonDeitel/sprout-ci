import SwiftUI
import SwiftData

/// Library: a grid of every story (cover + title), grouped by child via a picker. Tap to replay
/// offline; long-press for favorite/delete.
struct LibraryView: View {
    @EnvironmentObject var appModel: AppModel

    @Query(sort: \Child.createdAt, order: .forward) private var children: [Child]
    @Query(sort: \Story.createdAt, order: .reverse) private var allStories: [Story]

    @State private var filterChildID: UUID?   // nil = all children
    @State private var presentedStory: Story?

    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    private var stories: [Story] {
        guard let id = filterChildID else { return allStories }
        return allStories.filter { $0.child?.id == id }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SproutBackground()
                if allStories.isEmpty {
                    EmptyStateView(symbol: "books.vertical",
                                   title: "Your library is empty",
                                   message: "Stories you create will be saved here to replay any night, even offline.")
                } else {
                    ScrollView {
                        if children.count > 1 { childFilter }
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(stories) { story in
                                Button { presentedStory = story } label: {
                                    LibraryCard(story: story)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        appModel.toggleFavorite(story)
                                    } label: {
                                        Label(story.isFavorite ? "Unfavorite" : "Favorite",
                                              systemImage: story.isFavorite ? "heart.slash" : "heart")
                                    }
                                    Button(role: .destructive) {
                                        appModel.deleteStory(story)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Library")
            .fullScreenCover(item: $presentedStory) { story in
                ReaderView(story: story)
            }
        }
    }

    private var childFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { filterChildID = nil; Haptics.tap() } label: {
                    SproutChip(title: "All", selected: filterChildID == nil)
                }
                .buttonStyle(.plain)
                ForEach(children) { child in
                    Button { filterChildID = child.id; Haptics.tap() } label: {
                        SproutChip(title: child.displayName, symbol: "person",
                                   selected: filterChildID == child.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

// MARK: - Library card

struct LibraryCard: View {
    let story: Story
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                SceneCover(imageData: story.sceneImageData,
                           seed: story.id.uuidString,
                           symbol: story.lessonTheme.symbol)
                    .aspectRatio(1.3, contentMode: .fit)
                if story.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.sproutAccent, in: Circle())
                        .padding(8)
                }
            }
            Text(story.displayTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)
            if let name = story.child?.displayName {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
