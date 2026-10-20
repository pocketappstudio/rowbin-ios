import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Loads a project's pattern file (PDF or image) and renders pages on demand.
final class PatternDoc {
    let pdf: PDFDocument?
    let image: UIImage?
    let aspects: [CGFloat]           // height / width for each page
    private let cache = NSCache<NSString, UIImage>()

    init?(projectID: String, type: String) {
        guard let data = SharedStore.getFile("pattern:\(projectID)") else { return nil }
        cache.countLimit = 8
        if type == "image" {
            guard let img = UIImage(data: data), img.size.width > 0 else { return nil }
            image = img; pdf = nil; aspects = [img.size.height / img.size.width]
        } else {
            guard let doc = PDFDocument(data: data), doc.pageCount > 0 else { return nil }
            pdf = doc; image = nil
            aspects = (0..<doc.pageCount).map { i in
                guard let pg = doc.page(at: i) else { return 1.414 }
                let b = pg.bounds(for: .mediaBox)
                let rotated = abs(pg.rotation) % 180 == 90
                let w = rotated ? b.height : b.width, h = rotated ? b.width : b.height
                return w > 0 ? h / w : 1.414
            }
        }
    }
    var pageCount: Int { aspects.count }

    func render(_ i: Int, pixelWidth: CGFloat) -> UIImage? {
        if let image { return image }
        let key = "\(i)-\(Int(pixelWidth))" as NSString
        if let c = cache.object(forKey: key) { return c }
        guard let pg = pdf?.page(at: i) else { return nil }
        let img = pg.thumbnail(of: CGSize(width: pixelWidth, height: pixelWidth * aspects[i]), for: .mediaBox)
        cache.setObject(img, forKey: key)
        return img
    }
}

enum PatternImport {
    @MainActor
    static func importFile(_ url: URL, projectID: String, model: AppModel, done: @escaping (Bool) -> Void) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let raw = try? Data(contentsOf: url) else { model.showToast("Couldn't open that file. Is the phone low on storage?", seconds: 3.5); done(false); return }
        let isPdf = raw.starts(with: [0x25, 0x50, 0x44, 0x46]) || url.pathExtension.lowercased() == "pdf"
        let stored: Data? = isPdf ? raw : ImageTools.downscaledJPEG(raw, maxSide: 2400)
        guard let data = stored else { model.showToast("Couldn't open that file. Is the phone low on storage?", seconds: 3.5); done(false); return }
        do {
            try SharedStore.putFile("pattern:\(projectID)", data)
            let name = url.lastPathComponent.isEmpty ? "Pattern" : url.lastPathComponent
            model.update(projectID) { p in
                p.pattern = PatternInfo(name: name, type: isPdf ? "pdf" : "image")
                Engine.log(&p, "Pattern added: \(name)")
            }
            done(true)
        } catch {
            model.showToast("Couldn't open that file. Is the phone low on storage?", seconds: 3.5); done(false)
        }
    }
}

