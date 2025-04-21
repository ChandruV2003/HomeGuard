// EventLogManager.swift

import Foundation

class EventLogManager: ObservableObject {
    @Published var logs: [String] = []
    @Published var suggestedAutomation: AutomationRule?

    /// Called by your PowerButton & SpeechManager to record a UI‑driven event
    func addLog(_ log: String) {
        NetworkManager.fetchSensorData { maybeDict in
            guard let dict = maybeDict,
                  let simTime = dict["simTime"] as? Double
            else { return }
            let timeString = scaledMillisToString(simTime)
            let entry = "[\(timeString)] \(log)"
            DispatchQueue.main.async {
                self.logs.insert(entry, at: 0)
            }
        }
    }

    /// Fetches `/logs` **with** token+TOTP
    func fetchDeviceLogs(completion: @escaping ([String]) -> Void) {
        var comp = URLComponents(string: "http://\(Config.globalESPIP)/logs")!
        comp.queryItems = NetworkManager.authItems()
        URLSession.shared.dataTask(with: comp.url!) { data, _, _ in
            guard
                let data = data,
                let arr = try? JSONSerialization.jsonObject(with: data) as? [String]
            else {
                completion([])
                return
            }
            completion(arr)
        }
        .resume()
    }

    /// Builds a prompt with both logs + the current device lists,
    /// then asks GPT for exactly one JSON automation rule.
    func analyzeLogsForAutomation(inputDevices: [Device],
                                  outputDevices: [Device]) {
        let logsText = logs.joined(separator: "\n")

        let sensorList = inputDevices
            .map { "- \($0.name) (ID: \($0.id.uuidString))" }
            .joined(separator: "\n")
        let outputList = outputDevices
            .map { "- \($0.name) (ID: \($0.id.uuidString))" }
            .joined(separator: "\n")

        let prompt = """
        You are a home‑automation assistant. Based on these event logs (only for the lights),
        and given these *available* input sensors and output devices, suggest *exactly one*
        new automation rule and output *only* the JSON object—no markdown, no explanation, no extra keys—
        using this schema:

        {
          "uid": "SomeUIDStringOrEmpty",
          "name": "AI Suggested Automation",
          "condition": "Time is 8:00 PM",
          "action": "Turn on living room lights",
          "activeDays": "M,Tu,W,Th,F,Sa,Su",
          "triggerEnabled": true,
          "triggerTime": 0,
          "inputDeviceID": "SENSOR_ID",
          "outputDeviceID": "DEVICE_ID"
        }

        **Available input sensors:**
        \(sensorList)

        **Available output devices:**
        \(outputList)

        **Event logs:**
        \(logsText)
        """

        ChatGPTAPI.fetchAutomation(prompt: prompt) { rule, errorMsg in
            DispatchQueue.main.async {
                if let automation = rule {
                    self.suggestedAutomation = automation
                } else {
                    print("Failed to fetch AI automation: \(errorMsg ?? "unknown error")")
                    self.suggestedAutomation = nil
                }
            }
        }
    }
}
