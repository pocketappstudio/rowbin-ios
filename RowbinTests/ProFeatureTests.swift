import XCTest
@testable import Rowbin

final class VoiceCommandTests: XCTestCase {
    func testParsesCommands() {
        XCTAssertEqual(VoiceCommands.parse("next"), [.next])
        XCTAssertEqual(VoiceCommands.parse("Plus! add"), [.next, .next])
        XCTAssertEqual(VoiceCommands.parse("next row"), [.next])
        XCTAssertEqual(VoiceCommands.parse("go back"), [.back])
        XCTAssertEqual(VoiceCommands.parse("minus back row"), [.back, .back])
        XCTAssertEqual(VoiceCommands.parse("undo"), [.undo])
        XCTAssertEqual(VoiceCommands.parse("next next stop"), [.stop])
        XCTAssertEqual(VoiceCommands.parse("the weather is nice"), [])
        XCTAssertEqual(VoiceCommands.parse("nest"), [.next])
        XCTAssertEqual(VoiceCommands.parse(String(repeating: "next ", count: 9)).count, VoiceCommands.maxPerUtterance)
    }
}

final class ThemeMotionTests: XCTestCase {
    func testCalmThemesAndReduceMotion() {
        XCTAssertEqual(RowbinTheme.by("calm").name, "Calm Linen"); XCTAssertTrue(RowbinTheme.by("calm").calm)
        XCTAssertEqual(RowbinTheme.by("dusk").name, "Calm Dusk (dark)"); XCTAssertTrue(RowbinTheme.by("dusk").isDark)
        var s = Settings()
        XCTAssertFalse(Engine.reduceMotion(s, pro: false, system: false))
        XCTAssertTrue(Engine.reduceMotion(s, pro: false, system: true), "iOS Reduce Motion applies to everyone")
        s.reduceMotion = true
        XCTAssertFalse(Engine.reduceMotion(s, pro: false, system: false), "the setting is Pro")
        XCTAssertTrue(Engine.reduceMotion(s, pro: true, system: false))
        s.reduceMotion = false; s.theme = "dusk"
        XCTAssertTrue(Engine.reduceMotion(s, pro: true, system: false), "Calm themes are always still")
        XCTAssertFalse(Engine.reduceMotion(s, pro: false, system: false), "without Pro the theme is Oatmeal")
    }
}

final class MarkupTests: XCTestCase {
    /// Backup as Android writes it, with marks, showMarks and keys this app doesn't know.
    let androidJSON = """
    {"app":"rowbin","schema":1,"exportedAt":"2026-10-19T15:00:00.000Z","futureTop":1,"state":{"v":1,
     "settings":{"theme":"calm","reduceMotion":true,"volumeKeys":true,"followSystemDark":false},
     "projects":[{"id":"p1","name":"Shawl","rows":4,"futureProjectKey":{"a":[1,"x",null]},
       "pattern":{"name":"shawl.pdf","type":"pdf","page":1,"rel":0.3,"size":0.04,"zoom":2,"follow":true,"showMarks":false,"futurePatternKey":"keep me",
         "marks":[{"id":"m1","page":0,"tool":"pen","color":"#2F6690","w":0.0045,"pts":[0.1,0.2,0.3,0.4,0.5,0.6]},
                  {"id":"m2","page":1,"tool":"hl","color":"#FFD54F","w":0.025,"pts":[0.1,0.5,0.9,0.5]},
                  {"id":"bad1","page":0,"tool":"pen","color":"red","w":9,"pts":[2,-1,0.5]},
                  {"id":"bad2","pts":[]}]}}]},
     "files":{}}
    """

