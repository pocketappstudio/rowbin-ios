import SwiftUI
import PhotosUI

/// Project journal (free): an automatic timeline of rows, sessions, photos and notes, with pace stats and a
/// finish card made on this phone. Nothing leaves the phone unless you choose Share.
struct JournalView: View {
    @EnvironmentObject var model: AppModel
    let projectID: String
    @State private var photoItem: PhotosPickerItem?
    @State private var addNote = false
    @State private var noteText = ""
    @State private var card: UIImage?
    @State private var confirmSpec: ConfirmSpec?

    var p: Project { model.state.project(projectID) ?? Project() }

    var body: some View {
        let t = model.theme
        ScrollView {
            VStack(spacing: 14) {
                paceCard(t)
                finishCard(t)
                Card {
                    HStack {
                        Text("Timeline").font(.headline)
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) { Label("Photo", systemImage: "photo") }.buttonStyle(.bordered)
                        Button { noteText = ""; addNote = true } label: { Label("Note", systemImage: "square.and.pencil") }.buttonStyle(.bordered)
                    }
                    Muted("Rowbin adds your counting sessions here by itself. Add progress photos and notes whenever you like. They stay on this phone.")
                    ForEach(JournalMath.timeline(p)) { item in
                        TimelineRow(item: item, projectID: projectID) {
                            if let e = item.entryID {
                                confirmSpec = ConfirmSpec(title: "Delete this \(item.kind == .photo ? "photo" : "note")?", message: "It will be removed from the journal.", ok: "Delete") {
                                    model.removeJournalEntry(projectID, entry: e)
                                }
                            }
                        }
                        Divider()
                    }
                }
            }.padding(16)
        }
        .background(t.background.ignoresSafeArea())
        .foregroundStyle(t.text)
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { model.addJournalPhoto(projectID, data: data) }
                else { model.showToast("Couldn't save that photo.") }
                photoItem = nil
            }
        }
        .alert("Add a note", isPresented: $addNote) {
            TextField("e.g. Switched to the second skein", text: $noteText)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let s = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !s.isEmpty else { return }
                model.update(projectID) { $0.journal.append(JournalEntry(kind: "note", text: s)) }
            }
        }
        .confirm($confirmSpec)
        .onAppear {
            #if DEBUG
            if Demo.screen == "journal" { card = FinishCard.render(project: p, theme: model.theme) }
            #endif
        }
    }

    func paceCard(_ t: RowbinTheme) -> some View {
        let pace = JournalMath.pace(p)
        return Card {
            Text("Your pace").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                Stat(value: "\(pace.sessions)", label: pace.sessions == 1 ? "session" : "sessions")
                Stat(value: "\(pace.activeDays)", label: pace.activeDays == 1 ? "day knitting" : "days knitting")
                Stat(value: fmt(pace.rowsPerSession), label: "rows per session")
                Stat(value: fmt(pace.rowsPerDay), label: "rows per day knitting")
                if let m = pace.minutesPerRow { Stat(value: fmt(m), label: "minutes per row (timer)") }
                if let left = pace.sessionsLeft { Stat(value: "≈ \(left)", label: "more sessions to row \(p.target ?? 0)") }
            }
            Muted("Worked out from your row history: changes less than 30 minutes apart count as one session.")
        }
    }

    func finishCard(_ t: RowbinTheme) -> some View {
        Card {
            Text("Finish card").font(.headline)
            if let f = p.finishedAt {
                Text("Finished \(Date(timeIntervalSince1970: f / 1000).formatted(date: .long, time: .omitted)) 🎉")
            } else {
                Muted("When you’re done, mark the project finished and make a card to keep or share.")
            }
            HStack {
                Button(p.finishedAt == nil ? "Mark as finished" : "Not finished yet") {
                    model.update(projectID) { pr in
                        if pr.finishedAt == nil { pr.finishedAt = nowMs(); Engine.log(&pr, "Marked finished") }
                        else { pr.finishedAt = nil; Engine.log(&pr, "Marked not finished") }
                    }
                    if model.state.project(projectID)?.finishedAt != nil { model.haptic(.strong) }
                }.buttonStyle(.bordered)
                Button("Make card") { card = FinishCard.render(project: p, theme: model.theme) }.buttonStyle(.borderedProminent).foregroundStyle(t.onAccent)
            }
            if let card {
                Image(uiImage: card).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityLabel(FinishCard.summary(p))
                ShareLink(item: Image(uiImage: card), preview: SharePreview(p.name, image: Image(uiImage: card))) {
                    Label("Share card", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
            }
        }
    }
}

struct Stat: View {
    @EnvironmentObject var model: AppModel
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(label).font(.footnote).foregroundStyle(model.theme.muted)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TimelineRow: View {
    @EnvironmentObject var model: AppModel
    let item: JournalMath.Item
    let projectID: String
    let delete: () -> Void
    var icon: String {
        switch item.kind {
        case .started: return "flag"
        case .session: return "plus.circle"
        case .timer: return "timer"
        case .photo: return "photo"
        case .note: return "text.bubble"
        case .finished: return "star.fill"
        }
    }
    var body: some View {
        let t = model.theme
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(t.accent).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.body.weight(.semibold))
                if !item.detail.isEmpty { Text(item.detail).font(.callout) }
                Muted("\(fmtDay(item.t)), \(fmtClock(item.t))")
                if item.kind == .photo, let e = item.entryID, let img = ImageCache.shared.image(JournalEntry.fileKey(project: projectID, entry: e)) {
                    Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 220).clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Progress photo")
                }
            }
            Spacer(minLength: 0)
            if item.entryID != nil {
                Button(action: delete) { Image(systemName: "trash") }.buttonStyle(.borderless).foregroundStyle(t.muted)
                    .accessibilityLabel("Delete")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// The finish card, drawn by SwiftUI on this phone (ImageRenderer).
enum FinishCard {
    static func summary(_ p: Project) -> String {
        let pace = JournalMath.pace(p)
        var s = "\(p.name). \(plural(p.rows, "row")), \(plural(pace.sessions, "session")) over \(plural(pace.activeDays, "day"))."
        if p.timer.totalMs > 0 { s += " \(fmtDur(p.timer.totalMs)) on the timer." }
        return s
    }
    @MainActor static func render(project p: Project, theme t: RowbinTheme) -> UIImage? {
        let photo: UIImage? = p.journal.last(where: { $0.kind == "photo" }).flatMap { ImageCache.shared.image(JournalEntry.fileKey(project: p.id, entry: $0.id)) }
            ?? (p.hasPhoto ? ImageCache.shared.image("photo:\(p.id)") : nil)
        let r = ImageRenderer(content: FinishCardView(p: p, t: t, photo: photo))
        r.scale = 3
        return r.uiImage
    }
}

struct FinishCardView: View {
    let p: Project
    let t: RowbinTheme
    let photo: UIImage?
    var body: some View {
        let pace = JournalMath.pace(p)
        VStack(alignment: .leading, spacing: 14) {
            Text(p.finishedAt == nil ? "IN PROGRESS" : "FINISHED").font(.system(size: 13, weight: .heavy)).kerning(2).foregroundStyle(t.accent)
            Text(p.name).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(t.text).lineLimit(2)
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill().frame(width: 312, height: 220).clipped().clipShape(RoundedRectangle(cornerRadius: 16))
            }
            HStack(spacing: 18) {
                cell("\(p.rows)", p.isCrochet ? "rows/rounds" : "rows")
                cell("\(pace.sessions)", "sessions")
                cell("\(pace.activeDays)", "days")
                if p.timer.totalMs > 0 { cell(fmtHours(p.timer.totalMs), "hours") }
            }
            let start = Date(timeIntervalSince1970: p.createdAt / 1000).formatted(date: .abbreviated, time: .omitted)
            let end = p.finishedAt.map { Date(timeIntervalSince1970: $0 / 1000).formatted(date: .abbreviated, time: .omitted) }
            Text(end.map { "\(start) – \($0)" } ?? "Started \(start)").font(.system(size: 14)).foregroundStyle(t.muted)
            Spacer(minLength: 0)
            Text("Counted with Rowbin 🧶").font(.system(size: 13, weight: .semibold)).foregroundStyle(t.muted)
        }
        .padding(24)
        .frame(width: 360, height: photo == nil ? 340 : 560, alignment: .topLeading)
        .background(t.card)
        .environment(\.colorScheme, t.isDark ? .dark : .light)
    }
    func cell(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(t.text)
            Text(l).font(.system(size: 12)).foregroundStyle(t.muted)
        }
    }
    func fmtHours(_ ms: Double) -> String { (ms / 3_600_000).formatted(.number.precision(.fractionLength(0...1))) }
}
