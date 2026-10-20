#if DEBUG
import UIKit

/// DEBUG-only demo data for CI simulator screenshots: launch with `-rowbinDemo <counter|pattern|markup|settings|voice|dusk>`.
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
        s.projects = [p]; s.settings.lastProjectId = p.id
        try? SharedStore.putFile("pattern:\(p.id)", chartPDF())
        return s
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
