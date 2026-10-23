#if DEBUG
import UIKit

/// DEBUG-only demo data for CI simulator screenshots: launch with `-rowbinDemo <shaping|gauge|eyesfree|journal|counter|pattern|markup|settings|voice|dusk|pro>`.
/// Never compiled into TestFlight/App Store (Release) builds.
enum Demo {
    static let screen: String? = {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-rowbinDemo"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }()
    static var active: Bool { screen != nil }
    static let theme: String? = {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-rowbinTheme"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }()

    static func state() -> AppState {
        var s = AppState()
        s.settings.theme = theme ?? (screen == "dusk" ? "dusk" : "calm")
        s.settings.tipsSeen = true
        var p = Project(name: "Seed-stitch shawl", craft: "knit")
        p.rows = 42; p.target = 120
        p.counters = [ExtraCounter(id: "c1", name: "Lace repeat", resetAt: 8)]
        p.counters[0].value = 2; p.counters[0].repeats = 5
        var pt = PatternInfo(name: "shawl-chart.pdf", type: "pdf")
        pt.page = 0; pt.rel = 0.42; pt.zoom = 1
        pt.marks = [
            Mark(id: "d1", page: 0, tool: "hl", color: "#81C784", w: 0.025, pts: [0.12, 0.3, 0.5, 0.3, 0.88, 0.3]),
            Mark(id: "d2", page: 0, tool: "pen", color: "#B5523B", w: 0.0045, pts: [0.15, 0.55, 0.25, 0.5, 0.35, 0.56, 0.45, 0.5]),
            Mark(id: "d3", page: 0, tool: "pen", color: "#2F6690", w: 0.009, pts: [0.7, 0.62, 0.78, 0.7, 0.86, 0.62]),
        ]
        p.pattern = pt
        if ["shaping", "eyesfree"].contains(screen ?? "") {
            p.name = "Raglan sleeve"
            p.shaping = ShapingPlan(start: 84, steps: [
                ShapeStep(id: "s1", kind: "every", dir: "dec", row: 6, count: 2, every: 6, times: 10),
                ShapeStep(id: "s2", kind: "even", dir: "inc", row: 64, count: 8),
            ])
            p.target = 80
        }
        var g = GaugeInfo(); g.unit = "in"; g.per = 4; g.patSts = 22; g.patRows = 30
        g.swSts = 21; g.swW = 4; g.swRows = 30; g.swH = 4.2; g.patYardage = 1200
        g.skeinLen = 220; g.skeinGrams = 100; g.skeins = 5; g.margin = 10
        p.gauge = g
        // A few days of row history so the journal and pace stats have something to show.
        let day = 86_400_000.0, now = nowMs()
        p.createdAt = now - 6 * day
        var logs: [LogEntry] = [LogEntry(t: p.createdAt, m: "Project created", r: 0)]
        var row = 0
        for (d, n) in [(6.0, 9), (5.0, 7), (3.0, 12), (1.0, 8), (0.1, 6)] {
            let t0 = now - d * day
            for k in 0..<n { logs.append(LogEntry(t: t0 + Double(k) * 120_000, m: "Row \(row) → \(row + 1)", r: row + 1)); row += 1 }
        }
        p.log = logs; p.rows = row
        p.journal = [
            JournalEntry(id: "j1", t: now - 5 * day + 900_000, kind: "note", text: "Swatched and washed. Going up a needle size."),
            JournalEntry(id: "j2", t: now - 1 * day + 1_200_000, kind: "photo"),
        ]
        try? SharedStore.putFile(JournalEntry.fileKey(project: p.id, entry: "j2"), progressPhoto())
        s.projects = [p]; s.settings.lastProjectId = p.id
        try? SharedStore.putFile("pattern:\(p.id)", chartPDF())
        return s
    }

    /// A drawn "knitted fabric" image used as a demo progress photo.
    static func progressPhoto() -> Data {
        let size = CGSize(width: 900, height: 640)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(red: 0.84, green: 0.78, blue: 0.70, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let colors = [UIColor(red: 0.71, green: 0.32, blue: 0.23, alpha: 1), UIColor(red: 0.80, green: 0.47, blue: 0.36, alpha: 1)]
            for r in 0..<20 {
                colors[(r / 4) % 2].setFill()
                for c in 0..<30 {
                    let x = CGFloat(c) * 30 + 2, y = CGFloat(r) * 32 + 2
                    UIBezierPath(ovalIn: CGRect(x: x, y: y, width: 13, height: 28)).fill()
                    UIBezierPath(ovalIn: CGRect(x: x + 13, y: y, width: 13, height: 28)).fill()
                }
            }
        }
        return img.jpegData(compressionQuality: 0.85) ?? Data()
    }

    /// A simple knitting-chart-like PDF page (grid with row numbers) drawn in code.
    static func chartPDF() -> Data {
        let r = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        return r.pdfData { ctx in
            ctx.beginPage()
            let title = "Seed-stitch shawl, chart A" as NSString
            title.draw(at: CGPoint(x: 60, y: 50), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 22)])
            let cell: CGFloat = 22, x0: CGFloat = 70, y0: CGFloat = 110, cols = 20, rows = 26
            UIColor.darkGray.setStroke()
            for rI in 0...rows { let p = UIBezierPath(); p.move(to: CGPoint(x: x0, y: y0 + CGFloat(rI) * cell)); p.addLine(to: CGPoint(x: x0 + CGFloat(cols) * cell, y: y0 + CGFloat(rI) * cell)); p.lineWidth = 0.6; p.stroke() }
            for c in 0...cols { let p = UIBezierPath(); p.move(to: CGPoint(x: x0 + CGFloat(c) * cell, y: y0)); p.addLine(to: CGPoint(x: x0 + CGFloat(c) * cell, y: y0 + CGFloat(rows) * cell)); p.lineWidth = 0.6; p.stroke() }
            for rI in 0..<rows {
                ("\(rows - rI)" as NSString).draw(at: CGPoint(x: x0 + CGFloat(cols) * cell + 8, y: y0 + CGFloat(rI) * cell + 4), withAttributes: [.font: UIFont.systemFont(ofSize: 11)])
                for c in 0..<cols where (rI + c) % 2 == 0 {
                    UIColor.black.setFill()
                    UIBezierPath(ovalIn: CGRect(x: x0 + CGFloat(c) * cell + 8, y: y0 + CGFloat(rI) * cell + 8, width: 6, height: 6)).fill()
                }
            }
            ("●  purl     ▢  knit" as NSString).draw(at: CGPoint(x: 70, y: 700), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
    }
}
#endif
