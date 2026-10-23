import Foundation

// MARK: - Shaping plan (Pro)
// A passive, written plan the knitter reads beside the counter. Rowbin never pops up, notifies or prompts
// on any row: the list simply shows which shaping rows are done and the live stitch count.
// JSON (shared with Android):
// shaping: { start: Int (stitches before row 1), steps: [ { id, kind: "even"|"every", dir: "inc"|"dec", row, count, every, times } ] }
//   even:  on `row`, change the stitch count by `count`, spread evenly across the row.
//   every: starting on `row`, change by `count` stitches every `every` rows, `times` times.

struct ShapeStep: Codable, Equatable, Identifiable {
    var id: String = UID.make()
    var kind: String = "every"   // "even" | "every"
    var dir: String = "dec"      // "inc" | "dec"
    var row: Int = 1
    var count: Int = 2
    var every: Int = 4
    var times: Int = 1
    var isInc: Bool { dir == "inc" }
    var isEven: Bool { kind == "even" }
    init(id: String = UID.make(), kind: String, dir: String, row: Int, count: Int, every: Int = 1, times: Int = 1) {
        self.id = id; self.kind = kind == "even" ? "even" : "every"; self.dir = dir == "inc" ? "inc" : "dec"
        self.row = max(1, row); self.count = max(1, count); self.every = max(1, every); self.times = max(1, times)
    }
    enum CodingKeys: String, CodingKey { case id, kind, dir, row, count, every, times }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        self.init(id: c.val(.id, UID.make()), kind: c.val(.kind, "every"), dir: c.val(.dir, "dec"),
                  row: min(100_000, c.int(.row, 1)), count: min(10_000, c.int(.count, 1)),
                  every: min(10_000, c.int(.every, 1)), times: min(1_000, c.int(.times, 1)))
    }
}

struct ShapingPlan: Codable, Equatable {
    var start: Int = 0
    var steps: [ShapeStep] = []
    init(start: Int = 0, steps: [ShapeStep] = []) { self.start = max(0, start); self.steps = steps }
    enum CodingKeys: String, CodingKey { case start, steps }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        start = max(0, min(1_000_000, c.int(.start, 0)))
        steps = Array(c.val(.steps, [ShapeStep]()).prefix(ShapingMath.maxSteps))
    }
}

enum ShapingMath {
    static let maxSteps = 40
    static let maxRows = 2000

    struct PlanRow: Equatable, Identifiable {
        var row: Int
        var change: Int          // + increases, − decreases on this row
        var after: Int           // stitches after working this row
        var stepID: String
        var text: String         // e.g. "Decrease 2" or "K6, M1 × 8 …"
        var id: String { "\(stepID)-\(row)" }
    }

    /// Every shaping row in row order. Rows in the same row from different steps stay separate lines.
    static func rows(_ plan: ShapingPlan, crochet: Bool) -> [PlanRow] {
        var events: [(row: Int, order: Int, step: ShapeStep)] = []
        for (o, s) in plan.steps.enumerated() {
            if s.isEven { events.append((s.row, o, s)) }
            else { for k in 0..<s.times { events.append((s.row + k * s.every, o, s)) } }
            if events.count > maxRows { break }
        }
        events.sort { $0.row != $1.row ? $0.row < $1.row : $0.order < $1.order }
        var sts = plan.start
        var out: [PlanRow] = []
        for e in events.prefix(maxRows) {
            let before = sts
            let delta = e.step.isInc ? e.step.count : -min(e.step.count, sts)
            sts = max(0, sts + delta)
            let text: String
            if e.step.isEven, let ev = even(stitches: before, change: e.step.count, inc: e.step.isInc, crochet: crochet) { text = ev.text }
            else { text = "\(e.step.isInc ? "Increase" : "Decrease") \(e.step.count)" }
            out.append(PlanRow(row: e.row, change: delta, after: sts, stepID: e.step.id, text: text))
        }
        return out
    }

