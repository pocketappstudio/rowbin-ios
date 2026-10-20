import WidgetKit
import SwiftUI
import AppIntents

struct RowbinEntry: TimelineEntry {
    let date: Date
    let project: Project?
    let pro: Bool
    let locked: Bool
    let themeID: String
}

struct RowbinProvider: TimelineProvider {
    func placeholder(in context: Context) -> RowbinEntry {
        var p = Project(name: "Cozy cardigan", craft: "knit"); p.rows = 42; p.target = 120
        p.counters = [ExtraCounter(name: "Repeat", value: 3, resetAt: 8, repeats: 5, repeatTarget: 39)]
        return RowbinEntry(date: Date(), project: p, pro: false, locked: false, themeID: "oat")
    }
    func getSnapshot(in context: Context, completion: @escaping (RowbinEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RowbinEntry>) -> Void) {
        // The app and the widget buttons reload timelines whenever counts change.
        completion(Timeline(entries: [current()], policy: .never))
    }
    private func current() -> RowbinEntry {
        let s = SharedStore.load(), pro = SharedStore.proCached
        return RowbinEntry(date: Date(), project: s.currentProject, pro: pro, locked: s.settings.locked, themeID: Engine.effectiveTheme(s.settings, pro: pro))
    }
}

struct RowbinWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RowbinEntry
    var theme: RowbinTheme { RowbinTheme.by(entry.themeID) }

    var body: some View {
        Group {
            if let p = entry.project {
                switch family {
                case .accessoryInline: Text("\(p.isCrochet ? "Round" : "Row") \(p.rows) · \(p.name)")
                case .accessoryCircular: circular(p)
                case .accessoryRectangular: rectangular(p)
                case .systemMedium: medium(p)
                case .systemLarge, .systemExtraLarge: large(p)
                default: small(p)
                }
            } else {
                Text("Open Rowbin to start a project").font(.footnote)
            }
        }
        .widgetURL(entry.project.map { URL(string: "rowbin://project/\($0.id)")! })
        .containerBackground(for: .widget) { family.isAccessory ? AnyView(AccessoryWidgetBackground()) : AnyView(theme.background) }
    }

    func label(_ p: Project) -> String { p.isCrochet ? "ROW / ROUND" : "ROW" }

    func small(_ p: Project) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(p.name).font(.caption.weight(.semibold)).lineLimit(1).foregroundStyle(theme.muted)
            Spacer(minLength: 0)
            Text(label(p)).font(.caption2.weight(.bold)).foregroundStyle(theme.muted)
            Text("\(p.rows)").font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit()
                .minimumScaleFactor(0.5).lineLimit(1).contentTransition(.numericText(value: Double(p.rows)))
            if let t = Engine.targetLine(p) { Text(t).font(.caption2).foregroundStyle(theme.muted).lineLimit(1) }
        }
        .foregroundStyle(theme.text)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    func stepButtons(_ p: Project, size: CGFloat) -> some View {
        HStack(spacing: 8) {
            Button(intent: ChangeRowIntent(projectID: p.id, delta: -1)) {
                Image(systemName: "minus").font(.system(size: size * 0.4, weight: .bold)).frame(width: size, height: size)
            }
            .buttonStyle(.plain).background(Circle().fill(theme.card)).accessibilityLabel("Subtract a row")
            Button(intent: ChangeRowIntent(projectID: p.id, delta: 1)) {
                Image(systemName: "plus").font(.system(size: size * 0.45, weight: .bold)).frame(width: size * 1.25, height: size)
            }
            .buttonStyle(.plain).foregroundStyle(.white).background(Capsule().fill(theme.accent)).accessibilityLabel("Add a row")
        }
        .disabled(entry.locked)
    }

    func repeatLine(_ p: Project) -> some View {
        Group {
            if let c = Engine.repeatCounter(p), let r = c.resetAt {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(c.name): \(c.value)/\(r) · \(c.repeats)\(c.repeatTarget.map { "/\($0)" } ?? "") repeats").font(.caption).lineLimit(1)
                    ProgressView(value: Double(c.value), total: Double(r)).tint(theme.accent)
                }
            }
        }
    }

    func medium(_ p: Project) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name).font(.caption.weight(.semibold)).lineLimit(1).foregroundStyle(theme.muted)
                Text("\(p.rows)").font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit()
                    .minimumScaleFactor(0.5).lineLimit(1).contentTransition(.numericText(value: Double(p.rows)))
                if let t = Engine.targetLine(p) { Text(t).font(.caption2).foregroundStyle(theme.muted) }
                repeatLine(p)
                if entry.locked { Text("🔒 Locked").font(.caption2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            stepButtons(p, size: 50)
        }
        .foregroundStyle(theme.text)
    }

    func large(_ p: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(p.name).font(.headline).lineLimit(1)
                Spacer()
                if entry.locked { Text("🔒").font(.caption) }
            }
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(label(p)).font(.caption2.weight(.bold)).foregroundStyle(theme.muted)
                    Text("\(p.rows)").font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit()
                        .minimumScaleFactor(0.5).lineLimit(1).contentTransition(.numericText(value: Double(p.rows)))
                    if let t = Engine.targetLine(p) { Text(t).font(.caption).foregroundStyle(theme.muted) }
                }
                Spacer()
                stepButtons(p, size: 54)
            }
            if let target = p.target { ProgressView(value: min(1, Double(p.rows) / Double(target))).tint(theme.accent) }
            Divider()
            if let c = p.counters.first {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(c.name.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(theme.muted).lineLimit(1)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(c.value)").font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                                .contentTransition(.numericText(value: Double(c.value)))
                            if let r = c.resetAt { Text("/\(r)").font(.callout).foregroundStyle(theme.muted) }
                        }
                        if c.resetAt != nil { Text("\(c.repeats)\(c.repeatTarget.map { " / \($0)" } ?? "") repeats done").font(.caption) }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button(intent: ChangeCounterIntent(projectID: p.id, counterID: c.id, delta: -1)) {
                            Image(systemName: "minus").font(.system(size: 20, weight: .bold)).frame(width: 48, height: 48)
                        }.buttonStyle(.plain).background(Circle().fill(theme.card)).accessibilityLabel("\(c.name) minus one")
                        Button(intent: ChangeCounterIntent(projectID: p.id, counterID: c.id, delta: 1)) {
                            Image(systemName: "plus").font(.system(size: 22, weight: .bold)).frame(width: 60, height: 48)
                        }.buttonStyle(.plain).foregroundStyle(.white).background(Capsule().fill(theme.accent)).accessibilityLabel("\(c.name) plus one")
                    }.disabled(entry.locked)
                }
            } else {
                Text("Add an extra counter in Rowbin to see it here.").font(.caption).foregroundStyle(theme.muted)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.text)
    }

    func circular(_ p: Project) -> some View {
        ZStack {
            if let t = p.target, t > 0 {
                Gauge(value: min(Double(p.rows), Double(t)), in: 0...Double(t)) { Text("Row") } currentValueLabel: { Text("\(p.rows)").monospacedDigit() }
                    .gaugeStyle(.accessoryCircularCapacity)
            } else {
                VStack(spacing: 0) {
                    Text("ROW").font(.system(size: 9, weight: .bold))
                    Text("\(p.rows)").font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.5)
                }
            }
        }
        .widgetAccentable()
    }

    func rectangular(_ p: Project) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(p.name).font(.caption.weight(.semibold)).lineLimit(1)
            Text("\(p.isCrochet ? "Row / Round" : "Row") \(p.rows)").font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit().widgetAccentable()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RowbinCounterWidget: Widget {
    let kind = "RowbinCounter"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RowbinProvider()) { RowbinWidgetView(entry: $0) }
            .configurationDisplayName("Row counter")
            .description("Your current project's row count. Medium and large widgets have +1 and −1 buttons.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct RowbinWidgetBundle: WidgetBundle {
    var body: some Widget { RowbinCounterWidget() }
}

extension WidgetFamily {
    var isAccessory: Bool { self == .accessoryCircular || self == .accessoryRectangular || self == .accessoryInline }
}
