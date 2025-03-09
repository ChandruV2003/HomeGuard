import SwiftUI

struct DevicesAreaView: View {
    @Binding var devices: [Device]
    var onAdd: () -> Void
    var onSelect: (Device) -> Void
    var onContextAction: (Device, DeviceContextAction) -> Void
    @ObservedObject var logManager: EventLogManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header banner for Devices (green outline)
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundColor(.green)
                    .padding(.trailing, 4)
                Text("Devices")
                    .font(.headline)
                Spacer()
                if devices.isEmpty {
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                    }
                    .foregroundColor(.green)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green, lineWidth: 2)
            )
            .padding(.horizontal)
            .fixedSize(horizontal: false, vertical: true)
            
            if devices.isEmpty {
                Text("No devices. Tap '+' to add one.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ForEach($devices) { bindingDevice in
                    Button(action: { onSelect(bindingDevice.wrappedValue) }) {
                        DeviceRowView(
                            device: bindingDevice,
                            logManager: logManager,
                            onEdit: { onContextAction(bindingDevice.wrappedValue, .edit) },
                            onDelete: { onContextAction(bindingDevice.wrappedValue, .delete) }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button(action: { onContextAction(bindingDevice.wrappedValue, .edit) }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(action: { onContextAction(bindingDevice.wrappedValue, .delete) }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    Divider()
                        .background(Color.green)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct DevicesAreaView_Previews: PreviewProvider {
    @State static var devices: [Device] = [
        Device.create(name: "Living Room Lights", status: "Off", deviceType: .light, port: availablePorts[.light]?.first ?? "")
    ]
    static var previews: some View {
        DevicesAreaView(
            devices: $devices,
            onAdd: {},
            onSelect: { _ in },
            onContextAction: { _, _ in },
            logManager: EventLogManager()
        )
    }
}