private struct ScrollYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct PatternViewer: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let projectID: String

    @State private var doc: PatternDoc?
    @State private var failed = false
    @State private var dragStartTop: CGFloat?
    @State private var liveTop: CGFloat?
    @State private var scrollY: CGFloat = 0
    @State private var viewport: CGSize = .zero
    @State private var showMenu = false
    @State private var replace = false
    @State private var confirmRemove = false
    @State private var scrollRequest = 0
    @StateObject private var voice = VoiceCounter()
    // Chart markup (Pro)
    @State private var markup = false
    @State private var tool = "pen"            // "pen" | "hl" | "erase"
    @State private var penColor = MarkupPalette.pen[0]
    @State private var hlColor = MarkupPalette.highlight[0]
    @State private var thick = false
    @State private var live: Mark?
    @State private var confirmClear = false
    @State private var confirmReplace = false

    private var project: Project? { model.state.project(projectID) }
    private var pt: PatternInfo { project?.pattern ?? PatternInfo(name: "Pattern", type: "pdf") }

    var body: some View {
        let t = model.theme
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Close pattern")
                Text(pt.name).font(.headline).lineLimit(1).frame(maxWidth: .infinity)
                Button { zoom(-0.25) } label: { Image(systemName: "minus.magnifyingglass").frame(width: 44, height: 44) }.accessibilityLabel("Zoom out")
                Button { zoom(0.25) } label: { Image(systemName: "plus.magnifyingglass").frame(width: 44, height: 44) }.accessibilityLabel("Zoom in")
                Button { showMenu = true } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }.accessibilityLabel("Pattern options")
            }
            .padding(.horizontal, 6)
            .background(t.card)

            GeometryReader { geo in
                content(width: geo.size.width * CGFloat(pt.zoom))
                    .onAppear { viewport = geo.size }
                    .onChange(of: geo.size) { _, s in viewport = s; scrollRequest += 1 }
            }

            VStack(spacing: 8) {
                VoiceStatus(voice: voice)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        VoiceChip(voice: voice)
                        Chip(on: markup, label: markup ? "✏️ Markup on" : "✏️ Markup", pro: true) {
                            if !model.isPro { model.openPro("Chart markup"); return }
                            markup.toggle()
                            if markup && !pt.showMarks { model.update(projectID) { $0.pattern?.showMarks = true } }
                        }
                        if !markup && !pt.marks.isEmpty {
                            Chip(on: !pt.showMarks, label: pt.showMarks ? "Hide markup" : "Show markup") {
                                model.update(projectID) { $0.pattern?.showMarks.toggle() }
                            }
                        }
                    }
                }
                if markup { markupTools }
            }
            .padding(.horizontal, 10).padding(.top, 8)
            .background(t.card)

            HStack(spacing: 8) {
                Button { moveLine(-1) } label: { Image(systemName: "arrowtriangle.up.fill").frame(width: 40, height: 60) }.buttonStyle(.bordered).accessibilityLabel("Move line up")
                Button { moveLine(1) } label: { Image(systemName: "arrowtriangle.down.fill").frame(width: 40, height: 60) }.buttonStyle(.bordered).accessibilityLabel("Move line down")
                Button { row(-1) } label: { Text("−").font(.largeTitle.bold()).frame(maxWidth: .infinity, minHeight: 60) }.buttonStyle(.bordered).accessibilityLabel("Subtract a row")
                    .frame(maxWidth: .infinity).layoutPriority(1)
                Text("\(project?.rows ?? 0)").font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6).frame(minWidth: 52)
                    .accessibilityLabel("Row \(project?.rows ?? 0)")
                Button { row(1) } label: { Text("+").font(.largeTitle.bold()).foregroundStyle(model.theme.onAccent).frame(maxWidth: .infinity, minHeight: 60) }.buttonStyle(.borderedProminent).accessibilityLabel("Add a row")
                    .frame(maxWidth: .infinity).layoutPriority(1)
            }
            .padding(10)
            .background(t.card)
            .disabled(model.state.settings.locked)
        }
        .background(t.background.ignoresSafeArea())
        .foregroundStyle(t.text)
        .tint(t.accent)
        .task {
            #if DEBUG
            if Demo.screen == "markup" { markup = true; tool = "hl" }
            #endif
            doc = PatternDoc(projectID: projectID, type: pt.type)
            failed = doc == nil
            scrollRequest += 1
        }
        .modifier(VoiceSession(voice: voice, projectID: projectID))
        .sheet(isPresented: $showMenu) { menu }
        .alert("Clear all markup?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { model.update(projectID) { $0.pattern?.marks = [] } }
        } message: { Text("This removes every mark you drew on this pattern. The pattern itself isn’t changed.") }
        .alert("Replace pattern file?", isPresented: $confirmReplace) {
            Button("Cancel", role: .cancel) {}
            Button("Choose file") { replace = true }
        } message: { Text("Your markup belongs to this file, so it will be removed when you choose a new one.") }
        .fileImporter(isPresented: $replace, allowedContentTypes: [.pdf, .image]) { result in
            if case .success(let url) = result {
                PatternImport.importFile(url, projectID: projectID, model: model) { ok in
                    if ok { doc = PatternDoc(projectID: projectID, type: pt.type); failed = doc == nil; scrollRequest += 1 }
                }
            }
        }
        .alert("Remove pattern?", isPresented: $confirmRemove) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                SharedStore.deleteFile("pattern:\(projectID)")
                model.update(projectID) { $0.pattern = nil }
                dismiss()
            }
        } message: { Text("The pattern file will be deleted from this project.") }
    }

    // MARK: geometry
    private func heights(_ w: CGFloat) -> [CGFloat] { (doc?.aspects ?? []).map { $0 * w } }
    private func offsets(_ w: CGFloat) -> [CGFloat] {
        var o: [CGFloat] = [], y: CGFloat = 0
        for h in heights(w) { o.append(y); y += h }
        return o
    }
    private func lineHeight(_ w: CGFloat) -> CGFloat { max(14, CGFloat(pt.size) * w) }
    private func storedTop(_ w: CGFloat) -> CGFloat {
        let hs = heights(w), os = offsets(w)
        guard !hs.isEmpty else { return 0 }
        let i = min(max(pt.page, 0), hs.count - 1)
        let total = hs.reduce(0, +)
        return min(max(os[i] + CGFloat(pt.rel) * hs[i], 0), max(0, total - lineHeight(w)))
    }
    private func store(top: CGFloat, w: CGFloat) {
        let hs = heights(w), os = offsets(w), lh = lineHeight(w)
        guard !hs.isEmpty else { return }
        let center = top + lh / 2
        for i in hs.indices where center < os[i] + hs[i] + 4 || i == hs.count - 1 {
            let rel = Double((top - os[i]) / hs[i])
            model.update(projectID) { p in p.pattern?.page = i; p.pattern?.rel = rel }
            break
        }
    }
    private func clampTop(_ v: CGFloat, w: CGFloat) -> CGFloat { min(max(v, 0), max(0, heights(w).reduce(0, +) - lineHeight(w))) }

    @ViewBuilder
    private func content(width w: CGFloat) -> some View {
        if failed {
            VStack(spacing: 6) { Text("Sorry, this pattern couldn’t be opened."); Muted("The file may be damaged or missing.") }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let doc {
            let hs = heights(w), total = hs.reduce(0, +), lh = lineHeight(w)
            let top = liveTop ?? storedTop(w)
            ScrollViewReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<doc.pageCount, id: \.self) { i in
                            PageImage(doc: doc, index: i, pixelWidth: min(w * min(displayScale, 2), 2200))
                                .frame(width: w, height: hs[i])
                                .overlay { MarksLayer(marks: pageMarks(i)).allowsHitTesting(false) }
                        }
                    }
                    .frame(width: w, height: total, alignment: .top)
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { loc in
                        guard !markup else { return }
                        let nt = clampTop(loc.y - lh / 2, w: w)
                        store(top: nt, w: w); model.haptic(.soft)
                    }
                    .gesture(markup ? drawGesture(w: w) : nil)
                    .overlay(alignment: .topLeading) {
                        highlighter(width: w, height: lh)
                            .id("hl")
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { v in
                                        if dragStartTop == nil { dragStartTop = top }
                                        liveTop = clampTop((dragStartTop ?? 0) + v.translation.height, w: w)
                                    }
                                    .onEnded { _ in
                                        if let lt = liveTop { store(top: lt, w: w) }
                                        liveTop = nil; dragStartTop = nil
                                    }
                            )
                            .padding(.top, top)
                            .allowsHitTesting(!markup)
                    }
                    .background(GeometryReader { g in Color.clear.preference(key: ScrollYKey.self, value: g.frame(in: .named("vscroll")).minY) })
                }
                .scrollDisabled(markup)
                .coordinateSpace(name: "vscroll")
                .onPreferenceChange(ScrollYKey.self) { scrollY = $0 }
                .onChange(of: scrollRequest) { _, _ in
                    DispatchQueue.main.async { proxy.scrollTo("hl", anchor: UnitPoint(x: 0.5, y: 0.35)) }
                }
            }
        } else {
            ProgressView("Opening pattern…").frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func highlighter(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .trailing) {
            Rectangle().fill(Color.yellow.opacity(0.32))
            Rectangle().stroke(Color.orange.opacity(0.7), lineWidth: 2)
            Image(systemName: "arrow.up.and.down").font(.caption.bold()).padding(6)
                .background(Circle().fill(Color.orange)).foregroundStyle(.white).padding(.trailing, 6)
        }
        .frame(width: width, height: height)
        .accessibilityElement()
        .accessibilityLabel("Row highlighter, drag to move")
        .accessibilityAdjustableAction { dir in moveLine(dir == .increment ? 1 : -1) }
    }

    // MARK: actions
    private func currentWidth() -> CGFloat { viewport.width * CGFloat(pt.zoom) }
    private func moveLine(_ dir: Int) {
        let w = currentWidth(), lh = lineHeight(w)
        let nt = clampTop(storedTop(w) + CGFloat(dir) * lh * 0.9, w: w)
        store(top: nt, w: w)
        let vis = nt + scrollY
        if vis > viewport.height * 0.7 || vis < viewport.height * 0.1 { withAnimation { scrollRequest += 1 } }
    }
    private func row(_ delta: Int) {
        let before = project?.rows ?? 0
        model.changeRows(projectID, delta)
        if (project?.rows ?? 0) != before && pt.follow { moveLine(delta) }
    }
    private func zoom(_ d: Double) {
        let z = min(3, max(1, ((pt.zoom + d) * 100).rounded() / 100))
        model.update(projectID) { $0.pattern?.zoom = z }
        scrollRequest += 1
    }

    private var menu: some View {
        NavigationStack {
            Form {
                Toggle(isOn: Binding(get: { pt.follow }, set: { v in model.update(projectID) { $0.pattern?.follow = v } })) {
                    VStack(alignment: .leading) { Text("Move line with each row"); Muted("Tapping + here also moves the highlighter down one line") }
                }
                Section("Highlighter thickness") {
                    HStack {
                        Button("Thinner") { resize(0.8) }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                        Button("Thicker") { resize(1.25) }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                    }
                }
                if !pt.marks.isEmpty {
                    Toggle(isOn: Binding(get: { pt.showMarks }, set: { v in model.update(projectID) { $0.pattern?.showMarks = v } })) { Text("Show markup") }
                }
                Muted("Tip: tap anywhere on the pattern to move the line there, or drag it by the ⇕ handle. Tap ✏️ Markup to draw on the pattern; tap Done to scroll again.")
                Section {
                    Button("Replace pattern file") { showMenu = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { if pt.marks.isEmpty { replace = true } else { confirmReplace = true } } }
                    Button("Remove pattern", role: .destructive) { showMenu = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { confirmRemove = true } }
                }
            }
            .navigationTitle("Pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showMenu = false } } }
        }
        .presentationDetents([.medium, .large])
    }
    // MARK: markup
    private func pageMarks(_ i: Int) -> [Mark] {
        guard pt.showMarks || markup else { return [] }
        return pt.marks.filter { $0.page == i } + [live].compactMap { $0 }.filter { $0.page == i }
    }
    private func pageAt(_ y: CGFloat, w: CGFloat) -> Int {
        let hs = heights(w), os = offsets(w)
        return hs.indices.first { y < os[$0] + hs[$0] } ?? max(0, hs.count - 1)
    }
    private func frac(_ p: CGPoint, page: Int, w: CGFloat) -> CGPoint {
        let hs = heights(w), os = offsets(w)
        return CGPoint(x: min(1, max(0, p.x / w)), y: min(1, max(0, (p.y - os[page]) / hs[page])))
    }
    private func drawGesture(w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                guard !heights(w).isEmpty else { return }
                if tool == "erase" { eraseAt(v.location, w: w); return }
                if live == nil {
                    let pg = pageAt(v.location.y, w: w), f = frac(v.location, page: pg, w: w)
                    let sw = tool == "hl" ? (thick ? 0.04 : 0.025) : (thick ? 0.009 : 0.0045)
                    live = Mark(page: pg, tool: tool, color: tool == "hl" ? hlColor : penColor, w: sw, pts: [f.x, f.y])
                    return
                }
                guard var m = live, m.pts.count < Mark.maxPoints * 2 else { return }
                let f = frac(v.location, page: m.page, w: w)
                let dx = (f.x - m.pts[m.pts.count - 2]) * w, dy = (f.y - m.pts[m.pts.count - 1]) * heights(w)[m.page]
                if dx * dx + dy * dy >= 4 { m.pts += [f.x, f.y]; live = m }
            }
            .onEnded { _ in
                if let m = live, m.pts.count >= 4 {
                    model.update(projectID) { p in
                        p.pattern?.marks.append(m)
                        if let n = p.pattern?.marks.count, n > PatternInfo.maxMarks { p.pattern?.marks.removeFirst(n - PatternInfo.maxMarks) }
                        p.pattern?.showMarks = true
                    }
                }
                live = nil
            }
    }
    private func eraseAt(_ p: CGPoint, w: CGFloat) {
        let pg = pageAt(p.y, w: w), f = frac(p, page: pg, w: w)
        let aspect = heights(w)[pg] / w
        let removed = MarkupMath.erase(pt.marks, page: pg, at: f, aspect: aspect)
        if removed.count != pt.marks.count { model.update(projectID) { $0.pattern?.marks = removed }; model.haptic(.soft) }
    }

    private var markupTools: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Chip(on: tool == "pen", label: "✒️ Pen") { tool = "pen" }
                Chip(on: tool == "hl", label: "🖍 Highlighter") { tool = "hl" }
                Chip(on: tool == "erase", label: "🧽 Eraser") { tool = "erase" }
            }
            HStack(spacing: 10) {
                let colors = tool == "hl" ? MarkupPalette.highlight : MarkupPalette.pen
                let sel = tool == "hl" ? hlColor : penColor
                ForEach(colors, id: \.self) { c in
                    Button { if tool == "hl" { hlColor = c } else { penColor = c } } label: {
                        Circle().fill(MarkupPalette.color(c).opacity(tool == "hl" ? 0.7 : 1)).frame(width: 34, height: 34)
                            .overlay(Circle().stroke(model.theme.text, lineWidth: sel == c && tool != "erase" ? 3 : 0))
                    }
                    .buttonStyle(.plain).disabled(tool == "erase").opacity(tool == "erase" ? 0.4 : 1)
                    .accessibilityLabel("Colour \((colors.firstIndex(of: c) ?? 0) + 1)").accessibilityAddTraits(sel == c ? .isSelected : [])
                }
                Spacer()
                Chip(on: !thick, label: "Thin") { thick = false }
                Chip(on: thick, label: "Thick") { thick = true }
            }
            HStack(spacing: 8) {
                Button { model.update(projectID) { _ = $0.pattern?.marks.popLast() }; model.haptic(.soft) } label: { Text("↶ Undo mark").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).disabled(pt.marks.isEmpty)
                Button { confirmClear = true } label: { Text("Clear").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).tint(RowbinTheme.danger).disabled(pt.marks.isEmpty)
                Button { markup = false } label: { Text("Done").foregroundStyle(model.theme.onAccent).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
            }
            Muted("Draw with one finger. Marks sit on top of your pattern; the pattern itself isn’t changed.")
        }
    }

    private func resize(_ f: Double) { model.update(projectID) { p in let s = p.pattern?.size ?? 0.035; p.pattern?.size = min(0.2, max(0.012, s * f)) } }
}

