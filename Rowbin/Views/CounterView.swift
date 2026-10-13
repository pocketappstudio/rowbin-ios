import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct CounterView: View {
    @EnvironmentObject var model: AppModel
    let projectID: String
    @Environment(\.verticalSizeClass) private var vSize
    @FocusState private var keyFocus: Bool

    @State private var showMenu = false
    @State private var editProject = false
    @State private var newProject = false
    @State private var counterEdit: CounterEditTarget?
    @State private var addReminder = false
    @State private var editTimer = false
    @State private var showPattern = false
    @State private var importPattern = false
    @State private var photoItem: PhotosPickerItem?
    @State private var confirmSpec: ConfirmSpec?
    @State private var notes = ""
    @State private var notesSaved = false
    @State private var bump = 0

    var p: Project { model.state.project(projectID) ?? Project() }
    var locked: Bool { model.state.settings.locked }

    var body: some View {
        let t = model.theme
        Group {
            if model.state.project(projectID) == nil {
                Text("This project was deleted.").foregroundStyle(t.muted)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 14) {
                            if !model.state.settings.tipsSeen { TipsCard() }
                            if vSize == .compact {
                                HStack(alignment: .center, spacing: 16) { countArea.frame(maxWidth: .infinity); controls.frame(maxWidth: .infinity) }
                            } else {
                                countArea; controls
                            }
                            toolRow(proxy)
                            countersCard.id("counters")
                            remindersCard.id("reminders")
                            timerCard.id("timer")
                            notesCard.id("notes")
                            photoCard
                            historyCard.id("history")
                            HStack(spacing: 6) {
                                Button("Settings & backup") { model.path.append(.settings) }
                                Text("·")
                                Button("About & privacy") { model.path.append(.about) }
                            }.font(.footnote).padding(.vertical, 20)
                        }
                        .padding(16)
                    }
                }
            }
        }
        .background(t.background.ignoresSafeArea())
        .foregroundStyle(t.text)
        .navigationTitle(p.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button { editProject = true } label: { Text(p.name).font(.headline).foregroundStyle(t.text).lineLimit(1) }
                    .accessibilityHint("Edit project")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editProject = true } label: { Label("Edit name, craft, target", systemImage: "pencil") }
                    Button { startNewProject() } label: { Label("New project", systemImage: "plus") }
                    Button { confirmReset() } label: { Label("Reset row count to 0", systemImage: "arrow.counterclockwise") }
                    Button { model.path.append(.settings) } label: { Label("Settings & backup", systemImage: "gearshape") }
                    Button(role: .destructive) { confirmDelete() } label: { Label("Delete project", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Project options")
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($keyFocus)
        .onKeyPress(phases: [.down, .repeat]) { press in handleKey(press) }
        .onAppear {
            model.markOpened(projectID)
            notes = p.notes
            keyFocus = true
            Haptics.prepare()
            UIApplication.shared.isIdleTimerDisabled = model.state.settings.keepAwake
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: model.state.settings.keepAwake) { _, v in UIApplication.shared.isIdleTimerDisabled = v }
        .sheet(isPresented: $editProject) {
            ProjectForm(project: p) { v in
                model.update(projectID) { pr in
                    pr.name = v.name; pr.craft = v.craft; pr.target = v.target; pr.updatedAt = nowMs()
                    let r = max(0, v.rows ?? pr.rows)
                    if r != pr.rows { Engine.setRows(&pr, r, why: "Edited") }
                }
            }.environmentObject(model)
        }
        .sheet(isPresented: $newProject) {
            ProjectForm(project: nil) { v in
                if let id = model.newProject(name: v.name, craft: v.craft, target: v.target) { model.path = [.project(id)] }
            }.environmentObject(model)
        }
        .sheet(item: $counterEdit) { target in CounterSheet(projectID: projectID, counterID: target.counterID).environmentObject(model) }
        .sheet(isPresented: $addReminder) { ReminderSheet(projectID: projectID).environmentObject(model) }
        .sheet(isPresented: $editTimer) { TimerEditSheet(projectID: projectID).environmentObject(model) }
        .fullScreenCover(isPresented: $showPattern) { PatternViewer(projectID: projectID).environmentObject(model) }
        .fileImporter(isPresented: $importPattern, allowedContentTypes: [.pdf, .image]) { result in
            if case .success(let url) = result { PatternImport.importFile(url, projectID: projectID, model: model) { showPattern = $0 } }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { model.setPhoto(projectID, data: data) }
                else { model.showToast("Couldn't save that photo.") }
                photoItem = nil
            }
        }
        .confirm($confirmSpec)
    }

    // MARK: count + controls
    var countArea: some View {
        let t = model.theme
        let inner = VStack(spacing: 4) {
            Text(p.isCrochet ? "Row / Round" : "Row").font(.headline).foregroundStyle(t.muted).textCase(.uppercase)
            Text("\(p.rows)")
                .font(.system(size: 120, weight: .bold, design: .rounded)).monospacedDigit()
                .minimumScaleFactor(0.4).lineLimit(1)
                .contentTransition(.numericText(value: Double(p.rows)))
                .scaleEffect(bump % 2 == 0 ? 1 : 1.0001)
                .accessibilityLabel("\(p.isCrochet ? "Row or round" : "Row") \(p.rows)")
            ForEach([Engine.targetLine(p), Engine.nextReminderText(p, pro: model.isPro)].compactMap { $0 }, id: \.self) { line in
                Text(line).font(.callout).foregroundStyle(t.muted).multilineTextAlignment(.center)
            }
            if locked {
                Text("🔒 Locked").font(.footnote.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(t.muted.opacity(0.15))).padding(.top, 6)
            } else if model.state.settings.tapAnywhere {
                Muted("Tap anywhere here to add a row").padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 24).fill(t.card))
        .opacity(locked ? 0.7 : 1)
        .animation(.snappy, value: p.rows)
        return Group {
            if model.state.settings.tapAnywhere && !locked {
                Button { inc() } label: { inner }.buttonStyle(.plain).accessibilityLabel("Add a row")
            } else { inner }
        }
    }

    var controls: some View {
        let t = model.theme
        return HStack(spacing: 12) {
            Button { model.changeRows(projectID, -1) } label: {
                Text("−").font(.system(size: 40, weight: .bold)).frame(maxWidth: .infinity, minHeight: 84)
            }
            .buttonStyle(.bordered).accessibilityLabel("Subtract a row")
            Button { model.undo(projectID) } label: {
                VStack(spacing: 2) { Image(systemName: "arrow.uturn.backward"); Text("Undo").font(.caption) }.frame(maxWidth: .infinity, minHeight: 84)
            }
            .buttonStyle(.bordered).accessibilityLabel("Undo last change")
            Button { inc() } label: {
                Text("+").font(.system(size: 52, weight: .bold)).frame(maxWidth: .infinity, minHeight: 84)
            }
            .buttonStyle(.borderedProminent).layoutPriority(1).accessibilityLabel("Add a row")
        }
        .disabled(locked)
        .tint(t.accent)
    }

    func inc() { model.changeRows(projectID, 1); bump += 1 }

    func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .space, .rightArrow, .downArrow, .pageDown: inc(); return .handled
        case .leftArrow, .upArrow, .pageUp: model.changeRows(projectID, -1); return .handled
        case KeyEquivalent("u"), KeyEquivalent("U"): model.undo(projectID); return .handled
        default: return .ignored
        }
    }

    // MARK: tools
    func toolRow(_ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(on: locked, label: locked ? "🔒 Locked" : "🔓 Lock") { model.toggleLock() }
                Chip(on: model.state.settings.keepAwake, label: "☀️ Keep screen on") {
                    model.state.settings.keepAwake.toggle(); model.save()
                    model.showToast(model.state.settings.keepAwake ? "Screen will stay on while counting" : "Screen can sleep normally")
                }
                Chip(on: false, label: "📄 Pattern", pro: true) { patternAction() }
                Chip(on: p.timer.runningSince != nil, label: "⏱ Timer", pro: true) {
                    if model.isPro { withAnimation { proxy.scrollTo("timer", anchor: .center) } } else { model.openPro("The project timer") }
                }
                Chip(on: false, label: "📝 Notes") { withAnimation { proxy.scrollTo("notes", anchor: .top) } }
                Chip(on: false, label: "🕘 History") { withAnimation { proxy.scrollTo("history", anchor: .top) } }
            }
        }
    }

    func patternAction() {
        guard model.isPro else { model.openPro("The pattern viewer"); return }
        if p.pattern != nil { showPattern = true } else { importPattern = true }
    }

    var countersCard: some View {
        Card {
            HStack {
                Text("Extra counters").font(.headline)
                Spacer()
                Button {
                    if Engine.canAddCounter(p, pro: model.isPro) { counterEdit = CounterEditTarget(counterID: nil) }
                    else { model.openPro("More than \(Engine.freeExtraCounters) extra counter") }
                } label: { HStack(spacing: 4) { Text("+ Add"); if p.counters.count >= Engine.freeExtraCounters { ProTag() } } }
                .buttonStyle(.bordered)
            }
            if p.counters.isEmpty {
                Muted("Use these for stitches, increases or a pattern repeat. A linked counter moves with every row. Set “repeat every N rows” and it starts over after N and counts the repeats you’ve finished.")
            }
            ForEach(p.counters) { c in CounterRow(c: c, projectID: projectID) { counterEdit = CounterEditTarget(counterID: c.id) } }
        }
    }

    var remindersCard: some View {
        Card {
            HStack {
                Text("Row reminders").font(.headline); ProTag()
                Spacer()
                Button("+ Add") { if model.isPro { addReminder = true } else { model.openPro("Row reminders") } }.buttonStyle(.bordered)
            }
            if p.reminders.isEmpty {
                Muted("Example: “Decrease row” every 6 rows. You get a nudge on the right row.")
            }
            ForEach(p.reminders) { r in
                HStack {
                    VStack(alignment: .leading) {
                        Text(r.text).font(.body.weight(.semibold))
                        Muted("Every \(plural(r.every, "row")), starting at row \(r.start)")
                    }
                    Spacer()
                    Button { model.update(projectID) { $0.reminders.removeAll { $0.id == r.id } } } label: { Image(systemName: "xmark") }
                        .buttonStyle(.bordered).accessibilityLabel("Delete reminder")
                }
            }
        }
    }

    var timerCard: some View {
        Card {
            HStack { Text("Project timer").font(.headline); ProTag() }
            HStack {
                VStack(alignment: .leading) {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(fmtDur(Engine.timerElapsed(p, now: ctx.date.timeIntervalSince1970 * 1000)))
                            .font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                    }
                    Muted("Total time. It keeps counting when the app is closed.")
                }
                Spacer()
                Button("Edit") { if model.isPro { editTimer = true } else { model.openPro("The project timer") } }.buttonStyle(.bordered)
                Button(p.timer.runningSince != nil ? "Pause" : "Start") {
                    if model.isPro { model.update(projectID) { Engine.timerToggle(&$0) }; model.haptic(.normal) }
                    else { model.openPro("The project timer") }
                }.buttonStyle(.borderedProminent)
            }
        }
    }

    var notesCard: some View {
        Card {
            Text("Notes").font(.headline)
            TextEditor(text: $notes)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 12).fill(model.theme.background))
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty { Text("Yarn, needle or hook size, gauge, mods…").foregroundStyle(model.theme.muted).padding(14).allowsHitTesting(false) }
                }
                .accessibilityLabel("Project notes")
                .onChange(of: notes) { _, v in
                    guard v != p.notes else { return }
                    model.update(projectID) { $0.notes = v; $0.updatedAt = nowMs() }
                    notesSaved = true
                    Task { try? await Task.sleep(nanoseconds: 1_500_000_000); notesSaved = false }
                }
            Muted(notesSaved ? "Saved ✓" : "Saves as you type.")
        }
    }

    var photoCard: some View {
        Card {
            HStack {
                Text("Project photo").font(.headline)
                Spacer()
                PhotosPicker(selection: $photoItem, matching: .images) { Text(p.hasPhoto ? "Change" : "+ Add photo") }.buttonStyle(.bordered)
                if p.hasPhoto {
                    Button {
                        confirmSpec = ConfirmSpec(title: "Remove photo?", message: "The project photo will be deleted.", ok: "Remove") { model.removePhoto(projectID) }
                    } label: { Image(systemName: "xmark") }.buttonStyle(.bordered).accessibilityLabel("Remove photo")
                }
            }
            if p.hasPhoto, let img = ImageCache.shared.image("photo:\(projectID)") {
                Image(uiImage: img).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityLabel("Project photo")
            }
        }
    }

    var historyCard: some View {
        Card {
            Text("History").font(.headline)
            Muted("Every change is logged. Tap ↺ to go back to that count.")
            let items = Array(p.log.suffix(60).reversed())
            if items.isEmpty { Muted("No changes yet. Tap + to start.") }
            ForEach(Array(items.enumerated()), id: \.offset) { _, e in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.m)
                        Muted("\(fmtDay(e.t)), \(fmtClock(e.t))")
                    }
                    Spacer()
                    if e.r != p.rows {
                        Button("↺ \(e.r)") { model.restoreRow(projectID, e.r) }.buttonStyle(.bordered)
                            .accessibilityLabel("Go back to row \(e.r)")
                    }
                }
                Divider()
            }
        }
    }

    // MARK: menu actions
    func startNewProject() {
        if Engine.canAddProject(count: model.state.projects.count, pro: model.isPro) { newProject = true }
        else { model.openPro("More than \(Engine.freeProjectLimit) projects") }
    }
    func confirmReset() {
        confirmSpec = ConfirmSpec(title: "Reset to row 0?", message: "Your current count (\(p.rows)) stays in History, and you can undo this.", ok: "Reset") { model.reset(projectID) }
    }
    func confirmDelete() {
        confirmSpec = ConfirmSpec(title: "Delete “\(p.name)”?", message: "This removes the project, its notes, photo and pattern from this phone. It can’t be undone unless you have a backup.", ok: "Delete") { model.deleteProject(projectID) }
    }
}

