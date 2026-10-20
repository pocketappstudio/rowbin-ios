import XCTest
@testable import Rowbin

final class EngineTests: XCTestCase {
    func testIncrementDecrementNeverBelowZero() {
        var p = Project(name: "T")
        XCTAssertTrue(Engine.changeRows(&p, 1, locked: false, pro: false).changed)
        XCTAssertEqual(p.rows, 1)
        Engine.changeRows(&p, -1, locked: false, pro: false)
        let r = Engine.changeRows(&p, -1, locked: false, pro: false)
        XCTAssertEqual(p.rows, 0); XCTAssertFalse(r.changed); XCTAssertEqual(r.feedback, .soft)
        XCTAssertEqual(p.log.last?.m, "Row 1 → 0")
    }
    func testLockBlocks() {
        var p = Project()
        let r = Engine.changeRows(&p, 1, locked: true, pro: false)
        XCTAssertTrue(r.blockedByLock); XCTAssertEqual(p.rows, 0)
        p.counters = [ExtraCounter(id: "c")]
        XCTAssertFalse(Engine.changeCounter(&p, id: "c", 1, locked: true))
    }
    func testLinkedRepeatRollsOverAndBack() {
        var p = Project()
        p.counters = [ExtraCounter(id: "r", name: "Repeat", resetAt: 8)]
        for _ in 0..<9 { Engine.changeRows(&p, 1, locked: false, pro: false) }
        XCTAssertEqual(p.counters[0].value, 1); XCTAssertEqual(p.counters[0].repeats, 1)
        Engine.changeRows(&p, -1, locked: false, pro: false)
        XCTAssertEqual(p.counters[0].value, 8); XCTAssertEqual(p.counters[0].repeats, 0)
    }
    func testUnlinkedCounterDoesNotMove() {
        var p = Project()
        p.counters = [ExtraCounter(id: "m", linked: false)]
        Engine.changeRows(&p, 1, locked: false, pro: false)
        XCTAssertEqual(p.counters[0].value, 0)
        Engine.changeCounter(&p, id: "m", 1, locked: false)
        XCTAssertEqual(p.counters[0].value, 1)
        XCTAssertEqual(p.log.last?.m, "Counter: 0 → 1")
    }
    func testUndoRestoresRowsAndCounters() {
        var p = Project()
        p.counters = [ExtraCounter(id: "r", resetAt: 2)]
        Engine.changeRows(&p, 1, locked: false, pro: false)
        Engine.changeRows(&p, 1, locked: false, pro: false)
        Engine.changeRows(&p, 1, locked: false, pro: false)
        XCTAssertEqual(p.counters[0].repeats, 1)
        XCTAssertTrue(Engine.undo(&p))
        XCTAssertEqual(p.rows, 2); XCTAssertEqual(p.counters[0].value, 2); XCTAssertEqual(p.counters[0].repeats, 0)
        XCTAssertEqual(p.log.last?.m, "Undo: row 3 → 2")
        while Engine.undo(&p) {}
        XCTAssertEqual(p.rows, 0); XCTAssertFalse(Engine.undo(&p))
    }
    func testCaps() {
        var p = Project()
        for _ in 0..<700 { Engine.changeRows(&p, 1, locked: false, pro: false) }
        XCTAssertEqual(p.undo.count, Engine.undoCap); XCTAssertEqual(p.log.count, Engine.logCap)
    }
    func testResetIsUndoable() {
        var p = Project(); p.counters = [ExtraCounter(id: "a"), ExtraCounter(id: "b", value: 4, linked: false)]
        for _ in 0..<5 { Engine.changeRows(&p, 1, locked: false, pro: false) }
        Engine.reset(&p)
        XCTAssertEqual(p.rows, 0); XCTAssertEqual(p.counters[0].value, 0); XCTAssertEqual(p.counters[1].value, 4)
        Engine.undo(&p); XCTAssertEqual(p.rows, 5); XCTAssertEqual(p.counters[0].value, 5)
    }
    func testTargetReached() {
        var p = Project(); p.target = 2
        XCTAssertFalse(Engine.changeRows(&p, 1, locked: false, pro: false).reachedTarget)
        let r = Engine.changeRows(&p, 1, locked: false, pro: false)
        XCTAssertTrue(r.reachedTarget); XCTAssertEqual(r.feedback, .strong)
        XCTAssertEqual(Engine.targetLine(p), "of 2 · 100%")
    }
    func testLegacyRemindersInSavedDataLoadWithoutCrash() throws {
        let json = #"{"v":1,"settings":{},"projects":[{"id":"p1","name":"Old","rows":7,"reminders":[{"id":"r1","text":"Decrease","every":6,"start":6},{"bad":true}],"counters":[{"id":"c1","name":"Repeat","value":7,"resetAt":8}]}]}"#
        let s = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))
        var p = try XCTUnwrap(s.projects.first)
        XCTAssertEqual(p.rows, 7)
        let r = Engine.changeRows(&p, 1, locked: false, pro: true)
        XCTAssertTrue(r.changed); XCTAssertEqual(p.counters[0].value, 8)
        let out = String(decoding: try JSONEncoder().encode(p), as: UTF8.self)
        XCTAssertFalse(out.contains("reminders"))
    }
    func testTimer() {
        var p = Project()
        Engine.timerToggle(&p, now: 1_000)
        XCTAssertEqual(Engine.timerElapsed(p, now: 4_000), 3_000)
        Engine.timerToggle(&p, now: 61_000)
        XCTAssertEqual(p.timer.totalMs, 60_000); XCTAssertNil(p.timer.runningSince); XCTAssertEqual(p.timer.sessions, [[1_000, 61_000]])
        Engine.timerSet(&p, hours: 1, minutes: 75)
        XCTAssertEqual(p.timer.totalMs, 3_600_000 + 59 * 60_000)
        XCTAssertEqual(fmtDur(3_723_000), "1:02:03")
    }
    func testFreeLimits() {
        XCTAssertTrue(Engine.canAddProject(count: 1, pro: false))
        XCTAssertFalse(Engine.canAddProject(count: 2, pro: false))
        XCTAssertTrue(Engine.canAddProject(count: 50, pro: true))
        var p = Project(); XCTAssertTrue(Engine.canAddCounter(p, pro: false))
        p.counters = [ExtraCounter()]; XCTAssertFalse(Engine.canAddCounter(p, pro: false)); XCTAssertTrue(Engine.canAddCounter(p, pro: true))
        var s = Settings(); s.theme = "night"
        XCTAssertEqual(Engine.effectiveTheme(s, pro: false), "oat"); XCTAssertEqual(Engine.effectiveTheme(s, pro: true), "night")
    }
    func testEnsureProject() {
        var s = AppState()
        let id = Engine.ensureProject(&s)
        XCTAssertEqual(s.projects.count, 1); XCTAssertEqual(s.projects[0].name, "My first project"); XCTAssertEqual(s.settings.lastProjectId, id)
        XCTAssertEqual(Engine.ensureProject(&s), id)
    }
}

