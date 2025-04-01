import SwiftUI

struct SecuritySettingsView: View {
    @Binding var rule: AutomationRule
    @State private var lcdMessage: String = ""
    @State private var buzzerDuration: Double = 1.0 // seconds
    @State private var showConfirmation: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("LCD Message")) {
                    TextField("Enter LCD message", text: $lcdMessage)
                }
                Section(header: Text("Buzzer Duration (seconds)")) {
                    Slider(value: $buzzerDuration, in: 1...10, step: 1)
                    Text("\(Int(buzzerDuration)) seconds")
                }
                Button("Update Security Settings") {
                    // Update the rule's action to incorporate new settings.
                    rule.action = "Display: \(lcdMessage); Buzzer: \(Int(buzzerDuration))s"
                    // Optionally, call a NetworkManager function to update the ESP32 firmware.
                    NetworkManager.sendSecuritySettings(message: lcdMessage, duration: Int(buzzerDuration)) { success in
                        DispatchQueue.main.async {
                            showConfirmation = success
                        }
                    }
                }
            }
            .navigationTitle("Security Settings")
            .alert(isPresented: $showConfirmation) {
                Alert(title: Text("Success"), message: Text("Security settings updated"), dismissButton: .default(Text("OK")))
            }
        }
    }
}

struct SecuritySettingsView_Previews: PreviewProvider {
    @State static var rule = AutomationRule(
        id: UUID(),
        name: "Security Automation",
        condition: "RFID Allowed",
        action: "Display: Welcome; Buzzer: Off",
        activeDays: "M,Tu,W,Th,F,Sa,Su",
        triggerEnabled: true,
        triggerTime: Date()
    )
    static var previews: some View {
        SecuritySettingsView(rule: $rule)
    }
}
