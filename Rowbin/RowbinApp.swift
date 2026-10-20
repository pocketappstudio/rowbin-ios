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
                .onAppear { model.isPro = store.isPro || demoPro; demoRoute() }
                .onChange(of: store.isPro) { _, v in model.isPro = v || demoPro }
                .onChange(of: phase) { _, p in
                    if p == .active { model.reloadFromDisk(); Task { await store.refreshEntitlements() } }
                }
                .onOpenURL { model.open(url: $0) }
        }
    }

    private var demoPro: Bool {
        #if DEBUG
        return Demo.active && Demo.screen != "pro"
        #else
        return false
        #endif
    }
    private func demoRoute() {
        #if DEBUG
        if Demo.screen == "pro" { model.proSheetFeature = .some(nil) }
        if Demo.screen == "settings", let id = model.state.currentProject?.id { model.path = [.project(id), .settings] }
        #endif
    }
}