private struct PageImage: View {
    let doc: PatternDoc
    let index: Int
    let pixelWidth: CGFloat
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            Color.white
            if let image { Image(uiImage: image).resizable().interpolation(.high) }
            else { ProgressView() }
        }
        .task(id: pixelWidth) {
            let d = doc, i = index, pw = pixelWidth
            image = await Task.detached(priority: .userInitiated) { d.render(i, pixelWidth: pw) }.value
        }
        .onDisappear { image = nil }
        .accessibilityLabel("Pattern page \(index + 1)")
    }
}

/// Markup colours (same as Android): muted inks, and soft highlighter tints that still show on white paper.
enum MarkupPalette {
    static let pen = ["#B5523B", "#2F6690", "#4F7A5A", "#2E2A26"]
    static let highlight = ["#FFD54F", "#81C784", "#64B5F6", "#F48FB1"]
    static func color(_ hex: String) -> Color {
        guard Mark.isHex(hex), let v = UInt32(hex.dropFirst(), radix: 16) else { return Color(hex: 0xB5523B) }
        return Color(hex: v)
    }
}

/// Draws one page's marks. Positions are fractions of the page, so they stay put at every zoom level.
struct MarksLayer: View {
    let marks: [Mark]
    var body: some View {
        Canvas { ctx, size in
            for m in marks {
                let pts = stride(from: 0, to: m.pts.count - 1, by: 2).map { CGPoint(x: m.pts[$0] * size.width, y: m.pts[$0 + 1] * size.height) }
                guard let first = pts.first else { continue }
                let lw = max(1.5, m.w * size.width)
                let color = MarkupPalette.color(m.color).opacity(m.isHighlighter ? 0.38 : 0.95)
                if pts.count == 1 { ctx.fill(Path(ellipseIn: CGRect(x: first.x - lw / 2, y: first.y - lw / 2, width: lw, height: lw)), with: .color(color)); continue }
                var path = Path(); path.move(to: first)
                for i in 1..<pts.count { let a = pts[i - 1], b = pts[i]; path.addQuadCurve(to: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), control: a) }
                path.addLine(to: pts[pts.count - 1])
                ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: m.isHighlighter ? .butt : .round, lineJoin: .round))
            }
        }
    }
}
