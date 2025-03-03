import Foundation

class EventLogManager: ObservableObject {
    @Published var logs: [String] = []
    
    func addLog(_ log: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let entry = "[\(timestamp)] \(log)"
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0)
        }
    }
}
