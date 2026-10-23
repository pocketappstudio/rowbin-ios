import XCTest
@testable import Rowbin

final class ShapingMathTests: XCTestCase {
    func testEvenIncreaseKnitKeepsEdgesPlain() throws {
        let e = try XCTUnwrap(ShapingMath.even(stitches: 84, change: 8, inc: true, crochet: false))
        XCTAssertEqual(e.result, 92)
        XCTAssertEqual(e.text, "(K10, M1) × 2, (K9, M1) × 6, K10 (92 sts)")
        XCTAssertEqual(e.segments.reduce(0) { $0 + $1.plain * $1.reps } + e.tail, 84, "every stitch is used once")
    }
    func testEvenDecreaseKnit() throws {
        XCTAssertEqual(ShapingMath.even(stitches: 80, change: 8, inc: false, crochet: false)?.text, "(K8, k2tog) × 8 (72 sts)")
        let e = try XCTUnwrap(ShapingMath.even(stitches: 30, change: 4, inc: false, crochet: false))
        XCTAssertEqual(e.text, "(K6, k2tog) × 2, (K5, k2tog) × 2 (26 sts)")
        XCTAssertEqual(e.segments.reduce(0) { $0 + ($1.plain + 2) * $1.reps } + e.tail, 30)
    }
    func testEvenCrochet() {
        XCTAssertEqual(ShapingMath.even(stitches: 24, change: 6, inc: true, crochet: true)?.text, "(sc3, inc) × 6 (30 sts)")
        XCTAssertEqual(ShapingMath.even(stitches: 30, change: 6, inc: false, crochet: true)?.text, "(sc3, sc2tog) × 6 (24 sts)")
    }
    func testEvenRejectsImpossible() {
        XCTAssertNil(ShapingMath.even(stitches: 10, change: 6, inc: false, crochet: false))
        XCTAssertNil(ShapingMath.even(stitches: 0, change: 2, inc: true, crochet: false))
        XCTAssertNil(ShapingMath.even(stitches: 4, change: 5, inc: true, crochet: false))
        XCTAssertNil(ShapingMath.even(stitches: 4, change: 5, inc: true, crochet: true))
    }
    func testSpreadAndTimes() {
        XCTAssertEqual(ShapingMath.spread(times: 8, overRows: 50), .init(firstEvery: 6, firstTimes: 6, thenEvery: 7, thenTimes: 2))
        XCTAssertEqual(ShapingMath.spread(times: 5, overRows: 30), .init(firstEvery: 6, firstTimes: 5, thenEvery: 7, thenTimes: 0))
        XCTAssertNil(ShapingMath.spread(times: 9, overRows: 8))
        XCTAssertEqual(ShapingMath.timesNeeded(from: 84, to: 64, per: 2), 10)
        XCTAssertEqual(ShapingMath.timesNeeded(from: 60, to: 72, per: 2), 6)
        XCTAssertNil(ShapingMath.timesNeeded(from: 84, to: 63, per: 2))
    }
    func testPlanRowsAndLiveCount() {
        let plan = ShapingPlan(start: 84, steps: [
            ShapeStep(id: "a", kind: "every", dir: "dec", row: 6, count: 2, every: 6, times: 10),
            ShapeStep(id: "b", kind: "even", dir: "inc", row: 64, count: 8),
        ])
        let rows = ShapingMath.rows(plan, crochet: false)
        XCTAssertEqual(rows.count, 11)
        XCTAssertEqual(rows.map(\.row), [6, 12, 18, 24, 30, 36, 42, 48, 54, 60, 64])
        XCTAssertEqual(ShapingMath.stitches(plan, crochet: false, completedRows: 0), 84)
        XCTAssertEqual(ShapingMath.stitches(plan, crochet: false, completedRows: 5), 84)
        XCTAssertEqual(ShapingMath.stitches(plan, crochet: false, completedRows: 6), 82)
        XCTAssertEqual(ShapingMath.stitches(plan, crochet: false, completedRows: 42), 70)
        XCTAssertEqual(ShapingMath.next(plan, crochet: false, completedRows: 42)?.row, 48)
        XCTAssertEqual(ShapingMath.next(plan, crochet: false, completedRows: 42)?.after, 68)
        XCTAssertEqual(ShapingMath.finalStitches(plan, crochet: false), 72)
        XCTAssertEqual(rows.last?.text, "(K7, M1) × 8, K8 (72 sts)")
        XCTAssertNil(ShapingMath.next(plan, crochet: false, completedRows: 64))
    }
    func testDecreaseNeverGoesNegative() {
        let plan = ShapingPlan(start: 3, steps: [ShapeStep(kind: "every", dir: "dec", row: 1, count: 2, every: 1, times: 5)])
        XCTAssertEqual(ShapingMath.finalStitches(plan, crochet: false), 0)
    }
}

