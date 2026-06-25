import Foundation

// MARK: - Configuration

/// DIRECT mode: the app talks to OpenRouter's chat-completions API itself. The key is embedded in
/// the app (owner-approved, free key). Only text prompts (child name / today note / lesson / a soft
/// scene description) are ever sent — never personal media. The model is instructed to return ONLY a
/// JSON object matching the decoder's shape, with a strict child-safety guard on inputs and outputs.
enum AIConfig {
    /// OpenRouter chat-completions endpoint.
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    /// Embedded OpenRouter key (owner-approved, free key).
    static let apiKey = "__OPENROUTER_KEY__"

    /// Text model used for the bedtime story.
    static let model = "openai/gpt-4o-mini"

    static let storyMaxTokens = 1400
    static let temperature = 0.8

    /// Network timeout so a stalled call can never hang the generating UI forever.
    static let timeout: TimeInterval = 45

    /// Per-user, app-side daily cap on AI calls. Successful calls count against it.
    static let dailyCallLimit = 25
}

// MARK: - Wire types (what the model returns inside choices[0].message.content)

/// A generated bedtime story. The model returns EXACTLY this shape.
struct StoryResult: Codable {
    var title: String
    var story: String
    var sceneDescription: String

    enum CodingKeys: String, CodingKey {
        case title, story, sceneDescription
        // Tolerate alternate field names the model might emit.
        case body, text, scene, illustration
    }

    init(title: String, story: String, sceneDescription: String) {
        self.title = title
        self.story = story
        self.sceneDescription = sceneDescription
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        story = (try? c.decode(String.self, forKey: .story))
            ?? (try? c.decode(String.self, forKey: .body))
            ?? (try? c.decode(String.self, forKey: .text)) ?? ""
        sceneDescription = (try? c.decode(String.self, forKey: .sceneDescription))
            ?? (try? c.decode(String.self, forKey: .scene))
            ?? (try? c.decode(String.self, forKey: .illustration)) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(story, forKey: .story)
        try c.encode(sceneDescription, forKey: .sceneDescription)
    }

    /// The story must have a non-trivial body to be usable.
    var isUsable: Bool {
        story.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: { $0 == " " }).count >= 40
    }
}

// MARK: - Story request

/// Everything the text prompt needs about tonight's story.
struct StoryRequest {
    var childName: String
    var age: Int
    var pronouns: String          // e.g. "she/her", "he/him", "they/them"
    var favoriteThing: String?    // optional flavor
    var todaySummary: String      // "what did they do today"
    var lessonTheme: String       // e.g. "bravery", "sharing"
    var longerChapter: Bool       // Pro: longer chapter story
}

// MARK: - Errors

enum AIError: Error, LocalizedError {
    case badResponse
    case http(Int)
    case decoding
    case unusable
    case rateLimited
    case unsafeInput

    var errorDescription: String? {
        switch self {
        case .badResponse: return "No response from the story service."
        case .http(let code): return "Story service returned \(code)."
        case .decoding: return "Couldn't read the generated story."
        case .unusable: return "The story came back too short — please try again."
        case .rateLimited: return "Daily story limit reached — resets tomorrow."
        case .unsafeInput: return "That note can't be turned into a children's story. Try gentler details."
        }
    }
}

// MARK: - Daily rate limit (per-user, app-side)

/// Simple UserDefaults daily cap on AI calls, keyed by yyyy-MM-dd. Successful calls increment it.
enum AIRateLimiter {
    private static let countKey = "sprout.ai.daily.count"
    private static let dayKey = "sprout.ai.daily.day"

    private static var today: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func rollIfNeeded(_ d: UserDefaults) {
        if d.string(forKey: dayKey) != today {
            d.set(today, forKey: dayKey)
            d.set(0, forKey: countKey)
        }
    }

    static func usedToday(_ d: UserDefaults = .standard) -> Int {
        rollIfNeeded(d)
        return d.integer(forKey: countKey)
    }

    static func canCall(_ d: UserDefaults = .standard) -> Bool {
        usedToday(d) < AIConfig.dailyCallLimit
    }

    static func recordCall(_ d: UserDefaults = .standard) {
        rollIfNeeded(d)
        d.set(d.integer(forKey: countKey) + 1, forKey: countKey)
    }
}

// MARK: - Child-safety input guard (app-side, before any network call)

/// A light, local pre-filter that blocks obviously unsafe inputs from ever reaching the model.
/// The system prompt also enforces safety on the model side; this is defence in depth.
enum ChildSafety {
    private static let banned: [String] = [
        "kill", "blood", "gun", "weapon", "drug", "sex", "nude", "suicide",
        "die ", "dead", "knife", "porn", "abuse", "hate"
    ]

    static func isInputSafe(_ text: String) -> Bool {
        let lower = text.lowercased()
        return !banned.contains { lower.contains($0) }
    }
}

// MARK: - OpenRouter wire envelope

private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatRequest: Encodable {
    struct ResponseFormat: Encodable { let type: String }
    let model: String
    let messages: [ChatMessage]
    let response_format: ResponseFormat
    let max_tokens: Int
    let temperature: Double
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message?
    }
    let choices: [Choice]
}

// MARK: - Client

