import Foundation

/// Voice commands are INPUT only: they change the count. Rowbin never reads anything aloud.
/// Pure parser (same rules as Android) so it can be unit tested. English command words for now.
enum VoiceCommands {
    enum Cmd: Equatable { case next, back, undo, stop }
    static let maxPerUtterance = 5
    private static let next: Set = ["next", "plus", "add"]
    private static let back: Set = ["back", "minus", "subtract"]
    private static let undo: Set = ["undo", "oops"]
    private static let stop: Set = ["stop", "pause"]
    /// Common mishearings of the short command words.
    private static let alias: [(String, String)] = [("nest", "next"), ("necks", "next"), ("text", "next"), ("plush", "plus"), ("bag", "back"), ("black", "back"), ("undue", "undo"), ("and do", "undo")]

    /// Commands in the order spoken: "next next" -> [.next, .next]; "next row" counts once; unknown words are ignored.
    static func parse(_ text: String) -> [Cmd] {
        let letters = String(text.lowercased().map { ($0 >= "a" && $0 <= "z") ? $0 : " " })
        var t = " " + letters.split(separator: " ").joined(separator: " ") + " "
        for (k, v) in alias { t = t.replacingOccurrences(of: " \(k) ", with: " \(v) ") }
        let words = t.split(separator: " ").map(String.init)
        if words.contains(where: stop.contains) { return [.stop] }
        var out: [Cmd] = []; var i = 0
        while i < words.count && out.count < maxPerUtterance {
            let w = words[i], nx = i + 1 < words.count ? words[i + 1] : ""
            if undo.contains(w) { out.append(.undo) }
            else if w == "go" && nx == "back" { out.append(.back); i += 1 }
            else if back.contains(w) { out.append(.back); if nx == "row" { i += 1 } }
            else if next.contains(w) { out.append(.next); if nx == "row" { i += 1 } }
            i += 1
        }
        return out
    }
}