    /// Stitches on the needle/hook after `completedRows` rows are done.
    static func stitches(_ plan: ShapingPlan, crochet: Bool, completedRows: Int) -> Int {
        rows(plan, crochet: crochet).last { $0.row <= completedRows }?.after ?? plan.start
    }
    static func finalStitches(_ plan: ShapingPlan, crochet: Bool) -> Int { rows(plan, crochet: crochet).last?.after ?? plan.start }
    /// First shaping row not yet worked (row number is greater than the completed count).
    static func next(_ plan: ShapingPlan, crochet: Bool, completedRows: Int) -> PlanRow? {
        rows(plan, crochet: crochet).first { $0.row > completedRows }
    }

    // MARK: even spacing
    struct Even: Equatable {
        struct Segment: Equatable { var plain: Int; var reps: Int }
        var segments: [Segment]   // each segment = `plain` plain stitches then one shaping stitch, repeated `reps` times
        var tail: Int             // plain stitches at the end of the row
        var result: Int           // stitches after the row
        var text: String
    }

    /// Spreads `change` increases or decreases evenly over a row of `stitches`.
    /// Knit: M1 uses no stitch, k2tog uses 2. Crochet: an increase (2 sc in next) uses 1, sc2tog uses 2.
    /// Plain stitches are split into equal groups (bigger groups first); for knit increases, half a group is
    /// kept at each end so no increase sits on the edge. Returns nil if it can't be done.
    static func even(stitches s: Int, change k: Int, inc: Bool, crochet: Bool) -> Even? {
        guard s > 0, k > 0 else { return nil }
        let used = inc ? (crochet ? 1 : 0) : 2
        let plain = s - used * k
        guard plain >= 0, inc || k * 2 <= s, !(inc && !crochet && k > s) else { return nil }
        let opName = inc ? (crochet ? "inc" : "M1") : (crochet ? "sc2tog" : "k2tog")
        let st = crochet ? "sc" : "K"
        var segs: [Even.Segment] = []
        var tail = 0
        if inc && !crochet {
            // k increases between k+1 groups of plain stitches; the outer two share one group.
            let groups = k + 1
            let q = plain / groups, r = plain % groups
            // Distribute: first `r` groups get q+1. Edge groups are the first and last.
            var sizes = Array(repeating: q, count: groups)
            for i in 0..<r { sizes[i] += 1 }
            // Move a bigger group to the end so both edges look alike.
            if r > 0 && r < groups { sizes.swapAt(r - 1, groups - 1) }
            tail = sizes[groups - 1]
            for x in sizes.prefix(k) {
                if let l = segs.last, l.plain == x { segs[segs.count - 1].reps += 1 } else { segs.append(.init(plain: x, reps: 1)) }
            }
        } else {
            let q = plain / k, r = plain % k
            if r > 0 { segs.append(.init(plain: q + 1, reps: r)) }
            if k - r > 0 { segs.append(.init(plain: q, reps: k - r)) }
        }
        let parts = segs.map { g -> String in
            let body = g.plain > 0 ? "\(st)\(g.plain), \(opName)" : opName
            return g.reps > 1 ? "(\(body)) × \(g.reps)" : body
        } + (tail > 0 ? ["\(st)\(tail)"] : [])
        let result = inc ? s + k : s - k
        return Even(segments: segs, tail: tail, result: result, text: parts.joined(separator: ", ") + " (\(result) sts)")
    }

    // MARK: spreading shaping rows over a length
    struct Spread: Equatable { var firstEvery: Int; var firstTimes: Int; var thenEvery: Int; var thenTimes: Int }
    /// `times` shaping rows spread as evenly as possible over `rows` rows.
    /// Gives e.g. "every 5 rows 3 times, then every 6 rows 5 times" (the longer gaps come last).
    static func spread(times x: Int, overRows r: Int) -> Spread? {
        guard x > 0, r >= x else { return nil }
        let n = r / x, extra = r % x
        return Spread(firstEvery: n, firstTimes: x - extra, thenEvery: n + 1, thenTimes: extra)
    }
    /// How many shaping rows are needed to go from `from` to `to` stitches, `per` stitches per shaping row.
    static func timesNeeded(from: Int, to: Int, per: Int) -> Int? {
        guard per > 0 else { return nil }
        let d = abs(to - from)
        guard d % per == 0 else { return nil }
        return d / per
    }
}