/// Calls OpenRouter directly with the embedded key, builds the prompt IN THE APP, and decodes the
/// model's strict JSON into `StoryResult`. Only text is ever sent. Robust: every failure path throws
/// a typed error so callers can fall back gracefully (a gentle built-in story + drawn scene cover).
final class AIClient {
    static let shared = AIClient()

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = AIConfig.timeout
            cfg.timeoutIntervalForResource = AIConfig.timeout
            self.session = URLSession(configuration: cfg)
        }
    }

    /// Story pass. Builds a strong child-safety system prompt + a user message describing tonight's
    /// child and lesson, calls OpenRouter, decodes the JSON into a validated `StoryResult`.
    func generateStory(_ request: StoryRequest) async throws -> StoryResult {
        // App-side safety pre-filter on the free-text the parent typed.
        guard ChildSafety.isInputSafe(request.todaySummary),
              ChildSafety.isInputSafe(request.lessonTheme),
              ChildSafety.isInputSafe(request.favoriteThing ?? "") else {
            throw AIError.unsafeInput
        }
        guard AIRateLimiter.canCall() else { throw AIError.rateLimited }

        let system = Self.storySystemPrompt(longer: request.longerChapter)
        let user = Self.storyUserMessage(request)

        let content = try await chat(system: system, user: user, maxTokens: AIConfig.storyMaxTokens)
        let result: StoryResult = try decodeContent(content)
        guard result.isUsable else { throw AIError.unusable }
        AIRateLimiter.recordCall()
        return result
    }

    // MARK: Prompts (built in the app)

    private static func storySystemPrompt(longer: Bool) -> String {
        let length = longer
            ? "Write a slightly longer chapter-style story of about 500-700 words, in 2-3 short gentle scenes."
            : "Write a short bedtime story of about 250-400 words."
        return """
        You are a warm, gentle children's bedtime-story writer. You write soothing, age-appropriate
        stories that always star the named child as the kind, capable hero. \(length)

        STRICT CHILD-SAFETY RULES — these override everything else:
        - Absolutely nothing scary, violent, sad in a distressing way, or unsafe.
        - No death, injury, weapons, monsters that frighten, peril, romance, or anything mature.
        - Keep a calm, cozy, reassuring tone suitable for falling asleep. End on a peaceful, loving note.
        - Use simple words a young child understands. Short sentences. Soft imagery (stars, gardens, animals).
        - If the parent's "today" note or lesson is unsuitable for a small child, gently reinterpret it
          into something wholesome rather than refusing.

        Return ONLY a single JSON object — no markdown, no prose, no code fences — with EXACTLY this shape:
        {
          "title": string,              // a short, sweet title (max ~6 words)
          "story": string,              // the full bedtime story, plain text with normal sentences
          "sceneDescription": string    // ONE soft storybook illustration prompt: a single gentle scene,
                                         // pastel, cozy, no text, no scary elements
        }

        The story must weave in the child's name as the hero and the chosen lesson naturally.
        Output valid JSON only.
        """
    }

    private static func storyUserMessage(_ r: StoryRequest) -> String {
        var lines: [String] = []
        lines.append("CHILD NAME: \(r.childName)")
        lines.append("AGE: \(r.age)")
        lines.append("PRONOUNS: \(r.pronouns)")
        if let fav = r.favoriteThing, !fav.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("LOVES: \(fav)")
        }
        let today = r.todaySummary.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append("WHAT THEY DID TODAY: \(today.isEmpty ? "had an ordinary, happy day" : today)")
        lines.append("LESSON TO GENTLY TEACH: \(r.lessonTheme)")
        return lines.joined(separator: "\n")
    }

    // MARK: Transport

    /// One chat-completions round-trip. Returns the model's `content` string (expected to be JSON).
    private func chat(system: String, user: String, maxTokens: Int) async throws -> String {
        var req = URLRequest(url: AIConfig.endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(AIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("https://github.com/shimondeitel/sprout", forHTTPHeaderField: "HTTP-Referer")
        req.setValue("Sprout", forHTTPHeaderField: "X-Title")

        let body = ChatRequest(
            model: AIConfig.model,
            messages: [ChatMessage(role: "system", content: system),
                       ChatMessage(role: "user", content: user)],
            response_format: .init(type: "json_object"),
            max_tokens: maxTokens,
            temperature: AIConfig.temperature)
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw AIError.badResponse
        }
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse }
        guard (200..<300).contains(http.statusCode) else { throw AIError.http(http.statusCode) }

        let envelope: ChatResponse
        do {
            envelope = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw AIError.decoding
        }
        guard let content = envelope.choices.first?.message?.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.badResponse
        }
        return content
    }

    /// Tolerant decode of the model's JSON content into a target type. Strips an accidental code
    /// fence and falls back to the first {...} object if the model wrapped the JSON in prose.
    private func decodeContent<R: Decodable>(_ content: String) throws -> R {
        let candidates = Self.jsonCandidates(from: content)
        for candidate in candidates {
            if let data = candidate.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(R.self, from: data) {
                return decoded
            }
        }
        throw AIError.decoding
    }

    private static func jsonCandidates(from content: String) -> [String] {
        var out: [String] = []
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        out.append(trimmed)

        if trimmed.hasPrefix("```") {
            var s = trimmed
            if let firstNewline = s.firstIndex(of: "\n") { s = String(s[s.index(after: firstNewline)...]) }
            if let fence = s.range(of: "```", options: .backwards) { s = String(s[..<fence.lowerBound]) }
            out.append(s.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if let open = trimmed.firstIndex(of: "{"), let close = trimmed.lastIndex(of: "}"), open < close {
            out.append(String(trimmed[open...close]))
        }
        return out
    }
}
