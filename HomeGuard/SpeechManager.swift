import Foundation
import Speech
import AVFoundation

class SpeechManager: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var commandRecognized: Bool = false
    @Published var feedbackMessage: String = ""
    @Published var isListening: Bool = false
    
    // Dynamic lists (updated by DashboardView via onChange)
    @Published var currentDevices: [Device] = []
    @Published var currentAutomations: [AutomationRule] = []
    
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
            guard let self = self else { return }
            if let result = result {
                self.recognizedText = result.bestTranscription.formattedString
                if result.isFinal {
                    print("Final transcription: \(self.recognizedText)")
                    self.processCommand(self.recognizedText)
                    // Use a longer delay (e.g., 1.0 second) to allow final processing.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if self.audioEngine.isRunning {
                            self.stopListening()
                        }
                    }
                }
            }
            if let error = error {
                let nsError = error as NSError
                if nsError.domain == "com.apple.SFSpeechRecognitionErrorDomain" && nsError.code == 216 {
                    print("Recognition request was canceled.")
                } else if nsError.localizedDescription.contains("No speech detected") && !self.recognizedText.isEmpty {
                    // Valid final transcription exists, so ignore this error.
                } else {
                    print("Recognition error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        recognizedText = "" // Clear the preview text here if desired.
        isListening = false
    }
    
    /// Evaluates the final recognized text and posts a notification if a command is found.
    func processCommand(_ text: String) {
        let lowerText = text.lowercased()
        var command: String? = nil
        
        // Example matching: Use flexible matching with keywords.
        if lowerText.contains("turn on") && lowerText.contains("light") {
            command = "turn on light"
        } else if lowerText.contains("turn off") && lowerText.contains("light") {
            command = "turn off light"
        } else if lowerText.contains("open") && lowerText.contains("garage") {
            command = "open garage"
        }
        // Add more conditions as needed.
        
        if let command = command {
            DispatchQueue.main.async {
                self.commandRecognized = true
            }
            NotificationCenter.default.post(name: .voiceCommandReceived,
                                            object: nil,
                                            userInfo: ["command": command, "fullText": text])
            
            // Reset feedback and clear recognizedText after a short delay.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.commandRecognized = false
                self.feedbackMessage = ""
                self.recognizedText = ""  // Clear the preview area
            }
        }
    }
}
