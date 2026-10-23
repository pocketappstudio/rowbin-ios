import AVFoundation
import UIKit

/// Says the count out loud with the device's built-in speech voices (AVSpeechSynthesizer runs on the device;
/// nothing is sent anywhere). When VoiceOver is on, Rowbin hands the text to VoiceOver instead so it isn't read twice.
@MainActor
final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()
    private init() { synth.usesApplicationAudioSession = false }

    func say(_ text: String) {
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: NSAttributedString(string: text, attributes: [.accessibilitySpeechQueueAnnouncement: false]))
            return
        }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        u.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        synth.speak(u)
    }
    func stop() { if synth.isSpeaking { synth.stopSpeaking(at: .immediate) } }
}
