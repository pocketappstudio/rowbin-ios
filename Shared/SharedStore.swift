import Foundation

/// State shared between the app and its widgets through the App Group container.
/// Writes are atomic and coordinated so the widget's +1/-1 buttons and the app never clobber each other.
enum SharedStore {
    static let groupID = "group.com.pocketappstudio.rowbin"
    static let proKey = "rowbin.proCached"

    static var container: URL {
        if let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) { return u }
        // Unsigned simulator / test builds have no App Group; fall back to the app's own folder.
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Rowbin", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    static var stateURL: URL { container.appendingPathComponent("rowbin-state.json") }
    static var backupURL: URL { container.appendingPathComponent("rowbin-state.launch-backup.json") }
    static var filesDir: URL {
        let u = container.appendingPathComponent("files", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }

    static var proCached: Bool {
        get { defaults.bool(forKey: proKey) }
        set { defaults.set(newValue, forKey: proKey) }
    }

    static func decode(_ data: Data) -> AppState? { try? JSONDecoder().decode(AppState.self, from: data) }
    static func encode(_ s: AppState) -> Data? { try? JSONEncoder().encode(s) }

    static func load() -> AppState {
        var result: AppState? = nil
        coordinate(write: false) { url in
            if let d = try? Data(contentsOf: url) { result = decode(d) }
        }
        if result == nil, let d = try? Data(contentsOf: backupURL) { result = decode(d) }
        return result ?? AppState()
    }

    @discardableResult
    static func save(_ s: AppState) -> Bool {
        guard let data = encode(s) else { return false }
        var ok = false
        coordinate(write: true) { url in
            do { try data.write(to: url, options: [.atomic]); ok = true } catch { ok = false }
        }
        return ok
    }

    /// Keeps a last-known-good copy (like the web app's launch backup).
    static func writeLaunchBackup(_ s: AppState) {
        if let d = encode(s) { try? d.write(to: backupURL, options: [.atomic]) }
    }

    /// Read-modify-write under one coordinated write, used by widget buttons.
    static func mutate(_ body: (inout AppState) -> Void) {
        coordinate(write: true) { url in
            var s = (try? Data(contentsOf: url)).flatMap(decode) ?? AppState()
            body(&s)
            if let d = encode(s) { try? d.write(to: url, options: [.atomic]) }
        }
    }

    private static func coordinate(write: Bool, _ body: (URL) -> Void) {
        let c = NSFileCoordinator(filePresenter: nil)
        var err: NSError?
        if write {
            c.coordinate(writingItemAt: stateURL, options: [], error: &err) { body($0) }
        } else {
            c.coordinate(readingItemAt: stateURL, options: [], error: &err) { body($0) }
        }
        if err != nil { body(stateURL) }
    }

    // MARK: files (photos, patterns). Keys match the web backup: "photo:<id>", "pattern:<id>".
    static func fileURL(_ key: String) -> URL {
        filesDir.appendingPathComponent(key.replacingOccurrences(of: ":", with: "_"))
    }
    static func fileKeys() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: filesDir.path)) ?? []
        return names.compactMap { n -> String? in
            for p in ["photo_", "pattern_", "jphoto_"] where n.hasPrefix(p) { return String(p.dropLast()) + ":" + String(n.dropFirst(p.count)) }
            return nil
        }
    }
    static func putFile(_ key: String, _ data: Data) throws { try data.write(to: fileURL(key), options: [.atomic]) }
    static func getFile(_ key: String) -> Data? { try? Data(contentsOf: fileURL(key)) }
    static func deleteFile(_ key: String) { try? FileManager.default.removeItem(at: fileURL(key)) }
    static func deleteAllFiles() { for k in fileKeys() { deleteFile(k) } }
}
