import Foundation
import Speech
import AVFoundation
import SwiftUI  // for Color, if needed

class SpeechManager: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var commandRecognized: Bool = false
    @Published var feedbackMessage: String = ""
    @Published var isListening: Bool = false
    
    // NEW: The colored text we’ll display in the UI with highlights
    @Published var recognizedAttributed: AttributedString = AttributedString("")
    
    // The DashboardView will assign its own logManager to this property
    var logManager: EventLogManager?
    
    // Device + automation lists
    @Published var currentDevices: [Device] = []
    @Published var currentAutomations: [AutomationRule] = []
    
    // Known action phrases
    let actionKeywords = ["turn on", "turn off", "open", "close", "change"]
    
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
                // Update colored text after each partial or final result
                self.styleRecognizedText(self.recognizedText)
                
                if result.isFinal {
                    print("Final transcription: \(self.recognizedText)")
                    self.processCommand(self.recognizedText)
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
    
    /// Called for final text
    func processCommand(_ text: String) {
        let lowerText = text.lowercased()
        var commandProcessed = false
        
        // Check each device
        for device in currentDevices {
            let deviceName = device.name.lowercased()
            if lowerText.contains(deviceName) {
                if lowerText.contains("turn on") {
                    NetworkManager.sendCommand(port: device.port, action: "on") { _ in }
                    logManager?.addLog("\(device.name) turned on via voice")
                    commandProcessed = true
                }
                else if lowerText.contains("turn off") {
                    NetworkManager.sendCommand(port: device.port, action: "off") { _ in }
                    logManager?.addLog("\(device.name) turned off via voice")
                    commandProcessed = true
                }
                // expand: open, close, etc.
            }
        }
        // --- Branch for garage door commands ---
            if lowerText.contains("garage door") {
                // If the user says "open garage door" or "close garage door"
                if lowerText.contains("open") {
                    NetworkManager.sendCommand(port: "GPIO14", action: "open") { _ in }
                    logManager?.addLog("Garage door servo opened via voice")
                    commandProcessed = true
                } else if lowerText.contains("close") {
                    NetworkManager.sendCommand(port: "GPIO14", action: "close") { _ in }
                    logManager?.addLog("Garage door servo closed via voice")
                    commandProcessed = true
                }
            }
            
            // --- Loop through known devices for "turn on"/"turn off" commands ---
            for device in currentDevices {
                let deviceName = device.name.lowercased()
                if lowerText.contains(deviceName) {
                    if lowerText.contains("turn on") {
                        NetworkManager.sendCommand(port: device.port, action: "on") { _ in }
                        logManager?.addLog("\(device.name) turned on via voice")
                        commandProcessed = true
                    }
                    else if lowerText.contains("turn off") {
                        NetworkManager.sendCommand(port: device.port, action: "off") { _ in }
                        logManager?.addLog("\(device.name) turned off via voice")
                        commandProcessed = true
                    }
                }
            }
        
        if commandProcessed {
            DispatchQueue.main.async {
                self.commandRecognized = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.commandRecognized = false
                self.feedbackMessage = ""
                self.recognizedText = ""
                // If you want to also clear the colored text:
                self.recognizedAttributed = AttributedString("")
            }
        }
    }
    
    // MARK: - Coloring / styling recognized text in real-time
    /// Simple logic:
    /// - If we see an action phrase but no recognized device => highlight the phrase in ORANGE
    /// - If we see an action phrase + known device => highlight them in GREEN
    /// - Otherwise => highlight the entire text in RED
    private func styleRecognizedText(_ rawText: String) {
        // By default color entire text red
        var attString = AttributedString(rawText)
        attString.foregroundColor = .red
        
        let lowerText = rawText.lowercased()
        
        // 1) Check if user said an action phrase:
        var foundAction = false
        for keyword in actionKeywords {
            if lowerText.contains(keyword) {
                // highlight just that substring in orange initially
                if let range = attString.range(of: keyword, options: .caseInsensitive) {
                    attString[range].foregroundColor = .orange
                }
                foundAction = true
            }
        }
        
        // 2) Check if user said a device name
        var foundDevice: String? = nil
        for device in currentDevices {
            let devNameLower = device.name.lowercased()
            if lowerText.contains(devNameLower) {
                foundDevice = devNameLower
                // highlight that substring in orange or green
                if let range = attString.range(of: devNameLower, options: .caseInsensitive) {
                    attString[range].foregroundColor = .orange
                }
            }
        }
        
        // 3) If we have an action word AND a device, turn them BOTH green
        if foundAction, let dev = foundDevice {
            // highlight the action phrase green
            for keyword in actionKeywords {
                if lowerText.contains(keyword) {
                    if let range = attString.range(of: keyword, options: .caseInsensitive) {
                        attString[range].foregroundColor = .green
                    }
                }
            }
            // highlight the device green
            if let deviceRange = attString.range(of: dev, options: .caseInsensitive) {
                attString[deviceRange].foregroundColor = .green
            }
        }
        
        // 4) If we found an action but no recognized device => that action is orange
        //    If we found neither => everything remains red
        //    If we found both => we made them green above
        
        // Assign final result
        DispatchQueue.main.async {
            self.recognizedAttributed = attString
        }
    }
}
