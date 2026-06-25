import Foundation
import SwiftData
import SwiftUI

/// App state: owns the LOCAL-ONLY SwiftData store, runs the story pipeline (StoryRequest ->
/// AIClient -> Story), manages child profiles, and enforces the free-tier limits
/// (3 stories/month + 1 child) via UserDefaults. Pro is always read from `store` (StoreKit).
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    /// Surface for a soft, non-blocking error after a generation attempt.
    @Published var lastError: String?

    /// Free tier: this many stories per calendar month, and one child profile.
    static let freeStoriesPerMonth = 3
    static let freeChildLimit = 1

    private let kMonthlyCount = "sprout.free.monthlyStoryCount"
    private let kMonthlyKey = "sprout.free.monthKey"

    init(container: ModelContainer) {
        self.container = container
        #if DEBUG
        seedIfRequested()
        #endif
    }

    // MARK: Container (LOCAL-ONLY — no CloudKit, no iCloud entitlement)

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Child.self, Story.self])
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    var context: ModelContext { container.mainContext }

    // MARK: Children

    func allChildren() -> [Child] {
        let d = FetchDescriptor<Child>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        return (try? context.fetch(d)) ?? []
    }

    var childCount: Int {
        (try? context.fetchCount(FetchDescriptor<Child>())) ?? 0
    }

    /// True when the user is allowed to add another child profile.
    var canAddChild: Bool {
        if store?.isPro == true { return true }
        return childCount < Self.freeChildLimit
    }

    @discardableResult
    func createChild(name: String, age: Int, pronouns: Pronouns, favoriteThing: String?) -> Child {
        let child = Child(name: name, age: age, pronouns: pronouns,
                          favoriteThing: favoriteThing?.isEmpty == true ? nil : favoriteThing)
        context.insert(child)
        try? context.save()
        return child
    }

    func updateChild(_ child: Child, name: String, age: Int, pronouns: Pronouns, favoriteThing: String?) {
        child.name = name
        child.age = age
        child.pronouns = pronouns
        child.favoriteThing = favoriteThing?.isEmpty == true ? nil : favoriteThing
        try? context.save()
    }

    func deleteChild(_ child: Child) {
        context.delete(child)
        try? context.save()
    }

    // MARK: Stories

    func allStories() -> [Story] {
        let d = FetchDescriptor<Story>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(d)) ?? []
    }

    func stories(for child: Child) -> [Story] {
        let cid = child.id
        let d = FetchDescriptor<Story>(
            predicate: #Predicate { $0.child?.id == cid },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(d)) ?? []
    }

    func toggleFavorite(_ story: Story) {
        story.isFavorite.toggle()
        try? context.save()
    }

    func deleteStory(_ story: Story) {
        context.delete(story)
        try? context.save()
    }

    // MARK: Free-tier monthly metering

    private var monthKey: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    private func rollMonthIfNeeded() {
        let d = UserDefaults.standard
        if d.string(forKey: kMonthlyKey) != monthKey {
            d.set(monthKey, forKey: kMonthlyKey)
            d.set(0, forKey: kMonthlyCount)
        }
    }

    var monthlyStoryCount: Int {
        rollMonthIfNeeded()
        return UserDefaults.standard.integer(forKey: kMonthlyCount)
    }

    var monthlyStoriesRemaining: Int {
        max(0, Self.freeStoriesPerMonth - monthlyStoryCount)
    }

    /// True when the user may create another story this month (or is Pro).
    var canCreateStory: Bool {
        if store?.isPro == true { return true }
        return monthlyStoryCount < Self.freeStoriesPerMonth
    }

    private func recordStoryCreated() {
        guard store?.isPro != true else { return }
        rollMonthIfNeeded()
        UserDefaults.standard.set(monthlyStoryCount + 1, forKey: kMonthlyCount)
    }

    // MARK: Generation pipeline

    /// Generate tonight's story for a child. On any failure a gentle built-in fallback story is
    /// produced so the app always delivers a finished, narratable story (never bricked).
    func makeStory(for child: Child,
                   today: String,
                   lesson: LessonTheme,
                   longerChapter: Bool) async -> Story {
        lastError = nil

        let request = StoryRequest(
            childName: child.displayName,
            age: child.age,
            pronouns: child.pronouns.prompt,
            favoriteThing: child.favoriteThing,
            todaySummary: today,
            lessonTheme: lesson.label.lowercased(),
            longerChapter: longerChapter && (store?.isPro == true))

        var result: StoryResult
        do {
            result = try await AIClient.shared.generateStory(request)
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription
                ?? "We couldn't reach the story writer, so here's a cozy one we wrote for you."
            result = Self.fallbackStory(name: child.displayName,
                                        pronouns: child.pronouns,
                                        today: today, lesson: lesson)
        }

        let story = Story(
            title: result.title.isEmpty ? "A Story for \(child.displayName)" : result.title,
            bodyText: result.story,
            lessonTheme: lesson,
            todaySummary: today,
            sceneDescription: result.sceneDescription,
            sceneImageData: nil,
            durationSeconds: Self.estimatedDuration(result.story))
        story.child = child
        context.insert(story)
        try? context.save()

        recordStoryCreated()
        return story
    }

    /// ~150 words/minute reading pace estimate for the duration label.
    private static func estimatedDuration(_ text: String) -> Double {
        let words = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        return Double(words) / 150.0 * 60.0
    }

    /// A gentle, fully-formed offline fallback so a story always appears.
    static func fallbackStory(name: String, pronouns: Pronouns,
                              today: String, lesson: LessonTheme) -> StoryResult {
        let they = pronouns == .she ? "she" : (pronouns == .he ? "he" : "they")
        let them = pronouns == .she ? "her" : (pronouns == .he ? "him" : "them")
        let todayLine = today.trimmingCharacters(in: .whitespaces).isEmpty
            ? "After a happy, ordinary day,"
            : "After a day of \(today.lowercased()),"
        let body = """
        \(todayLine) \(name) curled up under a soft, warm blanket as the stars began to twinkle outside the window.

        A little firefly named Glim floated by and whispered, "\(name), would you like to visit the Quiet Meadow?" \(name) nodded, and together they drifted gently over sleepy rooftops and silver streams.

        In the meadow, the flowers were already yawning. A small rabbit had lost its way home, and \(name) felt a warm, kind feeling inside. Calmly and bravely, \(name) helped the rabbit follow the glowing path, showing real \(lesson.label.lowercased()) with every soft step.

        "Thank you," said the rabbit, snuggling safely into its burrow. Glim smiled and led \(name) back home, where the blanket was still warm and waiting.

        \(name) closed \(them) eyes, proud and peaceful, knowing that \(they) had been gentle and good today. The stars watched over \(them), and soon \(name) was fast asleep, dreaming the softest dreams. Goodnight, \(name). Sweet dreams.
        """
        return StoryResult(
            title: "\(name) and the Quiet Meadow",
            story: body,
            sceneDescription: "A soft pastel storybook scene of a child and a glowing firefly drifting over a calm moonlit meadow, cozy and gentle, no text.")
    }

    // MARK: Delete all data

    func deleteAllData() {
        try? context.delete(model: Story.self)
        try? context.delete(model: Child.self)
        try? context.save()
        UserDefaults.standard.removeObject(forKey: kMonthlyCount)
        UserDefaults.standard.removeObject(forKey: kMonthlyKey)
    }

    var totalStories: Int {
        (try? context.fetchCount(FetchDescriptor<Story>())) ?? 0
    }

    // MARK: DEBUG seeding (compiled out of Release)

    #if DEBUG
    private func seedIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard env["SPROUT_SEED"] == "1" else { return }
        if (try? context.fetchCount(FetchDescriptor<Child>())) == 0 {
            let child = Child(name: "Mia", age: 5, pronouns: .she, favoriteThing: "rabbits")
            context.insert(child)
            let r = Self.fallbackStory(name: "Mia", pronouns: .she,
                                       today: "a trip to the park", lesson: .kindness)
            let story = Story(title: r.title, bodyText: r.story, lessonTheme: .kindness,
                              todaySummary: "a trip to the park",
                              sceneDescription: r.sceneDescription,
                              durationSeconds: 120)
            story.child = child
            context.insert(story)
            try? context.save()
        }
    }
    #endif
}
