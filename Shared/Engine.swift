import Foundation

/// Pure counting rules, shared by the app and the widget buttons. Mirrors the web app exactly.
enum Engine {
    static let freeProjectLimit = 2
    static let freeExtraCounters = 1
    static let undoCap = 100
    static let logCap = 500
    static let sessionCap = 1000

    enum Feedback: Equatable { case none, soft, normal, strong }
    struct RowResult: Equatable {
        var changed = false
        var reminderText: String? = nil
        var reachedTarget = false
        var feedback: Feedback = .none
        var blockedByLock = false
    }

    static func snapshot(_ p: Project) -> UndoSnap {
        UndoSnap(rows: p.rows, c: p.counters.map { .init(id: $0.id, value: $0.value, repeats: $0.repeats) })
    }
    static func pushUndo(_ p: inout Project) {
        p.undo.append(snapshot(p))
        if p.undo.count > undoCap { p.undo.removeFirst(p.undo.count - undoCap) }
    }
    static func log(_ p: inout Project, _ msg: String, at t: Double = nowMs()) {
        p.log.append(LogEntry(t: t, m: msg, r: p.rows))
        if p.log.count > logCap { p.log.removeFirst(p.log.count - logCap) }
        p.updatedAt = t
    }
    static func bump(_ c: inout ExtraCounter, _ dir: Int) {
        if dir > 0 {
            c.value += 1
            if let r = c.resetAt, c.value > r { c.value = 1; c.repeats += 1 }
        } else if let r = c.resetAt, c.value <= 1, c.repeats > 0 {
            c.value = r; c.repeats -= 1
        } else {
            c.value = max(0, c.value - 1)
        }
    }

    /// +1 / -1 on the main row count.
    @discardableResult
    static func changeRows(_ p: inout Project, _ delta: Int, locked: Bool, pro: Bool) -> RowResult {
        var res = RowResult()
        if locked { res.blockedByLock = true; return res }
        let from = p.rows, to = max(0, from + delta)
        if to == from { res.feedback = .soft; return res }
        pushUndo(&p)
        p.rows = to
        for i in p.counters.indices where p.counters[i].linked { bump(&p.counters[i], delta) }
        log(&p, "Row \(from) → \(to)")
        res.changed = true; res.feedback = .normal
        if delta > 0, let text = reminderHits(p, pro: pro) { res.reminderText = text; res.feedback = .strong }
        if delta > 0, let t = p.target, to == t { res.reachedTarget = true; res.feedback = .strong }
        return res
    }

    /// Returns false when there was nothing to undo.
    @discardableResult
    static func undo(_ p: inout Project) -> Bool {
        guard let s = p.undo.popLast() else { return false }
        let from = p.rows
        p.rows = s.rows
        for e in s.c { if let i = p.counters.firstIndex(where: { $0.id == e.id }) { p.counters[i].value = e.value; p.counters[i].repeats = e.repeats } }
        log(&p, "Undo: row \(from) → \(p.rows)")
        return true
    }

    static func setRows(_ p: inout Project, _ to: Int, why: String = "Set") {
        let to = max(0, to)
        pushUndo(&p)
        let from = p.rows
        p.rows = to
        log(&p, "\(why): row \(from) → \(to)")
    }

    static func reset(_ p: inout Project) {
        pushUndo(&p)
        let from = p.rows
        p.rows = 0
        for i in p.counters.indices where p.counters[i].linked { p.counters[i].value = 0; p.counters[i].repeats = 0 }
        log(&p, "Reset: row \(from) → 0")
    }

    /// Extra counter +/-; returns false if locked or not found.
    @discardableResult
    static func changeCounter(_ p: inout Project, id: String, _ dir: Int, locked: Bool) -> Bool {
        if locked { return false }
        guard let i = p.counters.firstIndex(where: { $0.id == id }) else { return false }
        pushUndo(&p)
        let from = p.counters[i].value
        bump(&p.counters[i], dir)
        log(&p, "\(p.counters[i].name): \(from) → \(p.counters[i].value)")
        return true
    }

    // MARK: reminders (Pro)
    static func reminderHits(_ p: Project, pro: Bool) -> String? {
        guard pro else { return nil }
        let hits = p.reminders.filter { $0.every > 0 && p.rows >= $0.start && (p.rows - $0.start) % $0.every == 0 }
        return hits.isEmpty ? nil : hits.map(\.text).joined(separator: " · ")
    }
    static func nextReminderText(_ p: Project, pro: Bool) -> String? {
        guard pro, !p.reminders.isEmpty else { return nil }
        var best: (d: Int, r: Reminder)? = nil
        for r in p.reminders where r.every > 0 {
            let d = p.rows < r.start ? r.start - p.rows : (r.every - ((p.rows - r.start) % r.every)) % r.every
            if best == nil || d < best!.d { best = (d, r) }
        }
        guard let b = best else { return nil }
        return b.d == 0 ? "🔔 This row: \(b.r.text)" : "🔔 \(b.r.text) in \(plural(b.d, "row"))"
    }

    // MARK: timer (Pro), timestamp based so it keeps running while the app is closed
    static func timerElapsed(_ p: Project, now: Double = nowMs()) -> Double {
        p.timer.totalMs + (p.timer.runningSince.map { now - $0 } ?? 0)
    }
    static func timerToggle(_ p: inout Project, now: Double = nowMs()) {
        if let start = p.timer.runningSince {
            p.timer.totalMs += now - start
            p.timer.sessions.append([start, now])
            if p.timer.sessions.count > sessionCap { p.timer.sessions.removeFirst(p.timer.sessions.count - sessionCap) }
            p.timer.runningSince = nil
            log(&p, "Timer paused at \(fmtDur(p.timer.totalMs))", at: now)
        } else {
            p.timer.runningSince = now
            log(&p, "Timer started", at: now)
        }
    }
    static func timerSet(_ p: inout Project, hours: Int, minutes: Int, now: Double = nowMs()) {
        let total = Double(max(0, hours) * 3600 + min(59, max(0, minutes)) * 60) * 1000
        p.timer.totalMs = total
        if p.timer.runningSince != nil { p.timer.runningSince = now }
        log(&p, "Timer set to \(fmtDur(total))", at: now)
    }

    // MARK: limits
    static func canAddProject(count: Int, pro: Bool) -> Bool { pro || count < freeProjectLimit }
    static func canAddCounter(_ p: Project, pro: Bool) -> Bool { pro || p.counters.count < freeExtraCounters }
    static func effectiveTheme(_ s: Settings, pro: Bool) -> String { pro ? s.theme : "oat" }

    static func targetLine(_ p: Project) -> String? {
        guard let t = p.target, t > 0 else { return nil }
        return "of \(t) · \(min(100, Int((Double(p.rows) / Double(t) * 100).rounded())))%"
    }
    /// First counter that has "repeat every N" set; used by widgets.
    static func repeatCounter(_ p: Project) -> ExtraCounter? { p.counters.first { $0.resetAt != nil } }

    /// Makes sure there is a project to open, like the web app's first launch.
    static func ensureProject(_ s: inout AppState) -> String {
        if let p = s.currentProject { return p.id }
        var p = Project(name: "My first project", craft: "knit")
        p.updatedAt = nowMs()
        s.projects.append(p)
        s.settings.lastProjectId = p.id
        return p.id
    }
}

func plural(_ n: Int, _ w: String) -> String { "\(n) \(w)\(n == 1 ? "" : "s")" }
func fmtDur(_ ms: Double) -> String {
    let s = max(0, Int(ms / 1000)), h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return String(format: "%d:%02d:%02d", h, m, sec)
}
