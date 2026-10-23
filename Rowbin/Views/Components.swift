import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: ProStore
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    var body: some View {
        let t = model.theme
        NavigationStack(path: $model.path) {
            ProjectsView()
                .navigationDestination(for: Route.self) { r in
                    switch r {
                    case .project(let id): CounterView(projectID: id)
                    case .settings: SettingsView()
                    case .about: AboutView()
                    case .gauge(let id): GaugeView(projectID: id)
                    case .journal(let id): JournalView(projectID: id)
                    }
                }
        }
        .tint(t.accent)
        .preferredColorScheme(t.isDark ? .dark : .light)
        .onAppear { model.systemReduceMotion = systemReduceMotion }
        .onChange(of: systemReduceMotion) { _, v in model.systemReduceMotion = v }
        // Reduce motion: numbers, screens, toasts and scrolling change instantly.
        .transaction { if model.still { $0.disablesAnimations = true; $0.animation = nil } }
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if let msg = model.toast {
                    Text(msg).font(.callout.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Capsule().fill(Color.black.opacity(0.82)))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .padding(.bottom, 24).padding(.horizontal, 16)
            .animation(.spring(duration: 0.3), value: model.toast)
        }
        .sheet(isPresented: Binding(get: { model.proSheetFeature != nil }, set: { if !$0 { model.proSheetFeature = nil } })) {
            ProSheet(feature: model.proSheetFeature ?? nil).environmentObject(model).environmentObject(store)
        }
    }
}

struct Card<Content: View>: View {
    @EnvironmentObject var model: AppModel
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(model.theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(model.theme.muted.opacity(0.15)))
    }
}

struct ProTag: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        if !model.isPro {
            Text("PRO").font(.caption2.weight(.heavy)).padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(model.theme.accent.opacity(0.15))).foregroundStyle(model.theme.accent)
                .accessibilityLabel("Pro feature")
        }
    }
}

struct Muted: View {
    @EnvironmentObject var model: AppModel
    let text: String
    init(_ t: String) { text = t }
    var body: some View { Text(text).font(.footnote).foregroundStyle(model.theme.muted) }
}

func fmtDay(_ ms: Double) -> String {
    let d = Date(timeIntervalSince1970: ms / 1000), cal = Calendar.current
    if cal.isDateInToday(d) { return "Today" }
    if cal.isDateInYesterday(d) { return "Yesterday" }
    let sameYear = cal.component(.year, from: d) == cal.component(.year, from: Date())
    return d.formatted(sameYear ? .dateTime.month(.abbreviated).day() : .dateTime.month(.abbreviated).day().year())
}
func fmtClock(_ ms: Double) -> String { Date(timeIntervalSince1970: ms / 1000).formatted(date: .omitted, time: .shortened) }
func daysAgo(_ ms: Double) -> Int { Int((nowMs() - ms) / 86_400_000) }

struct ConfirmSpec: Identifiable {
    let id = UUID()
    let title: String, message: String, ok: String
    var destructive = true
    let action: () -> Void
}
extension View {
    func confirm(_ spec: Binding<ConfirmSpec?>) -> some View {
        alert(spec.wrappedValue?.title ?? "", isPresented: Binding(get: { spec.wrappedValue != nil }, set: { if !$0 { spec.wrappedValue = nil } }), presenting: spec.wrappedValue) { s in
            Button("Cancel", role: .cancel) {}
            Button(s.ok, role: s.destructive ? .destructive : nil) { s.action() }
        } message: { s in Text(s.message) }
    }
}
