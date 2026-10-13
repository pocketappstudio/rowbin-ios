import AppIntents
import WidgetKit

/// Interactive widget buttons (iOS 17+: Button(intent:) in a widget runs this in the widget extension).
struct ChangeRowIntent: AppIntent {
    static var title: LocalizedStringResource = "Change row count"
    static var description = IntentDescription("Adds or subtracts one row on a Rowbin project.")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Project") var projectID: String
    @Parameter(title: "Change") var delta: Int

    init() {}
    init(projectID: String, delta: Int) { self.projectID = projectID; self.delta = delta }

    func perform() async throws -> some IntentResult {
        let pro = SharedStore.proCached
        SharedStore.mutate { s in
            guard let i = s.index(projectID) else { return }
            Engine.changeRows(&s.projects[i], delta > 0 ? 1 : -1, locked: s.settings.locked, pro: pro)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct ChangeCounterIntent: AppIntent {
    static var title: LocalizedStringResource = "Change extra counter"
    static var description = IntentDescription("Adds or subtracts one on a Rowbin extra counter.")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Project") var projectID: String
    @Parameter(title: "Counter") var counterID: String
    @Parameter(title: "Change") var delta: Int

    init() {}
    init(projectID: String, counterID: String, delta: Int) { self.projectID = projectID; self.counterID = counterID; self.delta = delta }

    func perform() async throws -> some IntentResult {
        SharedStore.mutate { s in
            guard let i = s.index(projectID) else { return }
            Engine.changeCounter(&s.projects[i], id: counterID, delta > 0 ? 1 : -1, locked: s.settings.locked)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
