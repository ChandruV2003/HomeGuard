import Foundation

class EventLogManager: ObservableObject {
    @Published var logs: [String] = []
    @Published var suggestedAutomation: AutomationRule?  // Add this line

    func addLog(_ log: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let entry = "[\(timestamp)] \(log)"
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0)
        }
    }

    func analyzeLogsForAutomation() {
        let logsText = logs.joined(separator: "\n")
        let prompt = """
        Based on the following home automation event logs, only for the lights, suggest an automation rule to turn lights on/off at an optimal time:

        \(logsText)

        Provide the automation in the following JSON format:
        {
            "name": "AI Suggested Automation",
            "condition": "Time is 8:00 PM",
            "action": "Turn on living room lights",
            "activeDays": "M,Tu,W,Th,F,Sa,Su",
            "triggerEnabled": true
        }
        """

        ChatGPTAPI.fetchAutomation(prompt: prompt) { automation in
            DispatchQueue.main.async {
                if let automation = automation {
                    self.suggestedAutomation = automation  // Now it updates correctly
                }
            }
        }
    }
}
