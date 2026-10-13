import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var model: AppModel
    @State private var showNew = false

    var body: some View {
        let t = model.theme
        ScrollView {
            VStack(spacing: 12) {
                ForEach(model.state.projects.sorted { $0.updatedAt > $1.updatedAt }) { p in
                    Button { model.path.append(.project(p.id)) } label: { ProjectRow(p: p) }
                        .buttonStyle(.plain)
                }
                Button {
                    if Engine.canAddProject(count: model.state.projects.count, pro: model.isPro) { showNew = true }
                    else { model.openPro("More than \(Engine.freeProjectLimit) projects") }
                } label: {
                    HStack { Text("+ New project").font(.headline); if model.state.projects.count >= Engine.freeProjectLimit { ProTag() } }
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                if model.isPro { Muted("Rowbin Pro ✓ Thank you!") }
                else {
                    Text("Free: \(Engine.freeProjectLimit) projects. Pro: unlimited, one-time. [What’s included](rowbin-internal://about)")
                        .font(.footnote).foregroundStyle(t.muted).multilineTextAlignment(.center)
                        .environment(\.openURL, OpenURLAction { _ in model.path.append(.about); return .handled })
                }
                if let note = backupNote { Muted(note) }
            }
            .padding(16)
        }
        .background(t.background.ignoresSafeArea())
        .foregroundStyle(t.text)
        .navigationTitle("Rowbin")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.path.append(.about) } label: { Image(systemName: "info.circle") }.accessibilityLabel("About")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.path.append(.settings) } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showNew) {
            ProjectForm(project: nil) { v in
                if let id = model.newProject(name: v.name, craft: v.craft, target: v.target) { model.path.append(.project(id)) }
            }
            .environmentObject(model)
        }
    }

    var backupNote: String? {
        guard model.state.projects.contains(where: { $0.rows > 0 }) else { return nil }
        if let lb = model.state.settings.lastBackup {
            let d = daysAgo(lb)
            return "Last backup: " + (d == 0 ? "today" : "\(plural(d, "day")) ago")
        }
        return "No backup yet. It only takes a second, in Settings."
    }
}

struct ProjectRow: View {
    @EnvironmentObject var model: AppModel
    let p: Project
    var body: some View {
        let t = model.theme
        HStack(spacing: 14) {
            Group {
                if p.hasPhoto, let img = ImageCache.shared.image("photo:\(p.id)") {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Text(p.isCrochet ? "🪝" : "🧶").font(.system(size: 28))
                }
            }
            .frame(width: 54, height: 54).background(t.accent.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(p.name).font(.headline).lineLimit(1)
                Text([p.isCrochet ? "Crochet" : "Knitting", p.target.map { "\(p.rows) of \($0)" }, fmtDay(p.updatedAt)].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(t.muted)
                if let target = p.target {
                    ProgressView(value: min(1, Double(p.rows) / Double(target))).tint(t.accent)
                }
            }
            Spacer(minLength: 8)
            Text("\(p.rows)").font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(t.card))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the counter")
    }
}

struct ProjectFormValues { var name: String; var craft: String; var target: Int?; var rows: Int? }

struct ProjectForm: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let project: Project?
    let onSave: (ProjectFormValues) -> Void
    @State private var name = ""
    @State private var craft = "knit"
    @State private var target = ""
    @State private var rows = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("e.g. Cozy cardigan", text: $name)
                    .onChange(of: name) { _, v in if v.count > 60 { name = String(v.prefix(60)) } }
                Picker("Craft", selection: $craft) {
                    Text("🧶 Knitting").tag("knit")
                    Text("🪝 Crochet").tag("crochet")
                }.pickerStyle(.segmented)
                Section("Target rows (optional)") { TextField("e.g. 120", text: $target).keyboardType(.numberPad) }
                if project != nil { Section("Current row") { TextField("0", text: $rows).keyboardType(.numberPad) } }
            }
            .navigationTitle(project == nil ? "New project" : "Edit project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(project == nil ? "Create" : "Save") {
                        let tv = Int(target) ?? 0
                        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(.init(name: n.isEmpty ? "My project" : n, craft: craft, target: tv > 0 ? tv : nil, rows: project == nil ? nil : Int(rows)))
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let p = project { name = p.name; craft = p.craft; target = p.target.map(String.init) ?? ""; rows = String(p.rows) }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
