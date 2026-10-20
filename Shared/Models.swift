import Foundation

/// Data model. JSON keys match the web app so backups move between web, iPhone and Android.
enum UID {
    static func make() -> String {
        let t = String(Int64(Date().timeIntervalSince1970 * 1000), radix: 36)
        let r = String(UInt32.random(in: 0...UInt32.max), radix: 36)
        return t + String(r.prefix(6))
    }
}

func nowMs() -> Double { (Date().timeIntervalSince1970 * 1000).rounded() }

extension KeyedDecodingContainer {
    func val<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
    /// Lenient integer: accepts Int, Double or numeric String (the web app uses parseInt in places).
    func int(_ key: Key, _ fallback: Int) -> Int {
        if let v = (try? decodeIfPresent(Int.self, forKey: key)) ?? nil { return v }
        if let v = (try? decodeIfPresent(Double.self, forKey: key)) ?? nil, v.isFinite { return Int(v) }
        if let v = (try? decodeIfPresent(String.self, forKey: key)) ?? nil, let i = Int(v) { return i }
        return fallback
    }
    func optInt(_ key: Key) -> Int? {
        let v = int(key, Int.min)
        return v == Int.min ? nil : v
    }
}

struct ExtraCounter: Codable, Identifiable, Equatable {
    var id: String = UID.make()
    var name: String = "Counter"
    var value: Int = 0
    var linked: Bool = true
    var resetAt: Int? = nil
    var repeats: Int = 0
    var repeatTarget: Int? = nil

    init(id: String = UID.make(), name: String = "Counter", value: Int = 0, linked: Bool = true, resetAt: Int? = nil, repeats: Int = 0, repeatTarget: Int? = nil) {
        self.id = id; self.name = name; self.value = value; self.linked = linked
        self.resetAt = resetAt; self.repeats = repeats; self.repeatTarget = repeatTarget
    }
    enum CodingKeys: String, CodingKey { case id, name, value, linked, resetAt, repeats, repeatTarget }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.val(.id, UID.make()); name = c.val(.name, "Counter"); value = max(0, c.int(.value, 0))
        linked = c.val(.linked, true); resetAt = c.optInt(.resetAt).flatMap { $0 > 0 ? $0 : nil }
        repeats = max(0, c.int(.repeats, 0)); repeatTarget = c.optInt(.repeatTarget).flatMap { $0 > 0 ? $0 : nil }
    }
}

/// Undo snapshot: `{ rows, c: [[counterId, value, repeats]] }` exactly like the web app.
struct UndoSnap: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var id: String; var value: Int; var repeats: Int
        init(id: String, value: Int, repeats: Int) { self.id = id; self.value = value; self.repeats = repeats }
        init(from d: Decoder) throws {
            var u = try d.unkeyedContainer()
            id = (try? u.decode(String.self)) ?? ""
            value = (try? u.decode(Int.self)) ?? 0
            repeats = (try? u.decode(Int.self)) ?? 0
        }
        func encode(to e: Encoder) throws {
            var u = e.unkeyedContainer()
            try u.encode(id); try u.encode(value); try u.encode(repeats)
        }
    }
    var rows: Int
    var c: [Entry]
    init(rows: Int, c: [Entry]) { self.rows = rows; self.c = c }
    enum CodingKeys: String, CodingKey { case rows, c }
    init(from d: Decoder) throws {
        let k = try d.container(keyedBy: CodingKeys.self)
        rows = max(0, k.int(.rows, 0)); c = k.val(.c, [])
    }
}

struct LogEntry: Codable, Equatable {
    var t: Double; var m: String; var r: Int
    init(t: Double, m: String, r: Int) { self.t = t; self.m = m; self.r = r }
    enum CodingKeys: String, CodingKey { case t, m, r }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        t = c.val(.t, 0.0); m = c.val(.m, ""); r = c.int(.r, 0)
    }
}

struct ProjectTimer: Codable, Equatable {
    var totalMs: Double = 0
    var runningSince: Double? = nil
    var sessions: [[Double]] = []
    init() {}
    enum CodingKeys: String, CodingKey { case totalMs, runningSince, sessions }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        totalMs = c.val(.totalMs, 0.0); runningSince = c.val(.runningSince, Double?.none); sessions = c.val(.sessions, [])
    }
}

