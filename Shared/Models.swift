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

struct Reminder: Codable, Identifiable, Equatable {
    var id: String = UID.make()
    var text: String = "Reminder"
    var every: Int = 6
    var start: Int = 0
    init(id: String = UID.make(), text: String, every: Int, start: Int) { self.id = id; self.text = text; self.every = every; self.start = start }
    enum CodingKeys: String, CodingKey { case id, text, every, start }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.val(.id, UID.make()); text = c.val(.text, "Reminder"); every = c.int(.every, 0); start = max(0, c.int(.start, 0))
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

struct PatternInfo: Codable, Equatable {
    var name: String = "Pattern"
    var type: String = "pdf"   // "pdf" | "image"
    var page: Int = 0
    var rel: Double = 0.12
    var size: Double = 0.035
    var zoom: Double = 1
    var follow: Bool = true
    init(name: String, type: String) { self.name = name; self.type = type }
    enum CodingKeys: String, CodingKey { case name, type, page, rel, size, zoom, follow }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        name = c.val(.name, "Pattern"); type = c.val(.type, "pdf"); page = max(0, c.int(.page, 0))
        rel = c.val(.rel, 0.12); size = c.val(.size, 0.035); zoom = c.val(.zoom, 1.0); follow = c.val(.follow, true)
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
    var reminders: [Reminder] = []
    var undo: [UndoSnap] = []
    var log: [LogEntry] = []
    var timer = ProjectTimer()
    var createdAt: Double = nowMs()
    var updatedAt: Double = nowMs()

    init(name: String = "My project", craft: String = "knit") {
        self.name = name.isEmpty ? "My project" : name
        self.craft = craft == "crochet" ? "crochet" : "knit"
    }
    var isCrochet: Bool { craft == "crochet" }

    enum CodingKeys: String, CodingKey { case id, name, craft, rows, target, notes, hasPhoto, pattern, counters, reminders, undo, log, timer, createdAt, updatedAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.val(.id, UID.make()); name = c.val(.name, "My project"); craft = c.val(.craft, "knit")
        rows = max(0, c.int(.rows, 0)); target = c.optInt(.target).flatMap { $0 > 0 ? $0 : nil }
        notes = c.val(.notes, ""); hasPhoto = c.val(.hasPhoto, false); pattern = c.val(.pattern, PatternInfo?.none)
        counters = c.val(.counters, []); reminders = c.val(.reminders, [])
        undo = Array(c.val(.undo, [UndoSnap]()).suffix(Engine.undoCap))
        log = Array(c.val(.log, [LogEntry]()).suffix(Engine.logCap))
        timer = c.val(.timer, ProjectTimer()); createdAt = c.val(.createdAt, nowMs()); updatedAt = c.val(.updatedAt, nowMs())
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
    init() {}
    enum CodingKeys: String, CodingKey { case theme, haptics, tapAnywhere, locked, keepAwake, tipsSeen, lastBackup, lastProjectId, createdAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        theme = c.val(.theme, "oat"); haptics = c.val(.haptics, true); tapAnywhere = c.val(.tapAnywhere, false)
        locked = c.val(.locked, false); keepAwake = c.val(.keepAwake, false); tipsSeen = c.val(.tipsSeen, false)
        lastBackup = c.val(.lastBackup, Double?.none); lastProjectId = c.val(.lastProjectId, String?.none); createdAt = c.val(.createdAt, nowMs())
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
