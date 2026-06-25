import Foundation
import SwiftData

// MARK: - Lesson themes

/// The gentle lesson a story teaches. Used as selectable chips on the Setup screen.
enum LessonTheme: String, CaseIterable, Identifiable, Codable {
    case bravery, sharing, bedtime, kindness, patience, honesty

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bravery: return "Bravery"
        case .sharing: return "Sharing"
        case .bedtime: return "Bedtime"
        case .kindness: return "Kindness"
        case .patience: return "Patience"
        case .honesty: return "Honesty"
        }
    }

    var symbol: String {
        switch self {
        case .bravery: return "shield"
        case .sharing: return "hands.sparkles"
        case .bedtime: return "moon.stars"
        case .kindness: return "heart"
        case .patience: return "hourglass"
        case .honesty: return "checkmark.seal"
        }
    }
}

/// A few friendly suggestion chips for "what did they do today".
enum TodayChip: String, CaseIterable, Identifiable {
    case park, doctor, newSibling, firstDay, playdate, beach

    var id: String { rawValue }

    var label: String {
        switch self {
        case .park: return "Went to the park"
        case .doctor: return "Visited the doctor"
        case .newSibling: return "A new sibling"
        case .firstDay: return "First day of school"
        case .playdate: return "Had a playdate"
        case .beach: return "Day at the beach"
        }
    }

    var symbol: String {
        switch self {
        case .park: return "tree"
        case .doctor: return "cross.case"
        case .newSibling: return "figure.2.and.child.holdinghands"
        case .firstDay: return "backpack"
        case .playdate: return "figure.play"
        case .beach: return "beach.umbrella"
        }
    }
}

/// Pronoun choice for the child hero.
enum Pronouns: String, CaseIterable, Identifiable, Codable {
    case she, he, they

    var id: String { rawValue }

    var label: String {
        switch self {
        case .she: return "She / Her"
        case .he: return "He / Him"
        case .they: return "They / Them"
        }
    }

    /// What we send to the model.
    var prompt: String {
        switch self {
        case .she: return "she/her"
        case .he: return "he/him"
        case .they: return "they/them"
        }
    }
}

/// Narration voice style (Pro can switch calm/cheerful + pick speed).
enum VoiceStyle: String, CaseIterable, Identifiable, Codable {
    case calm, cheerful

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// Slightly different pitch/rate so the two styles sound distinct on AVSpeechSynthesizer.
    var rateMultiplier: Float { self == .cheerful ? 1.06 : 0.94 }
    var pitch: Float { self == .cheerful ? 1.12 : 0.98 }
}

// MARK: - SwiftData models
// Every stored property has a default value and there are NO unique constraints, so the schema
// stays simple and local-only safe.

/// A child profile. The hero of every story. Free tier = 1 child; Pro = many.
@Model
final class Child {
    var id: UUID = UUID()
    var name: String = ""
    var age: Int = 4
    var pronounsRaw: String = Pronouns.they.rawValue
    var favoriteThing: String? = nil
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Story.child)
    var stories: [Story]? = []

    init(id: UUID = UUID(),
         name: String = "",
         age: Int = 4,
         pronouns: Pronouns = .they,
         favoriteThing: String? = nil,
         createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.age = age
        self.pronounsRaw = pronouns.rawValue
        self.favoriteThing = favoriteThing
        self.createdAt = createdAt
    }

    var pronouns: Pronouns {
        get { Pronouns(rawValue: pronounsRaw) ?? .they }
        set { pronounsRaw = newValue.rawValue }
    }

    var displayName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Your child" : name
    }

    /// Stories newest-first.
    var orderedStories: [Story] {
        (stories ?? []).sorted { $0.createdAt > $1.createdAt }
    }
}

/// A finished bedtime story: text, optional illustration, and metadata. Cached fully so it replays
/// offline (narration is on-device AVSpeechSynthesizer, no audio file required).
@Model
final class Story {
    var id: UUID = UUID()
    var title: String = ""
    var bodyText: String = ""
    var lessonThemeRaw: String = LessonTheme.kindness.rawValue
    var todaySummary: String = ""
    var sceneDescription: String = ""
    /// Optional AI-generated illustration bytes (kept local; nil falls back to a drawn cover).
    var sceneImageData: Data? = nil
    var durationSeconds: Double = 0
    var isFavorite: Bool = false
    var createdAt: Date = Date.now

    var child: Child? = nil

    init(id: UUID = UUID(),
         title: String = "",
         bodyText: String = "",
         lessonTheme: LessonTheme = .kindness,
         todaySummary: String = "",
         sceneDescription: String = "",
         sceneImageData: Data? = nil,
         durationSeconds: Double = 0,
         isFavorite: Bool = false,
         createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.bodyText = bodyText
        self.lessonThemeRaw = lessonTheme.rawValue
        self.todaySummary = todaySummary
        self.sceneDescription = sceneDescription
        self.sceneImageData = sceneImageData
        self.durationSeconds = durationSeconds
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }

    var lessonTheme: LessonTheme {
        get { LessonTheme(rawValue: lessonThemeRaw) ?? .kindness }
        set { lessonThemeRaw = newValue.rawValue }
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? "A Bedtime Story" : title
    }

    /// Story split into sentences for the current-sentence highlight during narration.
    var sentences: [String] {
        TextSplit.sentences(bodyText)
    }
}

// MARK: - Sentence splitting (for narration highlight)

enum TextSplit {
    /// Split body text into display sentences, preserving terminal punctuation.
    static func sentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if ch == "." || ch == "!" || ch == "?" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { result.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        return result.isEmpty ? [text] : result
    }
}

// MARK: - Time formatting helpers

enum TimeFmt {
    /// "m:ss" for a duration in seconds.
    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let m = total / 60, s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: .now)
    }
}
