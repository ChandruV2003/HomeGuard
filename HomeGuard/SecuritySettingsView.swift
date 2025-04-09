import SwiftUI

struct SecuritySettingsView: View {
    @Binding var rule: AutomationRule
    
    @State private var goodCard: String = "044A565A7F7080"
    @State private var badCard: String = "046A2B4AD55E80"
    @State private var grantedMsg: String = "Access Granted"
    @State private var deniedMsg: String  = "Access Denied"
    @State private var buzzerDurationMs: Double = 1000
    
    @State private var showConfirmation: Bool = false
    
    var body: some View {
        NavigationView {
            Form(content: {
                Section(header: Text("Card UIDs")) {
                    TextField("Good Card UID", text: $goodCard)
                    TextField("Bad Card UID", text: $badCard)
                }
                
                Section(header: Text("Messages")) {
                    TextField("Granted Message", text: $grantedMsg)
                    TextField("Denied Message", text: $deniedMsg)
                }
                
                Section(header: Text("Buzzer Duration (ms)")) {
                    Slider(value: $buzzerDurationMs, in: 100...5000, step: 100)
                    Text("\(Int(buzzerDurationMs)) ms")
                }
                
                Button("Update Security Settings") {
                    NetworkManager.sendSecuritySettings(
                        goodCard: goodCard,
                        badCard: badCard,
                        grantedMsg: grantedMsg,
                        deniedMsg: deniedMsg,
                        buzzerMs: Int(buzzerDurationMs)
                    ) { success in
                        DispatchQueue.main.async {
                            showConfirmation = success
                        }
                    }
                }
            })
            .navigationBarTitle(Text("Security Settings"), displayMode: .inline)
            .onAppear(perform: fetchCurrentSecurity)
            .alert(isPresented: $showConfirmation, content: {
                Alert(
                    title: Text("Success"),
                    message: Text("Security settings updated"),
                    dismissButton: .default(Text("OK"))
                )
            })
        }
    }
    
    private func fetchCurrentSecurity() {
        guard let url = URL(string: "http://\(Config.globalESPIP)/security") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            else { return }
            
            DispatchQueue.main.async {
                if let gc = json["goodCard"] as? String {
                    goodCard = gc
                }
                if let bc = json["badCard"] as? String {
                    badCard = bc
                }
                if let gm = json["accessGrantedMsg"] as? String {
                    grantedMsg = gm
                }
                if let dm = json["accessDeniedMsg"] as? String {
                    deniedMsg = dm
                }
                if let bz = json["badCardBuzzerDuration"] as? Int {
                    buzzerDurationMs = Double(bz)
                }
            }
        }.resume()
    }
}

struct SecuritySettingsView_Previews: PreviewProvider {
    @State static var rule = AutomationRule(
        id: UUID().uuidString,  // Use string-based ID
        name: "Security Automation",
        condition: "RFID Allowed",
        action: "Active",
        activeDays: "M,Tu,W,Th,F,Sa,Su",
        triggerEnabled: true,
        triggerTime: Date(),
        inputDeviceID: nil,
        outputDeviceID: nil
    )
    
    static var previews: some View {
        SecuritySettingsView(rule: $rule)
    }
}