// MARK: - Gauge & yarn planner (Pro)
// JSON: gauge: { unit: "in"|"cm", per, patSts, patRows, swSts, swRows, swW, swH, swGrams,
//               skeinLen, skeinGrams, skeins, patYardage, width, length, margin }
// All numbers are optional (0 or missing = not entered).
struct GaugeInfo: Codable, Equatable {
    var unit: String = "in"
    var per: Double = 4        // pattern gauge is "X sts and Y rows over `per` units"
    var patSts: Double = 0
    var patRows: Double = 0
    var swSts: Double = 0      // stitches counted across the swatch
    var swRows: Double = 0
    var swW: Double = 0        // measured width of those stitches
    var swH: Double = 0        // measured height of those rows
    var swGrams: Double = 0    // weight of the whole swatch
    var skeinLen: Double = 0   // length per skein (yards when unit is "in", metres when "cm")
    var skeinGrams: Double = 0
    var skeins: Double = 0     // skeins you have
    var patYardage: Double = 0 // length the pattern asks for, same length unit
    var width: Double = 0      // finished piece size (for the weight-based estimate)
    var length: Double = 0
    var margin: Double = 10    // % extra
    init() {}
    enum CodingKeys: String, CodingKey, CaseIterable { case unit, per, patSts, patRows, swSts, swRows, swW, swH, swGrams, skeinLen, skeinGrams, skeins, patYardage, width, length, margin }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        func n(_ k: CodingKeys, _ f: Double = 0) -> Double { let v = c.val(k, f); return v.isFinite ? min(1_000_000, max(0, v)) : f }
        unit = c.val(.unit, "in") == "cm" ? "cm" : "in"; per = n(.per, unit == "cm" ? 10 : 4)
        patSts = n(.patSts); patRows = n(.patRows); swSts = n(.swSts); swRows = n(.swRows); swW = n(.swW); swH = n(.swH)
        swGrams = n(.swGrams); skeinLen = n(.skeinLen); skeinGrams = n(.skeinGrams); skeins = n(.skeins)
        patYardage = n(.patYardage); width = n(.width); length = n(.length); margin = min(100, n(.margin, 10))
    }
}

enum GaugeMath {
    /// Stitches (or rows) per one unit.
    static func rate(_ count: Double, over len: Double) -> Double? { count > 0 && len > 0 ? count / len : nil }
    static func patternSts(_ g: GaugeInfo) -> Double? { rate(g.patSts, over: g.per) }
    static func patternRows(_ g: GaugeInfo) -> Double? { rate(g.patRows, over: g.per) }
    static func mySts(_ g: GaugeInfo) -> Double? { rate(g.swSts, over: g.swW) }
    static func myRows(_ g: GaugeInfo) -> Double? { rate(g.swRows, over: g.swH) }
    /// Your gauge expressed over the pattern's measuring length, e.g. "19.2 sts over 4 in".
    static func myOverPer(_ g: GaugeInfo) -> (sts: Double?, rows: Double?) {
        (mySts(g).map { $0 * g.per }, myRows(g).map { $0 * g.per })
    }

    /// Pattern stitch count → stitches you need at your gauge for the same width.
    static func convertSts(_ n: Double, _ g: GaugeInfo) -> Int? {
        guard let p = patternSts(g), let m = mySts(g), n > 0 else { return nil }
        return Int((n / p * m).rounded())
    }
    static func convertRows(_ n: Double, _ g: GaugeInfo) -> Int? {
        guard let p = patternRows(g), let m = myRows(g), n > 0 else { return nil }
        return Int((n / p * m).rounded())
    }
    /// Width you'd get if you work the pattern's stitch count unchanged at your gauge.
    static func sizeAtMyGauge(sts n: Double, _ g: GaugeInfo) -> Double? {
        guard let m = mySts(g), n > 0 else { return nil }
        return n / m
    }
    static func sizeAtPatternGauge(sts n: Double, _ g: GaugeInfo) -> Double? {
        guard let p = patternSts(g), n > 0 else { return nil }
        return n / p
    }
    /// Percent difference in width if you follow the pattern as written (positive = bigger).
    static func widthDiffPercent(_ g: GaugeInfo) -> Double? {
        guard let p = patternSts(g), let m = mySts(g) else { return nil }
        return (p / m - 1) * 100
    }

