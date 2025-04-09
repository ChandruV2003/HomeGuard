import SwiftUI
import UniformTypeIdentifiers


struct DevicesAreaView: View {
    @Binding var devices: [Device]
    var onSelect: (Device) -> Void
    var onContextAction: (Device, DeviceContextAction) -> Void
    @ObservedObject var logManager: EventLogManager
    var isReordering: Bool = false
    
    // Grid layout: two columns.
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Devices Banner
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundColor(.green)
                Text("Devices")
                    .font(.headline)
                    .foregroundColor(.green)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green, lineWidth: 2)
            )
            // No extra horizontal padding here so it matches Automations.
            
            if devices.isEmpty {
                Text("No devices available.")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(sortedDeviceTypes, id: \.self) { deviceType in
                            ForEach(groupedDeviceTypes[deviceType] ?? []) { device in
                                if let bindingDevice = binding(for: device) {
                                    let card = DeviceCardView(
                                        device: bindingDevice,
                                        devices: $devices,
                                        logManager: logManager,
                                        onSelect: { onSelect(bindingDevice.wrappedValue) },
                                        onEdit: { onContextAction(bindingDevice.wrappedValue, .edit) }
                                    )
                                    
                                    // Condition: only allow drag if isReordering
                                    if isReordering {
                                        card
                                            .onDrag {
                                                NSItemProvider(object: device.id.uuidString as NSString)
                                            }
                                            .onDrop(
                                                of: [UTType.text.identifier],
                                                delegate: DeviceDropDelegate(item: device, devices: $devices)
                                            )
                                    } else {
                                        card
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // Group devices by type.
    private var groupedDeviceTypes: [DeviceType: [Device]] {
        Dictionary(grouping: devices) { $0.deviceType }
    }
    
    // Sorted keys.
    private var sortedDeviceTypes: [DeviceType] {
        groupedDeviceTypes.keys.sorted { $0.rawValue < $1.rawValue }
    }
    
    // Helper: return binding for a given device.
    private func binding(for device: Device) -> Binding<Device>? {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return nil }
        return $devices[index]
    }
}

struct DevicesAreaView_Previews: PreviewProvider {
    @State static var devices: [Device] = Device.defaultDevices()
    
    static var previews: some View {
        DevicesAreaView(
            devices: $devices,
            onSelect: { _ in },
            onContextAction: { _, _ in },
            logManager: EventLogManager()
        )
    }
}