final class BackupTests: XCTestCase {
    /// A backup exactly as the web app writes it (including web-only keys and the license, which must be ignored).
    let webJSON = """
    {"app":"rowbin","schema":1,"exportedAt":"2026-10-12T15:04:05.123Z","state":{"v":1,
     "settings":{"theme":"sage","haptics":false,"tapAnywhere":true,"locked":false,"keepAwake":true,"tipsSeen":false,"installDismissed":true,
       "license":{"ok":true,"key":"ABCD","source":"gumroad"},"lastBackup":null,"lastProjectId":"p1","persisted":true,"createdAt":1760000000000,"deviceId":"x"},
     "projects":[{"id":"p1","name":"Socks","craft":"crochet","rows":"12","target":40,"notes":"4mm hook","hasPhoto":true,
       "pattern":{"name":"socks.pdf","type":"pdf","page":2,"rel":0.5,"size":0.04,"zoom":1.5,"follow":false},
       "counters":[{"id":"c1","name":"Repeat","value":3,"linked":true,"resetAt":8,"repeats":1,"repeatTarget":39}],
       "reminders":[{"id":"r1","text":"Decrease","every":6,"start":18}],
       "undo":[{"rows":11,"c":[["c1",2,1]]}],
       "log":[{"t":1760000000000,"m":"Row 11 → 12","r":12}],
       "timer":{"totalMs":5000,"runningSince":null,"sessions":[[1,2]]},"createdAt":1760000000000,"updatedAt":1760000001000}]},
     "files":{"photo:p1":"data:image/jpeg;base64,/9j/AA=="}}
    """

