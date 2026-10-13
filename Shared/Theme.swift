import SwiftUI

struct RowbinTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let accent: Color
    let background: Color
    let card: Color
    let text: Color
    let muted: Color
    let isDark: Bool

    static let all: [RowbinTheme] = [
        .init(id: "oat", name: "Oatmeal", accent: Color(hex: 0xB5523B), background: Color(hex: 0xFBF6EF), card: Color(hex: 0xFFFFFF), text: Color(hex: 0x2E2A26), muted: Color(hex: 0x6B625A), isDark: false),
        .init(id: "night", name: "Night Owl (dark)", accent: Color(hex: 0xE58A6F), background: Color(hex: 0x1B1917), card: Color(hex: 0x26231F), text: Color(hex: 0xF3ECE3), muted: Color(hex: 0xB9AEA2), isDark: true),
        .init(id: "sage", name: "Sage", accent: Color(hex: 0x4F7A5A), background: Color(hex: 0xF2F5EF), card: Color(hex: 0xFFFFFF), text: Color(hex: 0x25302A), muted: Color(hex: 0x5C6B60), isDark: false),
        .init(id: "berry", name: "Berry", accent: Color(hex: 0x9C3D6B), background: Color(hex: 0xFAF3F6), card: Color(hex: 0xFFFFFF), text: Color(hex: 0x33232B), muted: Color(hex: 0x6E5763), isDark: false),
        .init(id: "ocean", name: "Ocean", accent: Color(hex: 0x2F6690), background: Color(hex: 0xF1F5F8), card: Color(hex: 0xFFFFFF), text: Color(hex: 0x1F2B33), muted: Color(hex: 0x56656F), isDark: false)
    ]
    static func by(_ id: String) -> RowbinTheme { all.first { $0.id == id } ?? all[0] }
    static let danger = Color(hex: 0xA23B2C)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
