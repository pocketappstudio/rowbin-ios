import SwiftUI

/// The shaping plan beside the counter (Pro). It is a passive list: it never alerts, notifies or prompts.
/// It shows the live stitch count and marks which shaping rows are done, based on the row count.
struct ShapingCard: View {
    @EnvironmentObject var model: AppModel
    let projectID: String
    @Binding var editing: Bool
    @State private var showAll = false

    var body: some View {
        let t = model.theme
        let p = model.state.project(projectID) ?? Project()
        Card {
            HStack {
                Text("Shaping plan").font(.headline)
                ProTag()
                Spacer()
                Button(p.shaping == nil ? "+ Plan" : "Edit") {
                    if model.isPro { editing = true } else { model.openPro("The shaping calculator") }
                }.buttonStyle(.bordered)
            }
            if let plan = p.shaping, model.isPro {
                let rows = ShapingMath.rows(plan, crochet: p.isCrochet)
                let now = ShapingMath.stitches(plan, crochet: p.isCrochet, completedRows: p.rows)
                let next = rows.first { $0.row > p.rows }
                HStack(alignment: .firstTextBaseline) {
                    Text("\(now)").font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("stitches now").foregroundStyle(t.muted)
                    Spacer()
                    Text("→ \(ShapingMath.finalStitches(plan, crochet: p.isCrochet))").font(.callout.weight(.semibold)).foregroundStyle(t.muted)
                        .accessibilityLabel("\(ShapingMath.finalStitches(plan, crochet: p.isCrochet)) stitches at the end of the plan")
                }
                .accessibilityElement(children: .combine)
                if let next {
                    Text("Next shaping row: **\(next.row)**, \(next.text.lowercasedFirst())").font(.callout)
                } else if !rows.isEmpty {
                    Text("All shaping rows are done ✓").font(.callout.weight(.semibold))
                }
                let shown = showAll ? rows : window(rows, current: p.rows)
                VStack(spacing: 0) {
                    ForEach(shown) { r in PlanRowView(r: r, done: r.row <= p.rows, isNext: r.id == next?.id) }
                }
                if rows.count > shown.count || showAll {
                    Button(showAll ? "Show fewer" : "Show all \(rows.count) shaping rows") { showAll.toggle() }.font(.footnote)
                }
            } else {
                Muted("Work out even increases or decreases, or “every N rows, X times” shaping. The plan sits here as a list with your live stitch count. It never pops up or interrupts you.")
            }
        }
    }

    /// A short window around the next shaping row: 2 done rows, then up to 4 ahead.
    func window(_ rows: [ShapingMath.PlanRow], current: Int) -> [ShapingMath.PlanRow] {
        let i = rows.firstIndex { $0.row > current } ?? rows.count
        let lo = max(0, i - 2), hi = min(rows.count, max(i, lo) + 4)
        return Array(rows[lo..<hi])
    }
}

struct PlanRowView: View {
    @EnvironmentObject var model: AppModel
    let r: ShapingMath.PlanRow
    let done: Bool
    let isNext: Bool
    var body: some View {
        let t = model.theme
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : (isNext ? "arrow.right.circle.fill" : "circle"))
                .foregroundStyle(done ? t.muted : t.accent).font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Row \(r.row)").font(.subheadline.weight(.semibold))
                Text(r.text).font(.footnote).foregroundStyle(t.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text("\(r.after) sts").font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .padding(.vertical, 8).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(isNext ? t.accent.opacity(0.12) : .clear))
        .opacity(done ? 0.65 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Row \(r.row). \(r.text). \(r.after) stitches after. \(done ? "Done" : (isNext ? "Next" : "Ahead"))")
    }
}

extension String {
    func lowercasedFirst() -> String { prefix(1).lowercased() + dropFirst() }
}

