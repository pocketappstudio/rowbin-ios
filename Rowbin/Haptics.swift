import UIKit

/// Taptic Engine feedback. Respects the "Vibrate on tap" setting.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
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

    /// Eyes-free milestones, each one easy to tell apart by feel:
    /// every 5th row = one firm tap, every 10th = two heavy taps, a finished repeat = three quick taps.
    static func milestone(_ m: Milestone, enabled: Bool) {
        guard enabled else { return }
        switch m {
        case .none: light.impactOccurred()
        case .five: medium.impactOccurred(intensity: 1)
        case .ten:
            heavy.impactOccurred(intensity: 1)
            after(0.18) { heavy.impactOccurred(intensity: 1) }
        case .repeatDone:
            rigid.impactOccurred(intensity: 1)
            after(0.14) { rigid.impactOccurred(intensity: 1) }
            after(0.28) { rigid.impactOccurred(intensity: 1) }
        }
    }
    private static func after(_ s: Double, _ body: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + s) { MainActor.assumeIsolated { body() } }
    }
    static func prepare() { light.prepare(); soft.prepare(); medium.prepare(); heavy.prepare(); rigid.prepare() }
}
