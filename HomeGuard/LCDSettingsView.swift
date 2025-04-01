import SwiftUI

struct LCDSettingsView: View {
    @State private var message: String = ""
    @State private var duration: Double = 5.0 // Duration in seconds
    @State private var showConfirmation: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("LCD Message")) {
                    TextField("Enter message", text: $message)
                }
                Section(header: Text("Display Duration (seconds)")) {
                    Slider(value: $duration, in: 1...20, step: 1)
                    Text("\(Int(duration)) seconds")
                }
                Button("Update LCD") {
                    NetworkManager.sendLCDMessage(message: message, duration: Int(duration)) { success in
                        DispatchQueue.main.async {
                            showConfirmation = success
                        }
                    }
                }
            }
            .navigationTitle("LCD Settings")
            .alert(isPresented: $showConfirmation) {
                Alert(title: Text("Success"), message: Text("LCD updated successfully"), dismissButton: .default(Text("OK")))
            }
        }
    }
}

struct LCDSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LCDSettingsView()
    }
}
