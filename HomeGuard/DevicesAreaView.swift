import SwiftUI

struct DevicesAreaView: View {
    var devices: [Device]
    var onAdd: () -> Void
    var onSelect: (Device) -> Void
    var onContextAction: (Device, DeviceContextAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header banner for Devices
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
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green, lineWidth: 2)
            )
            .padding(.horizontal)
            // Fix the header size so it doesn't expand vertically.
            .fixedSize(horizontal: false, vertical: true)
            
            if devices.isEmpty {
                Text("No devices. Tap '+' to add one.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ForEach(devices.indices, id: \.self) { i in
                    let device = devices[i]
                    Button(action: { onSelect(device) }) {
                        DeviceRowView(device: .constant(device), logManager: EventLogManager())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button(action: { onContextAction(device, .favoriteToggle) }) {
                            if device.isFavorite {
                                Label("Unfavorite", systemImage: "star.slash")
                            } else {
                                Label("Favorite", systemImage: "star")
                            }
                        }
                        Button("Edit") { onContextAction(device, .edit) }
                        Button("Delete", role: .destructive) { onContextAction(device, .delete) }
                    }
                    if i < devices.count - 1 {
                        Divider()
                            .background(Color.green)
                    }
                }
            }
        }
    }
}

struct DevicesAreaView_Previews: PreviewProvider {
    static var previews: some View {
        DevicesAreaView(devices: [
            Device.create(name: "Living Room Lights", status: "Off", deviceType: .light, port: availablePorts[.light]?.first ?? "")
        ], onAdd: {}, onSelect: { _ in }, onContextAction: { _, _ in })
    }
}