    func testDecodesWebBackup() throws {
        let b = try Backup.parse(Data(webJSON.utf8))
        XCTAssertEqual(b.state.settings.theme, "sage"); XCTAssertFalse(b.state.settings.haptics); XCTAssertTrue(b.state.settings.tapAnywhere)
        let p = try XCTUnwrap(b.state.projects.first)
        XCTAssertEqual(p.rows, 12); XCTAssertEqual(p.craft, "crochet"); XCTAssertEqual(p.target, 40)
        XCTAssertEqual(p.pattern?.page, 2); XCTAssertEqual(p.pattern?.follow, false)
        XCTAssertEqual(p.counters.first?.resetAt, 8); XCTAssertEqual(p.counters.first?.repeatTarget, 39)
        XCTAssertEqual(p.undo.first?.c.first, UndoSnap.Entry(id: "c1", value: 2, repeats: 1))
        XCTAssertEqual(p.timer.sessions, [[1, 2]])
        XCTAssertEqual(Backup.decodeDataURL(b.files["photo:p1"]!), Data([0xFF, 0xD8, 0xFF, 0x00]))
        var q = p; Engine.undo(&q); XCTAssertEqual(q.rows, 11); XCTAssertEqual(q.counters[0].value, 2)
    }
    func testRoundTripKeepsWebShape() throws {
        let b = try Backup.parse(Data(webJSON.utf8))
        let out = try JSONEncoder().encode(BackupFile(state: b.state, files: b.files, exportedAt: Backup.iso()))
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: out) as? [String: Any])
        XCTAssertEqual(obj["app"] as? String, "rowbin")
        let state = try XCTUnwrap(obj["state"] as? [String: Any])
        let settings = try XCTUnwrap(state["settings"] as? [String: Any])
        XCTAssertNil(settings["license"], "Pro must never travel in a backup")
        let proj = try XCTUnwrap((state["projects"] as? [[String: Any]])?.first)
        let undo = try XCTUnwrap((proj["undo"] as? [[String: Any]])?.first)
        let c = try XCTUnwrap((undo["c"] as? [[Any]])?.first)
        XCTAssertEqual(c[0] as? String, "c1"); XCTAssertEqual(c[1] as? Int, 2)
        XCTAssertEqual(try Backup.parse(out).state, b.state)
    }
    func testRejectsNonRowbin() {
        XCTAssertThrowsError(try Backup.parse(Data(#"{"app":"other","state":{}}"#.utf8)))
        XCTAssertThrowsError(try Backup.parse(Data("not json".utf8)))
    }
    func testMissingFieldsGetDefaults() throws {
        let s = try JSONDecoder().decode(AppState.self, from: Data(#"{"projects":[{"name":"Hat"}]}"#.utf8))
        XCTAssertEqual(s.projects[0].craft, "knit"); XCTAssertEqual(s.projects[0].rows, 0); XCTAssertTrue(s.settings.haptics)
        XCTAssertFalse(s.projects[0].id.isEmpty)
    }
    func testSharedStoreRoundTrip() {
        var s = AppState(); _ = Engine.ensureProject(&s); s.projects[0].rows = 7
        XCTAssertTrue(SharedStore.save(s))
        XCTAssertEqual(SharedStore.load().projects.first?.rows, 7)
        SharedStore.mutate { st in Engine.changeRows(&st.projects[0], 1, locked: false, pro: false) }
        XCTAssertEqual(SharedStore.load().projects.first?.rows, 8)
    }
    func testFileKeysMapping() throws {
        try SharedStore.putFile("pattern:abc", Data([1, 2]))
        XCTAssertTrue(SharedStore.fileKeys().contains("pattern:abc"))
        XCTAssertEqual(SharedStore.getFile("pattern:abc"), Data([1, 2]))
        SharedStore.deleteFile("pattern:abc")
        XCTAssertFalse(SharedStore.fileKeys().contains("pattern:abc"))
    }
}