/// Chart markup stroke (Pro). Drawn on top of ONE original page of the one pattern file; the pattern itself is never edited.
/// Points are fractions of that page (x of width, y of height); `w` is stroke width as a fraction of page width.
/// JSON (shared with Android): { id, page, tool: "pen"|"hl", color: "#RRGGBB", w, pts: [x0, y0, x1, y1, ...] }
struct Mark: Codable, Equatable, Identifiable {
    static let maxPoints = 4000
    var id: String = UID.make()
    var page: Int = 0
    var tool: String = "pen"
    var color: String = "#B5523B"
    var w: Double = 0.006
    var pts: [Double] = []
    var isHighlighter: Bool { tool == "hl" }
    init(id: String = UID.make(), page: Int, tool: String, color: String, w: Double, pts: [Double]) {
        self.id = id; self.page = page; self.tool = tool; self.color = color; self.w = w; self.pts = pts
    }
    enum CodingKeys: String, CodingKey { case id, page, tool, color, w, pts }
    /// Lenient, like Android: bad values are clamped; a mark with no usable point fails to decode and is dropped.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let raw = (try? c.decode([JSONValue].self, forKey: .pts)) ?? []
        let nums: [Double] = raw.compactMap { if case .number(let n) = $0, n.isFinite { return min(1, max(0, n)) }; return nil }
        let even = Array(nums.prefix(min(Mark.maxPoints * 2, nums.count - nums.count % 2)))
        guard even.count >= 2 else { throw DecodingError.dataCorruptedError(forKey: .pts, in: c, debugDescription: "no points") }
        id = c.val(.id, UID.make()); page = max(0, c.int(.page, 0))
        tool = c.val(.tool, "pen") == "hl" ? "hl" : "pen"
        let col = c.val(.color, "#B5523B")
        color = Mark.isHex(col) ? col : "#B5523B"
        w = min(0.08, max(0.001, c.val(.w, 0.006))); pts = even
    }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(page, forKey: .page); try c.encode(tool, forKey: .tool)
        try c.encode(color, forKey: .color); try c.encode(w, forKey: .w)
        try c.encode(pts.map { ($0 * 10000).rounded() / 10000 }, forKey: .pts)
    }
    static func isHex(_ s: String) -> Bool { s.count == 7 && s.first == "#" && s.dropFirst().allSatisfy(\.isHexDigit) }
}

/// Decodes an array of marks, skipping invalid ones instead of failing.
private struct LossyMark: Decodable { let m: Mark?; init(from d: Decoder) throws { m = try? Mark(from: d) } }

struct PatternInfo: Codable, Equatable {
    static let maxMarks = 1500
    var name: String = "Pattern"
    var type: String = "pdf"   // "pdf" | "image"
    var page: Int = 0
    var rel: Double = 0.12
    var size: Double = 0.035
    var zoom: Double = 1
    var follow: Bool = true
    var marks: [Mark] = []
    var showMarks: Bool = true
    var extras: [String: JSONValue] = [:]
    init(name: String, type: String) { self.name = name; self.type = type }
    enum CodingKeys: String, CodingKey, CaseIterable { case name, type, page, rel, size, zoom, follow, marks, showMarks }
    static let known = CodingKeys.allCases.map(\.rawValue)
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        name = c.val(.name, "Pattern"); type = c.val(.type, "pdf"); page = max(0, c.int(.page, 0))
        rel = c.val(.rel, 0.12); size = c.val(.size, 0.035); zoom = c.val(.zoom, 1.0); follow = c.val(.follow, true)
        marks = Array(c.val(.marks, [LossyMark]()).compactMap(\.m).suffix(PatternInfo.maxMarks))
        showMarks = c.val(.showMarks, true)
        extras = Extras.read(d, known: PatternInfo.known)
    }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name); try c.encode(type, forKey: .type); try c.encode(page, forKey: .page)
        try c.encode(rel, forKey: .rel); try c.encode(size, forKey: .size); try c.encode(zoom, forKey: .zoom); try c.encode(follow, forKey: .follow)
        if !marks.isEmpty { try c.encode(marks, forKey: .marks) }
        if !showMarks { try c.encode(false, forKey: .showMarks) }
        try Extras.write(extras, to: e, known: PatternInfo.known)
    }
}

struct Project: Codable, Identifiable, Equatable {
    var id: String = UID.make()
    var name: String = "My project"
    var craft: String = "knit"   // "knit" | "crochet"
    var rows: Int = 0
    var target: Int? = nil
    var notes: String = ""
    var hasPhoto: Bool = false
    var pattern: PatternInfo? = nil
    var counters: [ExtraCounter] = []
    var undo: [UndoSnap] = []
    var log: [LogEntry] = []
    var timer = ProjectTimer()
    var createdAt: Double = nowMs()
    var updatedAt: Double = nowMs()
    var extras: [String: JSONValue] = [:]

    init(name: String = "My project", craft: String = "knit") {
        self.name = name.isEmpty ? "My project" : name
        self.craft = craft == "crochet" ? "crochet" : "knit"
    }
    var isCrochet: Bool { craft == "crochet" }

