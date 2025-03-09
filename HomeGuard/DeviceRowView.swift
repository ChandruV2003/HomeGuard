import SwiftUI

struct DeviceRowView: View {
    @Binding var device: Device
    @ObservedObject var logManager: EventLogManager
    
    // Callbacks for context menu actions.
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                // Wi-Fi indicator icon.
                Image(systemName: "wifi")
                    .foregroundColor(device.isOnline ? .green : .red)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.headline)
                    // Port specification immediately below the name.
                    Text("Port: \(device.port)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                if device.deviceType == .sensor ||
                   device.deviceType == .temperature ||
                   device.deviceType == .humidity {
                    // For sensor devices, display the sensor reading.
                    Text(device.status) // e.g., "72°F" or "55%"
                        .font(.subheadline)
                        .padding(10)
                        .background(Circle().fill(device.isOnline ? Color.green : Color.red))
                        .foregroundColor(.white)
                } else {
                    // For controllable devices, display the power button.
                    PowerButton(device: $device, logManager: logManager)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
}

struct DeviceRowView_Previews: PreviewProvider {
    @State static var device = Device.create(name: "Living Room Light", status: "Off", deviceType: .light, port: availablePorts[.light]?.first ?? "")
    static var previews: some View {
        DeviceRowView(
            device: $device,
            logManager: EventLogManager(),
            onEdit: { print("Edit tapped") },
            onDelete: { print("Delete tapped") }
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}

