import SwiftUI
import Speech
import AVFoundation

/// Voice counting (Pro): listens for a few command words with Apple's ON-DEVICE speech recognition only.
/// - `requiresOnDeviceRecognition = true` on every request, and only when `supportsOnDeviceRecognition` is true.
///   There is no fallback to server recognition: if on-device isn't supported, the feature shows as unavailable.
/// - Input only. Nothing is ever read aloud, and audio and transcripts are never stored or sent anywhere.
/// - Stops when the screen goes away, when the app leaves the foreground, on "stop", and after 10 minutes without a command.
@MainActor
final class VoiceCounter: ObservableObject {
    enum State: Equatable { case off, starting, listening, heard(String), unavailable(String), error(String) }
    static let idleSeconds: TimeInterval = 10 * 60
    static let locale = Locale(identifier: "en-US")

    @Published private(set) var state: State = .off
    var isOn: Bool { switch state { case .starting, .listening, .heard: return true; default: return false } }

    var onCommand: (VoiceCommands.Cmd) -> Void = { _ in }

    private let recognizer = SFSpeechRecognizer(locale: VoiceCounter.locale)
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest? { didSet { box.set(request) } }
    private let box = RequestBox()
    private var task: SFSpeechRecognitionTask?
    private var handled = 0
    private var lastCommandAt = Date()
    private var idleTimer: Timer?
    private var errors = 0

    /// nil when on-device recognition can be used; otherwise the reason it can't.
    static func unavailableReason() -> String? {
        guard let r = SFSpeechRecognizer(locale: locale) else { return "Voice counting needs English speech recognition, which isn’t available on this device." }
        if !r.supportsOnDeviceRecognition { return "On-device speech recognition isn’t available on this device, so voice counting is off. Rowbin never uses online recognition." }
        return nil
    }
    static var permissionsGranted: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized && AVAudioApplication.shared.recordPermission == .granted
    }

    /// Asks for speech recognition and microphone permission (call after the explainer), then starts.
    func requestPermissionsAndStart() {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else { self.state = .error("Voice counting needs Speech Recognition. You can allow it in Settings → Rowbin."); return }
                AVAudioApplication.requestRecordPermission { ok in
                    Task { @MainActor in
                        if ok { self.start() } else { self.state = .error("Voice counting needs the microphone. You can allow it in Settings → Rowbin.") }
                    }
                }
            }
        }
    }

    func start() {
        if let why = VoiceCounter.unavailableReason() { state = .unavailable(why); return }
        guard VoiceCounter.permissionsGranted else { state = .error("Voice counting needs microphone and speech permission."); return }
        state = .starting; errors = 0; lastCommandAt = Date()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let input = engine.inputNode
            input.removeTap(onBus: 0)
            let box = self.box
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buf, _ in
                box.append(buf)   // audio thread
            }
            engine.prepare()
            try engine.start()
            beginTask()
            idleTimer?.invalidate()
            idleTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.checkIdle() }
            }
        } catch {
            fail("Voice counting couldn’t start. Try again.")
        }
    }

    private func beginTask() {
        guard let recognizer else { fail("Speech recognition isn’t available."); return }
        task?.cancel()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.requiresOnDeviceRecognition = true      // never send audio to a server
        req.shouldReportPartialResults = true
        req.taskHint = .confirmation
        req.contextualStrings = ["next", "plus", "add", "back", "minus", "go back", "undo", "stop"]
        request = req; handled = 0
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal ?? false
            Task { @MainActor in self?.handle(text: text, final: final, error: error) }
        }
        if state == .starting { state = .listening }
    }

    private func handle(text: String?, final: Bool, error: Error?) {
        guard isOn else { return }
        if let text {
            let cmds = VoiceCommands.parse(text)
            if cmds.first == .stop { stop(); onCommand(.stop); return }
            if cmds.count > handled {
                for c in cmds[handled...] { onCommand(c) }
                handled = cmds.count; lastCommandAt = Date(); errors = 0
                state = .heard(text.split(separator: " ").suffix(3).joined(separator: " "))
            }
        }
        if final || error != nil {
            if error != nil { errors += 1 }
            if errors >= 5 { fail("Voice counting stopped after repeated errors. Tap 🎙 Voice to try again."); return }
            request?.endAudio()
            beginTask()   // keep listening with a fresh request (still on-device only)
        }
    }

    private func checkIdle() {
        if isOn && Date().timeIntervalSince(lastCommandAt) > VoiceCounter.idleSeconds { stop() }
    }

    func stop() { teardown(); state = .off }
    private func fail(_ msg: String) { teardown(); state = .error(msg) }
    private func teardown() {
        idleTimer?.invalidate(); idleTimer = nil
        task?.cancel(); task = nil
        request?.endAudio(); request = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Hands audio buffers from the audio thread to the current request.
final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var req: SFSpeechAudioBufferRecognitionRequest?
    func set(_ r: SFSpeechAudioBufferRecognitionRequest?) { lock.lock(); req = r; lock.unlock() }
    func append(_ b: AVAudioPCMBuffer) { lock.lock(); let r = req; lock.unlock(); r?.append(b) }
}

