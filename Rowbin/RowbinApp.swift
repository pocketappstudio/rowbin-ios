import SwiftUI

@main
struct RowbinApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var store = ProStore()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(store)
                .onAppear { model.isPro = store.isPro }
                .onChange(of: store.isPro) { _, v in model.isPro = v }
                .onChange(of: phase) { _, p in
                    if p == .active { model.reloadFromDisk(); Task { await store.refreshEntitlements() } }
                }
                .onOpenURL { model.open(url: $0) }
        }
    }
}
