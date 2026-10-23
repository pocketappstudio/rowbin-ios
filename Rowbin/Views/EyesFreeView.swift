import SwiftUI

/// Full-screen eyes-free counting (free). Tap anywhere to add a row, swipe left to take one away,
/// swipe down to undo. Different haptics at every 5th row, every 10th row and when a repeat finishes.
/// With VoiceOver: swipe up or down on the counter to add or subtract, two-finger double-tap adds a row,
/// and the scrub gesture (two-finger Z) closes the screen.
struct EyesFreeView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let projectID: String

    var p: Project { model.state.project(projectID) ?? Project() }
    var locked: Bool { model.state.settings.locked }

    var body: some View {
        let t = model.theme
        GeometryReader { geo in
            let big = min(geo.size.width, geo.size.height) * 0.55
            VStack(spacing: 0) {
                HStack {
                    Button { model.state.settings.speakCount.toggle(); model.save()
                        if model.state.settings.speakCount { Speaker.shared.say("Speaking the count") }
                    } label: {
                        Label(model.state.settings.speakCount ? "Speak count: on" : "Speak count: off",
                              systemImage: model.state.settings.speakCount ? "speaker.wave.2.fill" : "speaker.slash")
                            .font(.headline).padding(.horizontal, 16).frame(minHeight: 52)
                            .background(Capsule().fill(t.card))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Speak the count")
                    .accessibilityValue(model.state.settings.speakCount ? "On" : "Off")
                    Spacer()
                    Button { dismiss() } label: {
                        Text("Done").font(.headline).padding(.horizontal, 22).frame(minHeight: 52)
                            .background(Capsule().fill(t.accent)).foregroundStyle(t.onAccent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Leave eyes-free counting")
                }
                .padding(.horizontal, 20).padding(.top, 8)

                Spacer(minLength: 0)
                counterSurface(t, big: big)
                Spacer(minLength: 0)

                Text(locked ? "🔒 Locked. Unlock on the counter screen to count."
                     : "Tap anywhere to add a row · Swipe left to subtract · Swipe down to undo")
                    .font(.title3.weight(.semibold)).multilineTextAlignment(.center).foregroundStyle(t.muted)
                    .padding(.horizontal, 24).padding(.bottom, 28)
                    .accessibilityHidden(true)
            }
        }
        .background(t.background.ignoresSafeArea())
        .foregroundStyle(t.text)
        .onAppear { Haptics.prepare(); UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { Speaker.shared.stop(); UIApplication.shared.isIdleTimerDisabled = model.state.settings.keepAwake }
        .accessibilityAction(.escape) { dismiss() }
    }

    func counterSurface(_ t: RowbinTheme, big: CGFloat) -> some View {
        let rep = Engine.repeatCounter(p)
        let sts: Int? = model.isPro ? p.shaping.map { ShapingMath.stitches($0, crochet: p.isCrochet, completedRows: p.rows) } : nil
        return VStack(spacing: 8) {
            Text(p.isCrochet ? "ROW / ROUND" : "ROW").font(.title2.weight(.bold)).foregroundStyle(t.muted)
            Text("\(p.rows)")
                .font(.system(size: big, weight: .bold, design: .rounded)).monospacedDigit()
                .minimumScaleFactor(0.3).lineLimit(1)
            if let c = rep, let r = c.resetAt {
                Text("\(c.name): \(c.value) of \(r) · \(plural(c.repeats, "repeat")) done").font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            if let sts { Text("\(sts) stitches").font(.title2.weight(.semibold)) }
            if let line = Engine.targetLine(p) { Text(line).font(.title3).foregroundStyle(t.muted) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { model.eyesFree(projectID, .add) }
        .gesture(DragGesture(minimumDistance: 40).onEnded { v in
            let dx = v.translation.width, dy = v.translation.height
            if abs(dx) > abs(dy) { model.eyesFree(projectID, dx < 0 ? .subtract : .add) }
            else if dy > 0 { model.eyesFree(projectID, .undo) }
        })
        // VoiceOver: one element that is the counter.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(p.isCrochet ? "Row or round counter" : "Row counter")
        .accessibilityValue(voValue(rep: rep, sts: sts))
        .accessibilityHint(locked ? "Locked" : "Swipe up to add a row, swipe down to subtract. Two-finger double-tap also adds a row.")
        .accessibilityAdjustableAction { d in
            switch d {
            case .increment: model.eyesFree(projectID, .add)
            case .decrement: model.eyesFree(projectID, .subtract)
            @unknown default: break
            }
        }
        .accessibilityAction(.magicTap) { model.eyesFree(projectID, .add) }
        .accessibilityAction(named: "Undo") { model.eyesFree(projectID, .undo) }
    }

    func voValue(rep: ExtraCounter?, sts: Int?) -> String {
        var s = "Row \(p.rows)"
        if let c = rep, let r = c.resetAt { s += ". \(c.name) \(c.value) of \(r), \(plural(c.repeats, "repeat")) done" }
        if let sts { s += ". \(sts) stitches" }
        return s
    }
}