final class GaugeMathTests: XCTestCase {
    var g: GaugeInfo {
        var g = GaugeInfo(); g.per = 4; g.patSts = 22; g.patRows = 30
        g.swSts = 21; g.swW = 4; g.swRows = 30; g.swH = 4.2
        return g
    }
    func testConversions() throws {
        XCTAssertEqual(GaugeMath.convertSts(110, g), 105)
        XCTAssertEqual(GaugeMath.convertRows(60, g), 57)
        XCTAssertEqual(try XCTUnwrap(GaugeMath.widthDiffPercent(g)), 4.7619, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(GaugeMath.sizeAtMyGauge(sts: 105, g)), 20, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(GaugeMath.myOverPer(g).sts), 21, accuracy: 0.0001)
        XCTAssertNil(GaugeMath.convertSts(110, GaugeInfo()), "nothing entered, nothing claimed")
    }
    func testYarnFromPatternWithShortfall() {
        var x = g; x.patYardage = 1200; x.skeinLen = 220; x.skeinGrams = 100; x.skeins = 5; x.margin = 10
        let y = GaugeMath.yarn(x)
        XCTAssertEqual(y.needLen ?? 0, 1200, accuracy: 0.01)   // 1200 × (37.5 / 41.25) × 1.1
        XCTAssertEqual(y.needSkeins, 6)
        XCTAssertEqual(y.shortSkeins, 1)
        x.skeins = 6
        XCTAssertEqual(GaugeMath.yarn(x).shortSkeins, 0)
    }
    func testYarnFromSwatchWeight() {
        var x = g; x.swGrams = 10; x.width = 20; x.length = 25; x.skeinGrams = 100; x.skeinLen = 220; x.margin = 10
        let y = GaugeMath.yarn(x)
        XCTAssertEqual(y.needGrams ?? 0, 10 / 16.8 * 500 * 1.1, accuracy: 0.01)
        XCTAssertEqual(y.needSkeins, 4)
        XCTAssertNil(y.shortSkeins, "no stash entered, no warning")
    }
}

final class EyesFreeTests: XCTestCase {
    func step(_ p: Project) -> (Project, Project) {
        var a = p; Engine.changeRows(&a, 1, locked: false, pro: false); return (p, a)
    }
    func testMilestones() {
        var p = Project(); p.rows = 4
        var (b, a) = step(p); XCTAssertEqual(EyesFree.milestone(before: b, after: a), .five)
        p.rows = 5; (b, a) = step(p); XCTAssertEqual(EyesFree.milestone(before: b, after: a), .none)
        p.rows = 9; (b, a) = step(p); XCTAssertEqual(EyesFree.milestone(before: b, after: a), .ten)
        p.rows = 8; p.counters = [ExtraCounter(id: "c", name: "Lace", value: 8, linked: true, resetAt: 8)]
        (b, a) = step(p); XCTAssertEqual(EyesFree.milestone(before: b, after: a), .repeatDone)
        XCTAssertEqual(EyesFree.phrase(a, .repeatDone), "Row 9. Repeat 1 done")
        var down = p; Engine.changeRows(&down, -1, locked: false, pro: false)
        XCTAssertEqual(EyesFree.milestone(before: p, after: down), .none)
    }
    func testRepeatBeatsTen() {
        var p = Project(); p.rows = 9; p.counters = [ExtraCounter(id: "c", value: 5, linked: true, resetAt: 5)]
        let (b, a) = step(p); XCTAssertEqual(EyesFree.milestone(before: b, after: a), .repeatDone)
    }
}