    enum CodingKeys: String, CodingKey, CaseIterable { case id, name, craft, rows, target, notes, hasPhoto, pattern, counters, undo, log, timer, createdAt, updatedAt }
    /// "reminders" was removed in 2026-10; it is read as known so it is dropped, not carried along.
    static let known = CodingKeys.allCases.map(\.rawValue) + ["reminders"]
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.val(.id, UID.make()); name = c.val(.name, "My project"); craft = c.val(.craft, "knit")
        rows = max(0, c.int(.rows, 0)); target = c.optInt(.target).flatMap { $0 > 0 ? $0 : nil }
        notes = c.val(.notes, ""); hasPhoto = c.val(.hasPhoto, false); pattern = c.val(.pattern, PatternInfo?.none)
        counters = c.val(.counters, [])  // legacy "reminders" key in old data/backups is ignored
        undo = Array(c.val(.undo, [UndoSnap]()).suffix(Engine.undoCap))
        log = Array(c.val(.log, [LogEntry]()).suffix(Engine.logCap))
        timer = c.val(.timer, ProjectTimer()); createdAt = c.val(.createdAt, nowMs()); updatedAt = c.val(.updatedAt, nowMs())
        extras = Extras.read(d, known: Project.known)
    }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name); try c.encode(craft, forKey: .craft); try c.encode(rows, forKey: .rows)
        try c.encodeIfPresent(target, forKey: .target); try c.encode(notes, forKey: .notes); try c.encode(hasPhoto, forKey: .hasPhoto)
        try c.encodeIfPresent(pattern, forKey: .pattern); try c.encode(counters, forKey: .counters); try c.encode(undo, forKey: .undo)
        try c.encode(log, forKey: .log); try c.encode(timer, forKey: .timer); try c.encode(createdAt, forKey: .createdAt); try c.encode(updatedAt, forKey: .updatedAt)
        try Extras.write(extras, to: e, known: Project.known)
    }
}

struct Settings: Codable, Equatable {
    var theme: String = "oat"
    var haptics: Bool = true
    var tapAnywhere: Bool = false
    var locked: Bool = false
    var keepAwake: Bool = false
    var tipsSeen: Bool = false
    var lastBackup: Double? = nil
    var lastProjectId: String? = nil
    var createdAt: Double = nowMs()
    var reduceMotion: Bool = false   // Pro
    var extras: [String: JSONValue] = [:]
    init() {}
    enum CodingKeys: String, CodingKey, CaseIterable { case theme, haptics, tapAnywhere, locked, keepAwake, tipsSeen, lastBackup, lastProjectId, createdAt, reduceMotion }
    /// "license" is the web app's Gumroad key; it is never carried into the native apps.
    static let known = CodingKeys.allCases.map(\.rawValue) + ["license"]
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        theme = c.val(.theme, "oat"); haptics = c.val(.haptics, true); tapAnywhere = c.val(.tapAnywhere, false)
        locked = c.val(.locked, false); keepAwake = c.val(.keepAwake, false); tipsSeen = c.val(.tipsSeen, false)
        lastBackup = c.val(.lastBackup, Double?.none); lastProjectId = c.val(.lastProjectId, String?.none); createdAt = c.val(.createdAt, nowMs())
        reduceMotion = c.val(.reduceMotion, false)
        extras = Extras.read(d, known: Settings.known)
    }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(theme, forKey: .theme); try c.encode(haptics, forKey: .haptics); try c.encode(tapAnywhere, forKey: .tapAnywhere)
        try c.encode(locked, forKey: .locked); try c.encode(keepAwake, forKey: .keepAwake); try c.encode(tipsSeen, forKey: .tipsSeen)
        try c.encodeIfPresent(lastBackup, forKey: .lastBackup); try c.encodeIfPresent(lastProjectId, forKey: .lastProjectId)
        try c.encode(createdAt, forKey: .createdAt); try c.encode(reduceMotion, forKey: .reduceMotion)
        try Extras.write(extras, to: e, known: Settings.known)
    }
}

struct AppState: Codable, Equatable {
    var v: Int = 1
    var settings = Settings()
    var projects: [Project] = []
    init() {}
    enum CodingKeys: String, CodingKey { case v, settings, projects }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        v = 1; settings = c.val(.settings, Settings()); projects = c.val(.projects, [])
    }
    func project(_ id: String?) -> Project? { projects.first { $0.id == id } }
    func index(_ id: String?) -> Int? { projects.firstIndex { $0.id == id } }
    /// The project shown by widgets and opened at launch.
    var currentProject: Project? { project(settings.lastProjectId) ?? projects.first }
}

/// Backup file, same shape as the web app's export.
struct BackupFile: Codable {
    var app: String = "rowbin"
    var schema: Int = 1
    var exportedAt: String
    var state: AppState
    var files: [String: String] = [:]
    init(state: AppState, files: [String: String], exportedAt: String) { self.state = state; self.files = files; self.exportedAt = exportedAt }
    enum CodingKeys: String, CodingKey { case app, schema, exportedAt, state, files }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        app = c.val(.app, ""); schema = c.int(.schema, 1); exportedAt = c.val(.exportedAt, "")
        state = try c.decode(AppState.self, forKey: .state); files = c.val(.files, [:])
    }
}