    struct Yarn: Equatable {
        var needLen: Double?      // length incl. margin
        var needGrams: Double?    // weight incl. margin
        var needSkeins: Int?      // whole skeins to buy/have
        var haveLen: Double?
        var shortSkeins: Int?     // > 0 when you don't have enough
    }

    /// Two honest estimates: from the pattern's stated length (adjusted for stitch density), and from the
    /// weight of your swatch scaled to the finished area. The larger is used for skeins.
    static func yarn(_ g: GaugeInfo) -> Yarn {
        let m = 1 + g.margin / 100
        var lenFromPattern: Double? = nil
        if g.patYardage > 0 {
            var factor = 1.0
            // More stitches and rows per unit area = more yarn for the same piece.
            if let ps = patternSts(g), let pr = patternRows(g), let ms = mySts(g), let mr = myRows(g) { factor = (ms * mr) / (ps * pr) }
            lenFromPattern = g.patYardage * factor * m
        }
        var gramsFromSwatch: Double? = nil
        if g.swGrams > 0, g.width > 0, g.length > 0, let area = swatchArea(g), area > 0 {
            gramsFromSwatch = g.swGrams / area * g.width * g.length * m
        }
        var out = Yarn()
        out.needGrams = gramsFromSwatch
        if let gr = gramsFromSwatch, g.skeinGrams > 0, g.skeinLen > 0 { out.needLen = max(lenFromPattern ?? 0, gr / g.skeinGrams * g.skeinLen) }
        else { out.needLen = lenFromPattern }
        if let L = out.needLen, g.skeinLen > 0 { out.needSkeins = Int((L / g.skeinLen - 1e-9).rounded(.up)) }
        else if let gr = gramsFromSwatch, g.skeinGrams > 0 { out.needSkeins = Int((gr / g.skeinGrams - 1e-9).rounded(.up)) }
        if g.skeins > 0 {
            if g.skeinLen > 0 { out.haveLen = g.skeins * g.skeinLen }
            if let need = out.needSkeins { out.shortSkeins = max(0, need - Int(g.skeins.rounded(.down))) }
        }
        return out
    }
    /// The swatch's area: the measured part (sts × rows) scaled up to the whole swatch is unknown, so the
    /// swatch weight is taken to cover the measured width × height. The app says this in its help text.
    static func swatchArea(_ g: GaugeInfo) -> Double? { g.swW > 0 && g.swH > 0 ? g.swW * g.swH : nil }
}

// MARK: - Eyes-free counting
enum Milestone: Equatable { case none, five, ten, repeatDone }
enum EyesFree {
    /// Which haptic to play after going from `before` to `after` (only for +1).
    /// A finished repeat wins over 10, and 10 wins over 5.
    static func milestone(before: Project, after: Project) -> Milestone {
        guard after.rows == before.rows + 1 else { return .none }
        let repeatDone = after.counters.contains { c in
            guard c.linked, c.resetAt != nil, let b = before.counters.first(where: { $0.id == c.id }) else { return false }
            return c.repeats > b.repeats
        }
        if repeatDone { return .repeatDone }
        if after.rows % 10 == 0 { return .ten }
        if after.rows % 5 == 0 { return .five }
        return .none
    }
    static func phrase(_ p: Project, _ m: Milestone) -> String {
        let base = "Row \(p.rows)"
        if m == .repeatDone, let c = p.counters.first(where: { $0.resetAt != nil }) { return "\(base). Repeat \(c.repeats) done" }
        return base
    }
}

// MARK: - Project journal (free)
// JSON: journal: [ { id, t, kind: "photo"|"note", text } ]. A photo is the file "jphoto:<projectId>.<entryId>".
struct JournalEntry: Codable, Equatable, Identifiable {
    var id: String = UID.make()
    var t: Double = nowMs()
    var kind: String = "note"
    var text: String = ""
    init(id: String = UID.make(), t: Double = nowMs(), kind: String, text: String = "") {
        self.id = id; self.t = t; self.kind = kind == "photo" ? "photo" : "note"; self.text = String(text.prefix(500))
    }
    enum CodingKeys: String, CodingKey { case id, t, kind, text }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        self.init(id: c.val(.id, UID.make()), t: c.val(.t, nowMs()), kind: c.val(.kind, "note"), text: c.val(.text, ""))
    }
    static func fileKey(project: String, entry: String) -> String { "jphoto:\(project).\(entry)" }
}

