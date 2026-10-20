import SwiftUI
import UIKit
import WidgetKit

enum Route: Hashable { case project(String), settings, about }

@MainActor
final class AppModel: ObservableObject {
    @Published var state: AppState
    @Published var path: [Route] = []
    @Published var toast: String?
    @Published var proSheetFeature: String?? = nil   // .some(nil) = generic Pro sheet
    @Published var isPro = SharedStore.proCached { didSet { if oldValue != isPro { objectWillChange.send() } } }
    @Published var saveFailed = false

    private var toastTask: Task<Void, Never>?
    private var lastTap: [String: Date] = [:]

    init() {
        var s = SharedStore.load()
        _ = Engine.ensureProject(&s)
        state = s
        SharedStore.save(s)
        SharedStore.writeLaunchBackup(s)
        if let id = s.currentProject?.id { path = [.project(id)] }
    }

    var theme: RowbinTheme { RowbinTheme.by(Engine.effectiveTheme(state.settings, pro: isPro)) }

    func reloadFromDisk() {
        let s = SharedStore.load()
        if s != state && !s.projects.isEmpty { state = s }
    }

    func save() {
        if !SharedStore.save(state), !saveFailed {
            saveFailed = true
            showToast("Storage is full. Remove a photo or pattern so counts can save.", seconds: 5)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func showToast(_ text: String, seconds: Double = 2.2) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    func haptic(_ f: Engine.Feedback) { Haptics.play(f, enabled: state.settings.haptics) }

    func debounced(_ key: String, _ ms: Double) -> Bool {
        let n = Date()
        if let l = lastTap[key], n.timeIntervalSince(l) * 1000 < ms { return true }
        lastTap[key] = n
        return false
    }

    func openPro(_ feature: String? = nil) { if !isPro { proSheetFeature = .some(feature) } }

    // MARK: project helpers
    func binding(_ id: String) -> Binding<Project>? {
        guard state.index(id) != nil else { return nil }
        return Binding(
            get: { self.state.project(id) ?? Project() },
            set: { v in if let i = self.state.index(id) { self.state.projects[i] = v } }
        )
    }
    func update(_ id: String, _ body: (inout Project) -> Void) {
        guard let i = state.index(id) else { return }
        body(&state.projects[i])
        save()
    }
    func markOpened(_ id: String) {
        if state.settings.lastProjectId != id { state.settings.lastProjectId = id; save() }
    }

    func lockedMsg() { showToast("Counter is locked. Tap 🔒 Locked to unlock.") }

    func changeRows(_ id: String, _ delta: Int) {
        if state.settings.locked { lockedMsg(); return }
        if debounced((delta > 0 ? "inc-" : "dec-") + id, 220) { return }
        guard let i = state.index(id) else { return }
        let r = Engine.changeRows(&state.projects[i], delta, locked: false, pro: isPro)
        if r.changed { save() }
        haptic(r.feedback)
        if r.reachedTarget { showToast("🎉 You reached row \(state.projects[i].rows)!", seconds: 3) }
    }
    func undo(_ id: String) {
        if state.settings.locked { lockedMsg(); return }
        guard let i = state.index(id) else { return }
        if Engine.undo(&state.projects[i]) { save(); haptic(.soft) } else { showToast("Nothing to undo") }
    }
    func changeCounter(_ id: String, counter cid: String, _ dir: Int) {
        if state.settings.locked { lockedMsg(); return }
        if debounced((dir > 0 ? "c-inc" : "c-dec") + cid, 180) { return }
        guard let i = state.index(id) else { return }
        if Engine.changeCounter(&state.projects[i], id: cid, dir, locked: false) { save(); haptic(.normal) }
    }
    func restoreRow(_ id: String, _ row: Int) {
        update(id) { Engine.setRows(&$0, row, why: "Restored from history") }
        showToast("Back to row \(row). Undo is available.")
    }
    func reset(_ id: String) {
        update(id) { Engine.reset(&$0) }
        showToast("Reset. Tap Undo to bring it back.", seconds: 3)
    }
    func toggleLock() {
        state.settings.locked.toggle(); save(); haptic(.soft)
        showToast(state.settings.locked ? "Locked. Taps won’t change the count." : "Unlocked")
    }

    @discardableResult
    func newProject(name: String, craft: String, target: Int?) -> String? {
        guard Engine.canAddProject(count: state.projects.count, pro: isPro) else {
            openPro("More than \(Engine.freeProjectLimit) projects"); return nil
        }
        var p = Project(name: name, craft: craft)
        p.target = target
        Engine.log(&p, "Project created")
        state.projects.append(p)
        state.settings.lastProjectId = p.id
        save()
        return p.id
    }
    func deleteProject(_ id: String) {
        state.projects.removeAll { $0.id == id }
        SharedStore.deleteFile("photo:\(id)"); SharedStore.deleteFile("pattern:\(id)")
        if state.settings.lastProjectId == id { state.settings.lastProjectId = nil }
        save()
        path = []
    }

    func eraseAll() {
        SharedStore.deleteAllFiles()
        var s = AppState()
        s.settings.tipsSeen = true
        let id = Engine.ensureProject(&s)
        state = s
        save()
        path = [.project(id)]
        showToast("All data erased")
    }

    /// rowbin://project/<id> from widgets.
    func open(url: URL) {
        guard url.scheme == "rowbin" else { return }
        let id = url.lastPathComponent
        if state.project(id) != nil { reloadFromDisk(); path = [.project(id)] }
    }

    // MARK: photos
    func setPhoto(_ id: String, data: Data) {
        guard let jpeg = ImageTools.downscaledJPEG(data, maxSide: 1400) else { showToast("Couldn't save that photo."); return }
        do {
            try SharedStore.putFile("photo:\(id)", jpeg)
            update(id) { $0.hasPhoto = true }
            ImageCache.shared.drop("photo:\(id)")
            showToast("Photo saved")
        } catch { showToast("Couldn't save that photo.") }
    }
    func removePhoto(_ id: String) {
        SharedStore.deleteFile("photo:\(id)"); ImageCache.shared.drop("photo:\(id)")
        update(id) { $0.hasPhoto = false }
    }
}

enum ImageTools {
    static func downscaledJPEG(_ data: Data, maxSide: CGFloat) -> Data? {
        guard let img = UIImage(data: data) else { return nil }
        let s = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: (img.size.width * s).rounded(), height: (img.size.height * s).rounded())
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        return out.jpegData(compressionQuality: 0.85)
    }
}

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    func image(_ key: String) -> UIImage? {
        if let i = cache.object(forKey: key as NSString) { return i }
        guard let d = SharedStore.getFile(key), let i = UIImage(data: d) else { return nil }
        cache.setObject(i, forKey: key as NSString)
        return i
    }
    func drop(_ key: String) { cache.removeObject(forKey: key as NSString) }
    func dropAll() { cache.removeAllObjects() }
}
