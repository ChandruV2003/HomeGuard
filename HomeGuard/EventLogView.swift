import SwiftUI

struct EventLogView: View {
    @ObservedObject var logManager: EventLogManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(logManager.logs, id: \.self) { log in
                    Text(log)
                        .font(.caption)
                }
            }
            .navigationTitle("Event Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EventLogView_Previews: PreviewProvider {
    static var previews: some View {
        let logManager = EventLogManager()
        logManager.logs = ["[12/12/2024 10:00 AM] Living Room Lights turned On"]
        return EventLogView(logManager: logManager)
    }
}
