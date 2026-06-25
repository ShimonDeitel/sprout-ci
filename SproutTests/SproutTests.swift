import XCTest
import SwiftData
@testable import Sprout

final class SproutTests: XCTestCase {

    // MARK: StoryResult JSON parsing (robust to field-name variants)

    func testStoryResultDecodesCanonical() throws {
        let json = """
        {
          "title": "Mia and the Quiet Meadow",
          "story": "Once upon a time, in a cozy little house, there lived a kind child named Mia who loved to help. One evening Mia found a lost rabbit and gently guided it home, showing real kindness with every soft step. The stars smiled down as Mia drifted off to sleep, warm and proud. Goodnight, Mia.",
          "sceneDescription": "A soft pastel meadow under a moonlit sky."
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(StoryResult.self, from: json)
        XCTAssertEqual(r.title, "Mia and the Quiet Meadow")
        XCTAssertFalse(r.story.isEmpty)
        XCTAssertEqual(r.sceneDescription, "A soft pastel meadow under a moonlit sky.")
        XCTAssertTrue(r.isUsable)
    }

    func testStoryResultDecodesAlternateFieldNames() throws {
        let alt = """
        { "title": "Cozy Night", "text": "\(String(repeating: "word ", count: 60))", "illustration": "soft scene" }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(StoryResult.self, from: alt)
        XCTAssertEqual(r.title, "Cozy Night")
        XCTAssertEqual(r.sceneDescription, "soft scene")
        XCTAssertTrue(r.isUsable)
    }

    func testShortStoryIsNotUsable() {
        let r = StoryResult(title: "x", story: "Too short.", sceneDescription: "s")
        XCTAssertFalse(r.isUsable)
    }

    // MARK: Child-safety pre-filter

    func testUnsafeInputBlocked() {
        XCTAssertFalse(ChildSafety.isInputSafe("a story with a gun"))
        XCTAssertTrue(ChildSafety.isInputSafe("went to the park and fed the ducks"))
    }

    // MARK: Sentence splitting

    func testSentenceSplitting() {
        let s = TextSplit.sentences("Hello there. How are you? I am well!")
        XCTAssertEqual(s.count, 3)
        XCTAssertEqual(s.first, "Hello there.")
    }

    // MARK: AppModel free-tier metering

    @MainActor
    func testFreeChildLimitEnforced() throws {
        let schema = Schema([Child.self, Story.self])
        let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: cfg)
        let model = AppModel(container: container)
        // No store assigned => treated as non-Pro.
        XCTAssertTrue(model.canAddChild)
        model.createChild(name: "Mia", age: 5, pronouns: .she, favoriteThing: nil)
        XCTAssertFalse(model.canAddChild) // free = 1 child
    }
}
