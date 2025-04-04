import Foundation
import Speech
import AVFoundation

class SpeechManager: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var commandRecognized: Bool = false
    @Published var feedbackMessage: String = ""
    @Published var isListening: Bool = false
    
    // Updated lists – DashboardView sets these so we know the available devices/automations.
    @Published var currentDevices: [Device] = []
    @Published var currentAutomations: [AutomationRule] = []
    
    // Define keywords that can be expanded later.
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
                    // Stop listening immediately once the final transcription is available.
                    self.stopListening()
                }
            }
            if let error = error {
                let nsError = error as NSError
                if nsError.domain == "com.apple.SFSpeechRecognitionErrorDomain" && nsError.code == 216 {
                    print("Recognition request was canceled.")
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
        isListening = false
    }
    
    /// Updated processCommand: now it iterates over currentDevices.
    /// If the recognized text contains a device's (lowercased) name along with “turn on” or “turn off”
    /// then it sends the corresponding command.
    func processCommand(_ text: String) {
        let lowerText = text.lowercased()
        var commandProcessed = false
        
        // Loop over each output device in currentDevices
        for device in currentDevices {
            let deviceName = device.name.lowercased()
            if lowerText.contains(deviceName) {
                if lowerText.contains("turn on") {
                    // Send command to turn device on
                    NetworkManager.sendCommand(port: device.port, action: "on") { state in
                        DispatchQueue.main.async {
                            // You may update state here or rely on a subsequent sync.
                        }
                    }
                    logManager.addLog("\(device.name) turned on via voice")
                    commandProcessed = true
                } else if lowerText.contains("turn off") {
                    NetworkManager.sendCommand(port: device.port, action: "off") { state in
                        DispatchQueue.main.async {
                            // Update state as needed.
                        }
                    }
                    logManager.addLog("\(device.name) turned off via voice")
                    commandProcessed = true
                }
            }
        }
        
        if commandProcessed {
            DispatchQueue.main.async {
                self.commandRecognized = true
            }
            // Clear after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.commandRecognized = false
                self.feedbackMessage = ""
                self.recognizedText = ""
            }
        }
    }
    
    // For logging from processCommand (requires access to logManager)
    private var logManager: EventLogManager {
        // In a real app you might inject this via dependency injection.
        // For now, assume a shared instance or create one if needed.
        return EventLogManager()
    }
}
