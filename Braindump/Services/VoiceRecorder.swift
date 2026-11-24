import Foundation
import Speech
import AVFoundation

@MainActor
final class VoiceRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recordingRequestID: UUID?

    func toggle() {
        if isRecording {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard recordingRequestID == nil else { return }
        let requestID = UUID()
        recordingRequestID = requestID
        transcript = ""
        errorMessage = nil

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self, self.recordingRequestID == requestID else { return }
                guard status == .authorized else {
                    self.errorMessage = "Speech recognition isn't authorized."
                    self.recordingRequestID = nil
                    return
                }
                await self.beginRecording(requestID: requestID)
            }
        }
    }

    private func beginRecording(requestID: UUID) async {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now."
            recordingRequestID = nil
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            errorMessage = "On-device dictation isn't available. You can type your moment instead."
            recordingRequestID = nil
            return
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard recordingRequestID == requestID else { return }
        guard micGranted else {
            errorMessage = "Microphone access is needed to dictate."
            recordingRequestID = nil
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Couldn't start the audio session."
            recordingRequestID = nil
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Couldn't start the microphone."
            recordingRequestID = nil
            self.request = nil
            inputNode.removeTap(onBus: 0)
            do {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                errorMessage = "Couldn't release the audio session: \(error.localizedDescription)"
            }
            return
        }

        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard self?.recordingRequestID == requestID else { return }
                if let result {
                    self?.transcript = result.bestTranscription.formattedString
                }
                if let error {
                    self?.errorMessage = "Dictation stopped: \(error.localizedDescription)"
                    self?.stop()
                } else if result?.isFinal == true {
                    self?.stop()
                }
            }
        }
    }

    func stop() {
        recordingRequestID = nil
        guard isRecording || audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        isRecording = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Couldn't release the audio session: \(error.localizedDescription)"
        }
    }
}
