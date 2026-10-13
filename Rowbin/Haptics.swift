import UIKit

/// Taptic Engine feedback. Respects the "Vibrate on tap" setting.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notify = UINotificationFeedbackGenerator()

    static func play(_ f: Engine.Feedback, enabled: Bool) {
        guard enabled else { return }
        switch f {
        case .none: break
        case .normal: light.impactOccurred()
        case .soft: soft.impactOccurred(intensity: 0.6)
        case .strong: notify.notificationOccurred(.success)
        }
    }
    static func prepare() { light.prepare(); soft.prepare() }
}
