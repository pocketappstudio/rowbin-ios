import SwiftUI

/// Gauge & yarn planner (Pro). Everything is worked out on this phone from numbers you type in.
struct GaugeView: View {
    @EnvironmentObject var model: AppModel
    let projectID: String
    @State private var g = GaugeInfo()
    @State private var loaded = false
    @State private var convSts = ""
    @State private var convRows = ""

    var p: Project { model.state.project(projectID) ?? Project() }
    var u: String { g.unit }
    var lenUnit: String { g.unit == "cm" ? "m" : "yd" }

    var body: some View {
        let t = model.theme
        ScrollView {
            VStack(spacing: 14) {
                if !model.isPro {
                    Card {
                        HStack { Text("Gauge & yarn planner").font(.headline); ProTag() }
                        Muted("Compare your swatch with the pattern’s gauge, convert stitch and row counts, and estimate how much yarn you need, with a warning if you may run short.")
                        Button { model.openPro("The gauge & yarn planner") } label: { Text("See what Pro adds").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    }
                } else {
                    Card {
                        Text("Units").font(.headline)
                        Picker("Units", selection: $g.unit) { Text("Inches · yards").tag("in"); Text("Centimetres · metres").tag("cm") }
                            .pickerStyle(.segmented)
                            .onChange(of: g.unit) { old, v in if old != v, g.per == (old == "cm" ? 10 : 4) { g.per = v == "cm" ? 10 : 4 } }
                    }
                    Card {
                        Text("Pattern gauge").font(.headline)
                        NumRow(label: "Stitches", value: $g.patSts)
                        NumRow(label: "Rows", value: $g.patRows)
                        NumRow(label: "Over (\(u))", value: $g.per)
                    }
                    Card {
                        Text("Your swatch").font(.headline)
                        Muted("Count stitches and rows in the middle of your washed swatch, and measure what they cover.")
                        NumRow(label: "Stitches counted", value: $g.swSts)
                        NumRow(label: "…measure (\(u))", value: $g.swW)
                        NumRow(label: "Rows counted", value: $g.swRows)
                        NumRow(label: "…measure (\(u))", value: $g.swH)
                    }
                    results(t)
                    converter(t)
                    yarn(t)
                }
            }.padding(16)
        }
        .background(t.background.ignoresSafeArea())
        .foregroundStyle(t.text)
        .navigationTitle("Gauge & yarn")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if !loaded { g = p.gauge ?? defaultGauge(); loaded = true } }
        .onChange(of: g) { _, v in if loaded && model.isPro { model.update(projectID) { $0.gauge = v; $0.updatedAt = nowMs() } } }
    }

    func defaultGauge() -> GaugeInfo { var x = GaugeInfo(); x.unit = Locale.current.measurementSystem == .metric ? "cm" : "in"; x.per = x.unit == "cm" ? 10 : 4; return x }

    @ViewBuilder func results(_ t: RowbinTheme) -> some View {
        let mine = GaugeMath.myOverPer(g)
        Card {
            Text("Your gauge").font(.headline)
            if mine.sts == nil && mine.rows == nil {
                Muted("Enter your swatch to see your gauge.")
            } else {
                Text("**\(fmt(mine.sts))** sts and **\(fmt(mine.rows))** rows over \(fmt(g.per)) \(u)")
                if let d = GaugeMath.widthDiffPercent(g) {
                    let close = abs(d) < 2
                    Text(close ? "Your stitch gauge matches the pattern (within 2%)."
                         : "Following the pattern as written, your piece would be about **\(fmt(abs(d)))% \(d > 0 ? "wider" : "narrower")**.")
                        .font(.callout)
                }
            }
        }
    }