struct CounterEditTarget: Identifiable { let id = UUID(); let counterID: String? }

struct Chip: View {
    @EnvironmentObject var model: AppModel
    let on: Bool
    let label: String
    var pro = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) { Text(label); if pro { ProTag() } }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Capsule().fill(on ? model.theme.accent.opacity(0.2) : model.theme.card))
                .overlay(Capsule().stroke(model.theme.muted.opacity(0.2)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct CounterRow: View {
    @EnvironmentObject var model: AppModel
    let c: ExtraCounter
    let projectID: String
    let edit: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Button(action: edit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(.body.weight(.semibold))
                    Muted(([c.linked ? "linked to rows" : "manual"] + (c.resetAt.map { ["repeat every \($0)"] } ?? []) + ["tap to edit"]).joined(separator: " · "))
                    if c.resetAt != nil {
                        Text("**\(c.repeats)**\(c.repeatTarget.map { " / \($0)" } ?? "") repeats done").font(.footnote)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            Button { model.changeCounter(projectID, counter: c.id, -1) } label: { Text("−").font(.title2.bold()).frame(width: 44, height: 44) }
                .buttonStyle(.bordered).accessibilityLabel("\(c.name) minus one")
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(c.value)").font(.title2.bold()).monospacedDigit()
                if let r = c.resetAt { Text("/\(r)").font(.footnote).foregroundStyle(model.theme.muted) }
            }.frame(minWidth: 44)
            Button { model.changeCounter(projectID, counter: c.id, 1) } label: { Text("+").font(.title2.bold()).frame(width: 44, height: 44) }
                .buttonStyle(.borderedProminent).accessibilityLabel("\(c.name) plus one")
        }
        .disabled(false)
    }
}

struct TipsCard: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Card {
            Text("Welcome to Rowbin 🧶").font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Tap the big **+** at the end of each row. Every tap saves right away, so closing the app never loses your place.")
                Text("2. Tapped by mistake? Hit **Undo**. Every change is also kept in the History log.")
                Text("3. Add a **repeat counter** below for patterns like “8-row repeat × 39”. It rolls over at 8 and counts the repeats for you.")
                Text("4. Free forever: no ads, no account. Pro is an optional **one-time** unlock.")
            }.font(.footnote)
            Button("Got it") { model.state.settings.tipsSeen = true; model.save() }.buttonStyle(.bordered)
        }
    }
}
