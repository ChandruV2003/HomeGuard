import SwiftUI

struct EditDeviceView: View {
    @Environment(\.dismiss) var dismiss
    @State var device: Device
    var onSave: (Device) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Device")) {
                    TextField("Device Name", text: $device.name)
                    Picker("Device Type", selection: $device.deviceType) {
                        ForEach(DeviceType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    Picker("Port", selection: $device.port) {
                        ForEach(availablePorts[device.deviceType] ?? [], id: \.self) { port in
                            Text(port).tag(port)
                        }
                    }
                    Text("IP: \(device.ipAddress)")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Edit \(device.name)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(device)
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

struct EditDeviceView_Previews: PreviewProvider {
    static var previews: some View {
        EditDeviceView(device: Device.create(name: "Test Device", status: "Off", deviceType: .light, port: availablePorts[.light]?.first ?? ""), onSave: { updated in
            print(updated)
        })
    }
}
