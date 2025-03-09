import SwiftUI

struct AddDeviceView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var selectedType: DeviceType = .light
    @State private var selectedPort: String = availablePorts[.light]?.first ?? ""
    
    // IP Address is not editable.
    let ipAddress: String = globalESPIP
    
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
                    Text("IP Address: \(ipAddress)")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Add New Device")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newDevice = Device(
                            id: UUID(),
                            name: name,
                            ipAddress: ipAddress,
                            port: selectedPort,
                            status: "Off",
                            sensorData: nil,
                            isOn: false,
                            isOnline: false,  // Start as offline.
                            deviceType: selectedType,
                            group: nil,
                            isFavorite: false
                        )
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
