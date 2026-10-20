import Foundation

/// Any JSON value. Used to keep keys this version doesn't know about (for example ones added by the
/// Android or web app) so they survive a save or a backup round trip through iPhone.
enum JSONValue: Codable, Equatable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    func encode(to e: Encoder) throws {
        var c = e.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

struct AnyKey: CodingKey {
    var stringValue: String; var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

enum Extras {
    /// Every key in the object that isn't in `known`.
    static func read(_ d: Decoder, known: [String]) -> [String: JSONValue] {
        guard let c = try? d.container(keyedBy: AnyKey.self) else { return [:] }
        var out: [String: JSONValue] = [:]
        for k in c.allKeys where !known.contains(k.stringValue) {
            if let v = try? c.decode(JSONValue.self, forKey: k) { out[k.stringValue] = v }
        }
        return out
    }
    static func write(_ extras: [String: JSONValue], to e: Encoder, known: [String]) throws {
        guard !extras.isEmpty else { return }
        var c = e.container(keyedBy: AnyKey.self)
        for (k, v) in extras where !known.contains(k) { try c.encode(v, forKey: AnyKey(k)) }
    }
}