enum JournalMath {
    static let maxEntries = 300
    /// Gap that splits two knitting sessions when the timer isn't used.
    static let sessionGapMs: Double = 30 * 60 * 1000

    struct Session: Equatable { var start: Double; var end: Double; var rows: Int }
    /// Sessions from the row history: changes closer than 30 minutes belong together.
    /// Only row moves count ("Row a → b"); `rows` is the net rows added in that session.
    static func sessions(_ log: [LogEntry]) -> [Session] {
        var out: [Session] = []
        for e in log.sorted(by: { $0.t < $1.t }) {
            guard e.m.hasPrefix("Row "), let from = Int(e.m.dropFirst(4).prefix { $0.isNumber }) else { continue }
            let delta = e.r - from
            if var last = out.last, e.t - last.end <= sessionGapMs {
                last.end = e.t; last.rows += delta; out[out.count - 1] = last
            } else {
                out.append(Session(start: e.t, end: e.t, rows: delta))
            }
        }
        return out
    }

    struct Pace: Equatable {
        var sessions: Int
        var activeDays: Int
        var rowsPerSession: Double?
        var rowsPerDay: Double?
        var minutesPerRow: Double?   // only from the Pro timer, when used
        var sessionsLeft: Int?       // to the target, at this pace
    }
    static func pace(_ p: Project, calendar: Calendar = .current) -> Pace {
        let s = sessions(p.log)
        let added = s.reduce(0) { $0 + max(0, $1.rows) }
        let days = Set(s.map { calendar.startOfDay(for: Date(timeIntervalSince1970: $0.start / 1000)) }).count
        var out = Pace(sessions: s.count, activeDays: days)
        if !s.isEmpty, added > 0 { out.rowsPerSession = Double(added) / Double(s.count) }
        if days > 0, added > 0 { out.rowsPerDay = Double(added) / Double(days) }
        if p.timer.totalMs > 0, p.rows > 0 { out.minutesPerRow = p.timer.totalMs / 60000 / Double(p.rows) }
        if let t = p.target, t > p.rows, let rps = out.rowsPerSession, rps > 0 { out.sessionsLeft = Int((Double(t - p.rows) / rps).rounded(.up)) }
        return out
    }

    enum ItemKind: Equatable { case started, session, timer, photo, note, finished }
    struct Item: Equatable, Identifiable { var id: String; var t: Double; var kind: ItemKind; var title: String; var detail: String; var entryID: String? }

    /// The automatic timeline, newest first.
    static func timeline(_ p: Project) -> [Item] {
        var items: [Item] = [Item(id: "start", t: p.createdAt, kind: .started, title: "Started \(p.name)", detail: p.isCrochet ? "Crochet" : "Knitting", entryID: nil)]
        for (i, s) in sessions(p.log).enumerated() {
            let mins = Int(((s.end - s.start) / 60000).rounded())
            items.append(Item(id: "s\(i)", t: s.start, kind: .session, title: s.rows >= 0 ? "+\(plural(s.rows, "row"))" : "\(s.rows) rows",
                              detail: mins > 0 ? "Session of about \(mins) min" : "Short session", entryID: nil))
        }
        for (i, se) in p.timer.sessions.enumerated() where se.count == 2 && se[1] > se[0] {
            items.append(Item(id: "t\(i)", t: se[0], kind: .timer, title: "Timer \(fmtDur(se[1] - se[0]))", detail: "Timed session", entryID: nil))
        }
        for e in p.journal {
            items.append(Item(id: "j" + e.id, t: e.t, kind: e.kind == "photo" ? .photo : .note, title: e.kind == "photo" ? "Photo" : "Note", detail: e.text, entryID: e.id))
        }
        if let f = p.finishedAt { items.append(Item(id: "done", t: f, kind: .finished, title: "Finished 🎉", detail: "\(plural(p.rows, "row")) in total", entryID: nil)) }
        return items.sorted { $0.t > $1.t }
    }
}