    func testDecodesAndroidMarks() throws {
        let b = try Backup.parse(Data(androidJSON.utf8))
        XCTAssertEqual(b.state.settings.theme, "calm"); XCTAssertTrue(b.state.settings.reduceMotion)
        let pt = try XCTUnwrap(b.state.projects.first?.pattern)
        XCTAssertFalse(pt.showMarks)
        XCTAssertEqual(pt.marks.map(\.id), ["m1", "m2", "bad1"])
        XCTAssertEqual(pt.marks[0].pts, [0.1, 0.2, 0.3, 0.4, 0.5, 0.6]); XCTAssertEqual(pt.marks[1].tool, "hl")
        // Invalid values are clamped like Android: colour reset, width capped, points clamped and made even.
        XCTAssertEqual(pt.marks[2].color, "#B5523B"); XCTAssertEqual(pt.marks[2].w, 0.08); XCTAssertEqual(pt.marks[2].pts, [1, 0])
    }

    func testBackupRoundTripKeepsMarksAndUnknownKeys() throws {
        let b = try Backup.parse(Data(androidJSON.utf8))
        let out = try JSONEncoder().encode(BackupFile(state: b.state, files: b.files, exportedAt: Backup.iso()))
        let again = try Backup.parse(out)
        XCTAssertEqual(again.state, b.state)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: out) as? [String: Any])
        let state = try XCTUnwrap(obj["state"] as? [String: Any])
        let settings = try XCTUnwrap(state["settings"] as? [String: Any])
        XCTAssertEqual(settings["volumeKeys"] as? Bool, true); XCTAssertEqual(settings["reduceMotion"] as? Bool, true)
        let proj = try XCTUnwrap((state["projects"] as? [[String: Any]])?.first)
        XCTAssertNotNil(proj["futureProjectKey"])
        let pat = try XCTUnwrap(proj["pattern"] as? [String: Any])
        XCTAssertEqual(pat["futurePatternKey"] as? String, "keep me")
        XCTAssertEqual(pat["showMarks"] as? Bool, false)
        let marks = try XCTUnwrap(pat["marks"] as? [[String: Any]])
        XCTAssertEqual(marks.count, 3)
        XCTAssertEqual(marks[0]["id"] as? String, "m1"); XCTAssertEqual(marks[0]["page"] as? Int, 0)
        XCTAssertEqual(marks[0]["tool"] as? String, "pen"); XCTAssertEqual(marks[0]["color"] as? String, "#2F6690")
        XCTAssertEqual(marks[0]["pts"] as? [Double], [0.1, 0.2, 0.3, 0.4, 0.5, 0.6])
    }

    func testDefaultsAreNotWritten() throws {
        var pt = PatternInfo(name: "a.pdf", type: "pdf")
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(pt)) as? [String: Any])
        XCTAssertNil(obj["marks"]); XCTAssertNil(obj["showMarks"])
        pt.marks = [Mark(page: 0, tool: "pen", color: "#2E2A26", w: 0.0045, pts: [0.123456, 0.5, 0.2, 0.6])]
        obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(pt)) as? [String: Any])
        XCTAssertEqual(((obj["marks"] as? [[String: Any]])?.first?["pts"] as? [Double])?.first, 0.1235)
    }

    func testEraser() {
        let a = Mark(id: "a", page: 0, tool: "pen", color: "#2E2A26", w: 0.005, pts: [0.1, 0.1, 0.2, 0.2])
        let b = Mark(id: "b", page: 0, tool: "pen", color: "#2E2A26", w: 0.005, pts: [0.8, 0.8, 0.9, 0.9])
        let c = Mark(id: "c", page: 1, tool: "hl", color: "#FFD54F", w: 0.025, pts: [0.1, 0.1, 0.2, 0.2])
        XCTAssertEqual(MarkupMath.erase([a, b, c], page: 0, at: CGPoint(x: 0.1, y: 0.1), aspect: 1.4).map(\.id), ["b", "c"])
        XCTAssertEqual(MarkupMath.erase([a, b, c], page: 0, at: CGPoint(x: 0.5, y: 0.5), aspect: 1.4).count, 3)
    }
}