/// Wires a voice session to a screen: counts with the model and stops on disappear or background.
struct VoiceSession: ViewModifier {
    @EnvironmentObject var model: AppModel
    @ObservedObject var voice: VoiceCounter
    let projectID: String
    @Environment(\.scenePhase) private var phase
    func body(content: Content) -> some View {
        content
            .onAppear {
                voice.onCommand = { [weak model] c in
                    guard let model else { return }
                    switch c {
                    case .next: model.changeRows(projectID, 1, fromVoice: true)
                    case .back: model.changeRows(projectID, -1, fromVoice: true)
                    case .undo: model.undo(projectID)
                    case .stop: model.haptic(.soft); model.showToast("Voice counting off")
                    }
                }
            }
            .onDisappear { voice.stop() }
            .onChange(of: phase) { _, p in if p != .active { voice.stop() } }
    }
}

/// The "🎙 Voice" chip (Pro), with an explainer before the system permission prompts.
struct VoiceChip: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var voice: VoiceCounter
    @State private var explain = false
    var body: some View {
        Chip(on: voice.isOn, label: voice.isOn ? "🎙 Voice on" : "🎙 Voice", pro: true) {
            if !model.isPro { model.openPro("Voice counting"); return }
            if voice.isOn { voice.stop(); return }
            if let why = VoiceCounter.unavailableReason() { model.showToast(why, seconds: 4); return }
            if VoiceCounter.permissionsGranted { voice.start() } else { explain = true }
        }
        .onAppear {
            #if DEBUG
            if Demo.screen == "voice" { explain = true }
            #endif
        }
        .alert("Count with your voice", isPresented: $explain) {
            Button("Not now", role: .cancel) {}
            Button("Continue") { voice.requestPermissionsAndStart() }
        } message: {
            Text("Say “next” or “plus” to add a row, “back” or “minus” to subtract one, “undo” to undo, and “stop” to turn listening off.\n\nRowbin uses your iPhone’s on-device speech recognition only. Your voice is processed on this device, isn’t recorded or saved, and is never sent anywhere by Rowbin. iOS will ask for microphone and speech recognition permission.")
        }
    }
}

/// Status line shown while voice is in use (or when it needs attention).
struct VoiceStatus: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var voice: VoiceCounter
    var body: some View {
        let t = model.theme
        let text: String? = {
            switch voice.state {
            case .off: return nil
            case .starting: return "🎙 Starting…"
            case .listening: return "🎙 Listening. Say “next”, “back” or “undo”."
            case .heard(let s): return "🎙 Heard “\(s)”. Listening."
            case .unavailable(let r), .error(let r): return r
            }
        }()
        if let text {
            HStack(spacing: 10) {
                Text(text).font(.callout.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
                if voice.isOn { Button("Stop") { voice.stop() } }
                else if case .error = voice.state { Button("Try again") { voice.start() } }
                else { Button { voice.stop() } label: { Image(systemName: "xmark") }.accessibilityLabel("Dismiss") }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14).fill(t.card))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}
