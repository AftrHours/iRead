import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechSearchSvc {
    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: .current)
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInstalledTap = false

    func start(onTranscript: @escaping @MainActor (String) -> Void,
               onFailure: @escaping @MainActor (String) -> Void,
               onFinished: @escaping @MainActor () -> Void) async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            throw SpeechSearchError.permissionDenied("Allow Speech Recognition in Settings to search by voice.")
        }
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechSearchError.permissionDenied("Speech recognition is unavailable right now.")
        }

        let microphoneAllowed = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard microphoneAllowed else {
            throw SpeechSearchError.permissionDenied("Allow microphone access in Settings to search by voice.")
        }

        stop()
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request

            let inputNode = audioEngine.inputNode
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputNode.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            hasInstalledTap = true
            audioEngine.prepare()
            try audioEngine.start()

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let result {
                    let transcript = result.bestTranscription.formattedString
                    Task { @MainActor in onTranscript(transcript) }
                }
                if let error {
                    Task { @MainActor in
                        self?.stop()
                        onFailure(error.localizedDescription)
                        onFinished()
                    }
                } else if result?.isFinal == true {
                    Task { @MainActor in
                        self?.stop()
                        onFinished()
                    }
                }
            }
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if audioEngine.isRunning { audioEngine.stop() }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        request?.endAudio()
        recognitionTask?.cancel()
        request = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private enum SpeechSearchError: LocalizedError {
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message): message
        }
    }
}