    @ViewBuilder func converter(_ t: RowbinTheme) -> some View {
        Card {
            Text("Convert counts").font(.headline)
            Muted("Type a number from the pattern to get the count for the same size at your gauge.")
            StrRow(label: "Pattern stitches", text: $convSts)
            if let n = Double(convSts) {
                if let c = GaugeMath.convertSts(n, g) { Text("Work **\(c)** stitches for the same width").font(.callout) }
                if let w = GaugeMath.sizeAtPatternGauge(sts: n, g), let mw = GaugeMath.sizeAtMyGauge(sts: n, g) {
                    Muted("\(fmt(w)) \(u) at the pattern’s gauge, \(fmt(mw)) \(u) at yours if unchanged.")
                }
            }
            StrRow(label: "Pattern rows", text: $convRows)
            if let n = Double(convRows), let c = GaugeMath.convertRows(n, g) { Text("Work **\(c)** rows for the same length").font(.callout) }
        }
    }

    @ViewBuilder func yarn(_ t: RowbinTheme) -> some View {
        let y = GaugeMath.yarn(g)
        Card {
            Text("Yarn estimate").font(.headline)
            Muted("Use the pattern’s yarn amount, your swatch’s weight, or both. Rowbin adjusts the pattern amount for your gauge and uses the larger estimate.")
            NumRow(label: "Pattern asks for (\(lenUnit))", value: $g.patYardage)
            NumRow(label: "Swatch weight (g)", value: $g.swGrams)
            NumRow(label: "Finished width (\(u))", value: $g.width)
            NumRow(label: "Finished length (\(u))", value: $g.length)
            Divider()
            NumRow(label: "Length per skein (\(lenUnit))", value: $g.skeinLen)
            NumRow(label: "Weight per skein (g)", value: $g.skeinGrams)
            NumRow(label: "Skeins you have", value: $g.skeins)
            NumRow(label: "Extra margin (%)", value: $g.margin)
            if y.needLen == nil && y.needGrams == nil {
                Muted("Enter the pattern’s yarn amount, or your swatch weight and the finished size.")
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if let l = y.needLen { Text("About **\(fmt(l, 0)) \(lenUnit)**\(y.needGrams.map { " (\(fmt($0, 0)) g)" } ?? "") including \(fmt(g.margin, 0))% extra") }
                    else if let gr = y.needGrams { Text("About **\(fmt(gr, 0)) g** including \(fmt(g.margin, 0))% extra") }
                    if let s = y.needSkeins { Text("That’s **\(plural(s, "skein"))**.") }
                }.font(.callout)
                if let short = y.shortSkeins {
                    if short > 0 {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                            Text("You may be **\(plural(short, "skein")) short**. Consider buying more from the same dye lot before you start.")
                        }
                        .font(.callout).foregroundStyle(t.isDark ? t.text : RowbinTheme.danger)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(RowbinTheme.danger.opacity(t.isDark ? 0.35 : 0.1)))
                        .accessibilityElement(children: .combine)
                    } else {
                        Text("✓ You have enough yarn for this estimate.").font(.callout.weight(.semibold))
                    }
                }
                Muted("Estimates only. Yarn use varies with stitch pattern, so keep a little extra.")
            }
        }
    }
}

func fmt(_ v: Double?, _ digits: Int = 1) -> String {
    guard let v, v.isFinite else { return "–" }
    return v.formatted(.number.precision(.fractionLength(0...digits)))
}

/// A number field that keeps what you type (e.g. "4.") while editing.
struct NumRow: View {
    let label: String
    @Binding var value: Double
    @State private var text = ""
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("–", text: $text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 110)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.35)))
                .accessibilityLabel(label)
        }
        .onAppear { text = value == 0 ? "" : value.formatted(.number.grouping(.never).precision(.fractionLength(0...3))) }
        .onChange(of: text) { _, s in
            let v = Double(s.replacingOccurrences(of: ",", with: ".").filter { "0123456789.".contains($0) }) ?? 0
            if v != value { value = min(1_000_000, max(0, v)) }
        }
    }
}

struct StrRow: View {
    let label: String
    @Binding var text: String
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("–", text: $text).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(maxWidth: 110)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.35)))
                .accessibilityLabel(label)
        }
    }
}
