import Foundation
import Speech
import AVFoundation

class SpeechManager: ObservableObject {
    @Published var recognizedText: String = "Awaiting command..."
    @Published var commandRecognized: Bool = false
    @Published var feedbackMessage: String = ""
    @Published var isListening: Bool = false

    let magicKeywords = ["open", "close", "turn on", "turn off", "change"]

    private var audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func startListening() {
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else {
            print("Unable to create request")
            return
        }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
        audioEngine = AVAudioEngine()
        let node = audioEngine.inputNode
        let recordingFormat = node.inputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed: \(error.localizedDescription)")
        }
        isListening = true
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result = result, let transcription = result.bestTranscription.formattedString as String? {
                self?.recognizedText = transcription
                self?.processCommand(transcription)
            }
            if let error = error {
                print("Recognition error: \(error.localizedDescription)")
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        recognizedText = "Awaiting command..."
        isListening = false
    }

    private func processCommand(_ text: String) {
        let lowerText = text.lowercased()
        var commandSent = false

        if lowerText.contains("light on") {
            commandSent = true
            NetworkManager.sendCommand(port: "D1", action: "lightOn") { state in
                DispatchQueue.main.async {
                    if let state = state {
                        self.feedbackMessage = "Lights turned \(state)"
                    } else {
                        self.feedbackMessage = "Failed to turn on lights"
                    }
                }
            }
        } else if lowerText.contains("light off") {
            commandSent = true
            NetworkManager.sendCommand(port: "D1", action: "lightOff") { state in
                DispatchQueue.main.async {
                    if let state = state {
                        self.feedbackMessage = "Lights turned \(state)"
                    } else {
                        self.feedbackMessage = "Failed to turn off lights"
                    }
                }
            }
        } else if lowerText.contains("open garage") {
            commandSent = true
            NetworkManager.sendCommand(port: "D4", action: "garageOpen") { state in
                DispatchQueue.main.async {
                    if let state = state {
                        self.feedbackMessage = "Garage \(state)"
                    } else {
                        self.feedbackMessage = "Failed to open garage"
                    }
                }
            }
        }

        if commandSent {
            DispatchQueue.main.async {
                self.commandRecognized = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.commandRecognized = false
                self.feedbackMessage = ""
                self.stopListening()
            }
        }
    }
}
