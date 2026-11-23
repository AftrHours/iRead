import AVFoundation
@preconcurrency import Speech

@MainActor
final class LibrarySpeechSearch {
    enum Failure: LocalizedError {
        case permission, unavailable

        var errorDescription: String? {
            switch self {
            case .permission: "Allow microphone and speech recognition access in Settings to search by voice. You can also type your search."
            case .unavailable: "Voice search is unavailable right now. You can still search by typing."
            }
        }
    }

    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var sessionActive = false

    func start(onUpdate: @escaping @MainActor @Sendable (String?, Bool, Bool) -> Void) async throws {
        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in continuation.resume(returning: status) }
        }
        try Task.checkCancellation()
        guard authorization == .authorized, await AVAudioApplication.requestRecordPermission() else {
            throw Failure.permission
        }
        try Task.checkCancellation()
        guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable else { throw Failure.unavailable }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)
        sessionActive = true
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard session.isInputAvailable, format.sampleRate > 0, format.channelCount > 0 else { throw Failure.unavailable }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .search
        self.recognizer = recognizer
        self.request = request
        self.engine = engine
        input.installTap(onBus: 0, bufferSize: 1024, format: nil) { @Sendable buffer, _ in
            request.append(buffer)
        }
        try engine.start()
        recognition = recognizer.recognitionTask(with: request) { @Sendable result, error in
            let text = result?.bestTranscription.formattedString
            let finished = result?.isFinal == true
            let failed = error != nil
            Task { @MainActor in onUpdate(text, finished, failed) }
        }
    }

    func stop() {
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        request?.endAudio()
        recognition?.cancel()
        recognition = nil
        request = nil
        recognizer = nil
        if sessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActive = false
        }
    }
}
