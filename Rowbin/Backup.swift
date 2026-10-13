import SwiftUI
import UniformTypeIdentifiers

/// Backup export/import in the same JSON format as the web app (and Android).
enum Backup {
    static func fileName(_ d: Date = Date()) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return "rowbin-backup-\(f.string(from: d)).json"
    }
    static func iso(_ d: Date = Date()) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }
    static func parseISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
    static func mime(for key: String, data: Data) -> String {
        if data.starts(with: [0x25, 0x50, 0x44, 0x46]) { return "application/pdf" }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        return "image/jpeg"
    }

    static func make(state: AppState, includeFiles: Bool) -> Data? {
        var files: [String: String] = [:]
        if includeFiles {
            for k in SharedStore.fileKeys() {
                if let d = SharedStore.getFile(k) { files[k] = "data:\(mime(for: k, data: d));base64,\(d.base64EncodedString())" }
            }
        }
        return try? JSONEncoder().encode(BackupFile(state: state, files: files, exportedAt: iso()))
    }

    enum ParseError: Error { case notRowbin }
    static func parse(_ data: Data) throws -> BackupFile {
        guard let b = try? JSONDecoder().decode(BackupFile.self, from: data), b.app == "rowbin" else { throw ParseError.notRowbin }
        return b
    }
    static func decodeDataURL(_ s: String) -> Data? {
        guard let comma = s.firstIndex(of: ",") else { return nil }
        return Data(base64Encoded: String(s[s.index(after: comma)...]), options: .ignoreUnknownCharacters)
    }

    /// Replaces everything on this phone. Pro is never carried by a backup (it comes from the App Store).
    static func apply(_ b: BackupFile, to current: AppState) throws -> AppState {
        var next = b.state
        next.settings.tipsSeen = true
        var decoded: [String: Data] = [:]
        for (k, v) in b.files { if let d = decodeDataURL(v) { decoded[k] = d } }
        SharedStore.deleteAllFiles()
        for (k, d) in decoded { try SharedStore.putFile(k, d) }
        ImageCache.shared.dropAll()
        return next
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
