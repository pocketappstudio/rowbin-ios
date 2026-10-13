import SwiftUI

struct CounterSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let projectID: String
    let counterID: String?
    @State private var name = ""
    @State private var linked = true
    @State private var resetAt = ""
    @State private var repeatTarget = ""
    @State private var value = ""
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Counter", text: $name).onChange(of: name) { _, v in if v.count > 40 { name = String(v.prefix(40)) } }
                }
                Section {
                    Toggle(isOn: $linked) {
                        VStack(alignment: .leading) { Text("Link to rows"); Muted("Moves by one each time you tap the main +") }
                    }
                }
                Section("Repeat every N rows (optional)") { TextField("e.g. 8 (starts over and counts repeats)", text: $resetAt).keyboardType(.numberPad) }
                Section("Repeat goal (optional)") { TextField("e.g. 39", text: $repeatTarget).keyboardType(.numberPad) }
                if counterID != nil {
                    Section("Current value") { TextField("0", text: $value).keyboardType(.numberPad) }
                    Section { Button("Delete counter", role: .destructive) { confirmDelete = true } }
                }
            }
            .navigationTitle(counterID == nil ? "Add a counter" : "Edit counter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .alert("Delete “\(name)”?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    model.update(projectID) { p in
                        p.counters.removeAll { $0.id == counterID }
                        Engine.log(&p, "Counter deleted: \(name)")
                    }
                    dismiss()
                }
            } message: { Text("This counter will be removed.") }
            .onAppear(perform: load)
        }
        .presentationDetents([.large])
    }

    func load() {
        let p = model.state.project(projectID)
        if let id = counterID, let c = p?.counters.first(where: { $0.id == id }) {
            name = c.name; linked = c.linked; resetAt = c.resetAt.map(String.init) ?? ""
            repeatTarget = c.repeatTarget.map(String.init) ?? ""; value = String(c.value)
        } else {
            let n = p?.counters.count ?? 0
            name = n > 0 ? "Counter \(n + 1)" : "Repeat"
        }
    }

    func save() {
        let ra = Int(resetAt) ?? 0, rt = Int(repeatTarget) ?? 0
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        model.update(projectID) { p in
            if let id = counterID, let i = p.counters.firstIndex(where: { $0.id == id }) {
                var c = p.counters[i]
                c.name = trimmed.isEmpty ? "Counter" : trimmed
                c.linked = linked; c.resetAt = ra > 0 ? ra : nil; c.repeatTarget = rt > 0 ? rt : nil
                let nv = max(0, Int(value) ?? 0)
                if nv != c.value { Engine.pushUndo(&p); c.value = nv }
                if let r = c.resetAt, c.value > r { c.value = r }
                p.counters[i] = c
            } else {
                var c = ExtraCounter(name: trimmed.isEmpty ? "Counter" : trimmed, linked: linked, resetAt: ra > 0 ? ra : nil, repeatTarget: rt > 0 ? rt : nil)
                if let r = c.resetAt, c.value > r { c.value = r }
                p.counters.append(c)
                Engine.log(&p, "Counter added: \(c.name)")
            }
        }
        dismiss()
    }
}

struct ReminderSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let projectID: String
    @State private var text = ""
    @State private var every = "6"
    @State private var start = ""
    @State private var touchedStart = false
    @State private var error: String?

    var rows: Int { model.state.project(projectID)?.rows ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder") {
                    TextField("e.g. Decrease row", text: $text).onChange(of: text) { _, v in if v.count > 60 { text = String(v.prefix(60)) } }
                }
                Section("Every N rows") {
                    TextField("6", text: $every).keyboardType(.numberPad)
                        .onChange(of: every) { _, v in if !touchedStart { start = String(rows + (Int(v) ?? 0)) } }
                }
                Section("First at row") {
                    TextField("", text: Binding(get: { start }, set: { start = $0; touchedStart = true })).keyboardType(.numberPad)
                }
                if let error { Text(error).foregroundStyle(RowbinTheme.danger) }
            }
            .navigationTitle("Add a row reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let e = Int(every), e > 0 else { error = "Enter how many rows apart"; return }
                        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        model.update(projectID) { $0.reminders.append(Reminder(text: t.isEmpty ? "Reminder" : t, every: e, start: max(0, Int(start) ?? 0))) }
                        dismiss()
                    }
                }
            }
            .onAppear { start = String(rows + 6) }
        }
        .presentationDetents([.medium, .large])
    }
}

struct TimerEditSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let projectID: String
    @State private var hours = ""
    @State private var minutes = ""
    var body: some View {
        NavigationStack {
            Form {
                Muted("Forgot to start the timer? Set the total here.")
                Section("Hours") { TextField("0", text: $hours).keyboardType(.numberPad) }
                Section("Minutes") { TextField("0", text: $minutes).keyboardType(.numberPad) }
            }
            .navigationTitle("Edit total time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.update(projectID) { Engine.timerSet(&$0, hours: Int(hours) ?? 0, minutes: Int(minutes) ?? 0) }
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let p = model.state.project(projectID) {
                    let ms = Engine.timerElapsed(p)
                    hours = String(Int(ms / 3_600_000)); minutes = String(Int(ms.truncatingRemainder(dividingBy: 3_600_000) / 60_000))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct ProFeatureList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Unlimited projects (free: \(Engine.freeProjectLimit))", systemImage: "square.stack")
            Label("Unlimited extra & repeat counters (free: \(Engine.freeExtraCounters) per project)", systemImage: "plusminus")
            Label("“Every N rows” reminders", systemImage: "bell")
            Label("Pattern viewer for PDFs & photos with a movable line highlighter", systemImage: "doc.richtext")
            Label("Project timer that keeps running when the app is closed (editable)", systemImage: "timer")
            Label("Themes, including a dark mode", systemImage: "paintpalette")
        }.font(.callout)
    }
}

struct ProSheet: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: ProStore
    @Environment(\.dismiss) private var dismiss
    let feature: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(feature.map { "\($0) is part of Pro" } ?? "Rowbin Pro").font(.title2.bold())
                    Text("**One-time purchase\(store.priceText.isEmpty ? "" : ", \(store.priceText)").** No subscription and no account. It keeps working offline, forever.")
                    ProFeatureList()
                    Button {
                        Task { if await store.purchase() { model.haptic(.strong); model.showToast("Pro unlocked. Thank you! 🧶", seconds: 4); dismiss() } }
                    } label: {
                        Text(store.priceText.isEmpty ? "Buy Pro" : "Buy Pro, \(store.priceText) one-time").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent).disabled(store.busy)
                    Button { Task { await store.restore(); if store.isPro { dismiss() } } } label: {
                        Text("Restore Purchases").frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.bordered).disabled(store.busy)
                    if store.busy { ProgressView().frame(maxWidth: .infinity) }
                    if let m = store.message { Text(m).font(.footnote).foregroundStyle(model.theme.muted) }
                    Muted("Paid through your Apple Account. Already bought Pro on another iPhone or iPad with the same Apple Account? Tap Restore Purchases.")
                }
                .padding(20)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } } }
        }
        .tint(model.theme.accent)
        .onChange(of: store.isPro) { _, v in if v { dismiss() } }
    }
}
