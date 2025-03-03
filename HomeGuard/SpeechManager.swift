import Foundation
import Speech
import AVFoundation

func sendCommand(_ command: String, for deviceIP: String, completion: @escaping (Bool) -> Void = { _ in }) {
    guard let url = URL(string: "http://\(deviceIP)/command?act=\(command)") else {
        completion(false)
        return
    }
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error sending command: \(error.localizedDescription)")
            completion(false)
        } else {
            print("Command \(command) sent successfully to \(deviceIP).")
            completion(true)
        }
    }.resume()
}

class SpeechManager: ObservableObject {
    @Published var recognizedText: String = "Awaiting command..."
    @Published var commandRecognized: Bool = false
    @Published var feedbackMessage: String = ""
    @Published var isListening: Bool = false

    let magicKeywords = ["open", "close", "turn on", "turn off", "change"]

    private var audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func startListening() {
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else {
            print("Unable to create request")
            return
        }
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
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
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                self?.recognizedText = result.bestTranscription.formattedString
                self?.processCommand(result.bestTranscription.formattedString)
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
            sendCommand("lightOn", for: "192.168.1.101") { success in
                DispatchQueue.main.async {
                    self.feedbackMessage = success ? "Lights turned on" : "Failed to turn on lights"
                }
            }
        } else if lowerText.contains("light off") {
            commandSent = true
            sendCommand("lightOff", for: "192.168.1.101") { success in
                DispatchQueue.main.async {
                    self.feedbackMessage = success ? "Lights turned off" : "Failed to turn off lights"
                }
            }
        } else if lowerText.contains("open garage") {
            commandSent = true
            sendCommand("garageOpen", for: "192.168.1.102") { success in
                DispatchQueue.main.async {
                    self.feedbackMessage = success ? "Garage opened" : "Failed to open garage"
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