/// Editor for the shaping plan.
struct ShapingSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let projectID: String
    @State private var start = ""
    @State private var steps: [ShapeStep] = []
    // new step
    @State private var kind = "every"
    @State private var dir = "dec"
    @State private var row = "1"
    @State private var count = "2"
    @State private var every = "4"
    @State private var times = "6"
    // work it out
    @State private var wFrom = ""
    @State private var wTo = ""
    @State private var wPer = "2"
    @State private var wRows = ""
    @State private var wRow = "1"
    @State private var confirmClear = false

    var crochet: Bool { model.state.project(projectID)?.isCrochet ?? false }
    var draft: ShapingPlan { ShapingPlan(start: Int(start) ?? 0, steps: steps) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. 120", text: $start).keyboardType(.numberPad).accessibilityLabel("Stitches before row 1")
                } header: { Text("Stitches before row 1") } footer: { Text("Row numbers below match your row counter: row 1 is the first row you count.") }

                Section("Steps") {
                    if steps.isEmpty { Text("No steps yet. Add one below.").foregroundStyle(.secondary) }
                    ForEach(steps) { s in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(describe(s)).font(.body.weight(.semibold))
                            if s.isEven, let ev = evenPreview(s) { Text(ev).font(.footnote).foregroundStyle(.secondary) }
                        }.accessibilityElement(children: .combine)
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    if !steps.isEmpty {
                        Text("Ends with **\(ShapingMath.finalStitches(draft, crochet: crochet))** stitches after \(plural(ShapingMath.rows(draft, crochet: crochet).count, "shaping row")).").font(.footnote)
                    }
                }

                Section {
                    Picker("Type", selection: $kind) {
                        Text("Every N rows").tag("every"); Text("Evenly in one row").tag("even")
                    }.pickerStyle(.segmented)
                    Picker("Shaping", selection: $dir) {
                        Text("Decrease").tag("dec"); Text("Increase").tag("inc")
                    }.pickerStyle(.segmented)
                    LabeledField(label: kind == "even" ? "On row" : "First on row", text: $row)
                    LabeledField(label: kind == "even" ? "Stitches to \(dir == "inc" ? "add" : "take away")" : "Stitches per shaping row", text: $count)
                    if kind == "every" {
                        LabeledField(label: "Every … rows", text: $every)
                        LabeledField(label: "How many times", text: $times)
                    } else if let s = newStep, let ev = evenPreview(s) {
                        Text(ev).font(.footnote).foregroundStyle(.secondary)
                    } else if kind == "even" {
                        Text("Enter stitches before row 1 and a number that fits the row.").font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Add step") { if let s = newStep { steps.append(s); steps.sort { $0.row < $1.row } } }
                        .disabled(newStep == nil || steps.count >= ShapingMath.maxSteps)
                } header: { Text("Add a step") }

                Section {
                    LabeledField(label: "From stitches", text: $wFrom)
                    LabeledField(label: "To stitches", text: $wTo)
                    LabeledField(label: "Stitches per shaping row", text: $wPer)
                    LabeledField(label: "Over how many rows", text: $wRows)
                    LabeledField(label: "Start on row", text: $wRow)
                    if let w = workOut {
                        Text(w.text).font(.footnote)
                        Button("Add these steps") { steps.append(contentsOf: w.steps); steps.sort { $0.row < $1.row }; if start.isEmpty { start = wFrom } }
                            .disabled(steps.count + w.steps.count > ShapingMath.maxSteps)
                    } else if !wFrom.isEmpty && !wTo.isEmpty && !wRows.isEmpty {
                        Text("That doesn’t divide evenly. Check that the stitch difference is a multiple of the stitches per shaping row, and that there are enough rows.").font(.footnote).foregroundStyle(.secondary)
                    }
                } header: { Text("Work it out for me") } footer: { Text("Spreads the shaping rows as evenly as possible, for example for a sleeve taper.") }

                if model.state.project(projectID)?.shaping != nil {
                    Section { Button("Remove the plan", role: .destructive) { confirmClear = true } }
                }
            }
            .navigationTitle("Shaping plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(Int(start) == nil) }
            }
            .alert("Remove the shaping plan?", isPresented: $confirmClear) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) { model.update(projectID) { $0.shaping = nil; Engine.log(&$0, "Shaping plan removed") }; dismiss() }
            }
            .onAppear {
                if let plan = model.state.project(projectID)?.shaping { start = String(plan.start); steps = plan.steps }
            }
        }
        .tint(model.theme.accent)
    }

    var newStep: ShapeStep? {
        guard let r = Int(row), r >= 1, let c = Int(count), c >= 1 else { return nil }
        if kind == "even" {
            let s = ShapeStep(kind: "even", dir: dir, row: r, count: c)
            return evenPreview(s) == nil ? nil : s
        }
        guard let e = Int(every), e >= 1, let x = Int(times), x >= 1, x <= 1000 else { return nil }
        return ShapeStep(kind: "every", dir: dir, row: r, count: c, every: e, times: x)
    }

    func describe(_ s: ShapeStep) -> String {
        let verb = s.isInc ? "Increase" : "Decrease"
        if s.isEven { return "Row \(s.row): \(verb.lowercased()) \(s.count) evenly" }
        if s.times == 1 { return "Row \(s.row): \(verb.lowercased()) \(s.count)" }
        return "\(verb) \(s.count) every \(plural(s.every, "row")), \(s.times) times, from row \(s.row)"
    }
    /// Even spacing uses the stitch count on the needle at that row.
    func evenPreview(_ s: ShapeStep) -> String? {
        var before = draft
        before.steps = steps.filter { $0.id != s.id }
        let sts = ShapingMath.stitches(before, crochet: crochet, completedRows: s.row - 1)
        return ShapingMath.even(stitches: sts, change: s.count, inc: s.isInc, crochet: crochet).map { "Over \(sts) sts: \($0.text)" }
    }

    var workOut: (text: String, steps: [ShapeStep])? {
        guard let f = Int(wFrom), let to = Int(wTo), f != to, let per = Int(wPer), let r = Int(wRows), let first = Int(wRow), first >= 1,
              let x = ShapingMath.timesNeeded(from: f, to: to, per: per), let sp = ShapingMath.spread(times: x, overRows: r) else { return nil }
        let d = to > f ? "inc" : "dec", verb = to > f ? "Increase" : "Decrease"
        var out: [ShapeStep] = []
        // Shaping rows land at the end of each gap: first on row (start + gap − 1).
        let firstRow = first + sp.firstEvery - 1
        if sp.firstTimes > 0 { out.append(ShapeStep(kind: "every", dir: d, row: firstRow, count: per, every: sp.firstEvery, times: sp.firstTimes)) }
        if sp.thenTimes > 0 {
            let r2 = firstRow + sp.firstTimes * sp.firstEvery + (sp.thenEvery - sp.firstEvery)
            out.append(ShapeStep(kind: "every", dir: d, row: sp.firstTimes > 0 ? r2 : first + sp.thenEvery - 1, count: per, every: sp.thenEvery, times: sp.thenTimes))
        }
        var text = "\(verb) \(per) every \(plural(sp.firstEvery, "row")) \(sp.firstTimes) times"
        if sp.thenTimes > 0 { text += ", then every \(plural(sp.thenEvery, "row")) \(sp.thenTimes) times" }
        text += ". That’s \(x) shaping rows over \(r) rows."
        return (text, out)
    }

    func save() {
        let plan = draft
        model.update(projectID) { p in
            p.shaping = plan; p.updatedAt = nowMs()
            Engine.log(&p, "Shaping plan saved: \(plan.start) → \(ShapingMath.finalStitches(plan, crochet: p.isCrochet)) sts")
        }
        dismiss()
    }
}

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var decimal = false
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", text: $text).keyboardType(decimal ? .decimalPad : .numberPad).multilineTextAlignment(.trailing).frame(maxWidth: 110)
                .accessibilityLabel(label)
        }
    }
}