final class JournalMathTests: XCTestCase {
    let t0 = 1_790_000_000_000.0   // 2026-09-21 14:13 UTC
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    func testSessionsSplitOnGaps() {
        let log = [
            LogEntry(t: t0, m: "Row 0 → 1", r: 1),
            LogEntry(t: t0 + 600_000, m: "Row 1 → 2", r: 2),
            LogEntry(t: t0 + 700_000, m: "Timer started", r: 2),
            LogEntry(t: t0 + 7_200_000, m: "Row 2 → 3", r: 3),
            LogEntry(t: t0 + 7_300_000, m: "Undo: row 3 → 2", r: 2),
        ]
        let s = JournalMath.sessions(log)
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s[0].rows, 2); XCTAssertEqual(s[0].end - s[0].start, 600_000)
        XCTAssertEqual(s[1].rows, 1)
    }
    func testPace() throws {
        var p = Project(); p.rows = 3; p.target = 10
        p.log = [LogEntry(t: t0, m: "Row 0 → 1", r: 1), LogEntry(t: t0 + 60_000, m: "Row 1 → 2", r: 2),
                 LogEntry(t: t0 + 86_400_000, m: "Row 2 → 3", r: 3)]
        let pace = JournalMath.pace(p, calendar: utc)
        XCTAssertEqual(pace.sessions, 2); XCTAssertEqual(pace.activeDays, 2)
        XCTAssertEqual(try XCTUnwrap(pace.rowsPerSession), 1.5, accuracy: 0.0001)
        XCTAssertEqual(pace.sessionsLeft, 5)
        XCTAssertNil(pace.minutesPerRow, "no timer, no claim")
        p.timer.totalMs = 30 * 60_000
        XCTAssertEqual(try XCTUnwrap(JournalMath.pace(p, calendar: utc).minutesPerRow), 10, accuracy: 0.0001)
    }
    func testTimelineNewestFirst() {
        var p = Project(name: "Hat"); p.createdAt = t0 - 1000
        p.log = [LogEntry(t: t0, m: "Row 0 → 1", r: 1)]
        p.journal = [JournalEntry(id: "n", t: t0 + 5000, kind: "note", text: "Hi")]
        p.finishedAt = t0 + 9000
        XCTAssertEqual(JournalMath.timeline(p).map(\.kind), [.finished, .note, .session, .started])
    }
}

final class NewBackupKeysTests: XCTestCase {
    func testRoundTrip() throws {
        var s = AppState(); s.settings.speakCount = true
        var p = Project(name: "Sleeve")
        p.shaping = ShapingPlan(start: 84, steps: [ShapeStep(id: "a", kind: "every", dir: "dec", row: 6, count: 2, every: 6, times: 10)])
        var g = GaugeInfo(); g.unit = "cm"; g.per = 10; g.patSts = 22; g.skeins = 3; p.gauge = g
        p.journal = [JournalEntry(id: "j", t: 1, kind: "photo")]
        p.finishedAt = 123
        s.projects = [p]
        let d = try JSONEncoder().encode(BackupFile(state: s, files: [:], exportedAt: "x"))
        let back = try Backup.parse(d)
        XCTAssertEqual(back.state.projects[0].shaping, p.shaping)
        XCTAssertEqual(back.state.projects[0].gauge, p.gauge)
        XCTAssertEqual(back.state.projects[0].journal, p.journal)
        XCTAssertEqual(back.state.projects[0].finishedAt, 123)
        XCTAssertTrue(back.state.settings.speakCount)
        XCTAssertTrue(back.state.projects[0].extras.isEmpty, "new keys are known, not carried as extras")
    }
    func testLenientDecode() throws {
        let json = #"{"start":"40","steps":[{"kind":"weird","dir":"inc","row":0,"count":-3,"every":0,"times":0}]}"#
        let plan = try JSONDecoder().decode(ShapingPlan.self, from: Data(json.utf8))
        XCTAssertEqual(plan.start, 40)
        XCTAssertEqual(plan.steps[0].kind, "every"); XCTAssertEqual(plan.steps[0].row, 1); XCTAssertEqual(plan.steps[0].count, 1)
        XCTAssertEqual(JournalEntry.fileKey(project: "p", entry: "e"), "jphoto:p.e")
    }
}
