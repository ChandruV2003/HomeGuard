import SwiftUI

struct AddDeviceView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var selectedType: DeviceType = .light
    @State private var selectedPort: String = availablePorts[.light]?.first ?? ""
    
    var onSave: (Device) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Device Info")) {
                    TextField("Device Name", text: $name)
                    Picker("Device Type", selection: $selectedType) {
                        ForEach(DeviceType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .onChange(of: selectedType) { _, newValue in
                        if let ports = availablePorts[newValue] {
                            selectedPort = ports.first ?? ""
                        } else {
                            selectedPort = ""
                        }
                    }
                    Picker("Port", selection: $selectedPort) {
                        ForEach(availablePorts[selectedType] ?? [], id: \.self) { port in
                            Text(port).tag(port)
                        }
                    }
                }
            }
            .navigationTitle("Add New Device")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newDevice = Device.create(name: name, status: "Unknown", deviceType: selectedType, port: selectedPort)
                        onSave(newDevice)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct AddDeviceView_Previews: PreviewProvider {
    static var previews: some View {
        AddDeviceView { device in
            print(device)
        }
    }
}
