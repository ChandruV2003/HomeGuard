import Foundation

class EventLogManager: ObservableObject {
    @Published var logs: [String] = []
    @Published var suggestedAutomation: AutomationRule?  // Add this line

    func analyzeLogsForAutomation() {
        let logsText = logs.joined(separator: "\n")
        let prompt = """
        Based on the following home automation event logs, only for the lights, suggest an automation rule to turn lights on/off at an optimal time:

        \(logsText)

        Please provide exactly one JSON object, with these fields:
        {
          "uid": "SomeUIDStringOrEmpty",
          "name": "AI Suggested Automation",
          "condition": "Time is 8:00 PM",
          "action": "Turn on living room lights",
          "activeDays": "M,Tu,W,Th,F,Sa,Su",
          "triggerEnabled": true,
          "triggerTime": 0,
          "inputDeviceID": "",
          "outputDeviceID": ""
        }
        No extra text, only the JSON.
        """


        ChatGPTAPI.fetchAutomation(prompt: prompt) { rule, errorMsg in
            DispatchQueue.main.async {
                if let automation = rule {
                    self.suggestedAutomation = automation
                } else if let error = errorMsg {
                    // Handle or log the error as needed, e.g.:
                    print("Failed to fetch AI automation: \(error)")
                    // Optionally set suggestedAutomation to nil if you want to clear any old data:
                    self.suggestedAutomation = nil
                }
            }
        }
    }
    
    func addLog(_ log: String) {
        NetworkManager.fetchSensorData { maybeDict in
            guard let dict = maybeDict, let simTime = dict["simTime"] as? Double else { return }
            let timeString = scaledMillisToString(simTime)
            let final = "[\(timeString)] \(log)"
            DispatchQueue.main.async {
                self.logs.insert(final, at: 0)
            }
        }
    }

    
    func fetchDeviceLogs(completion: @escaping ([String]) -> Void) {
        guard let url = URL(string: "http://\(Config.globalESPIP)/logs") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
           guard let data = data,
                 let arr = try? JSONSerialization.jsonObject(with: data) as? [String]
           else {
              completion([])
              return
           }
           completion(arr)
        }.resume()
    }

}
