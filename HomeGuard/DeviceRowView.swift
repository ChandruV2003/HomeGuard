import SwiftUI

struct DeviceRowView: View {
    @Binding var device: Device
    @ObservedObject var logManager: EventLogManager
    var onSelect: () -> Void = {}
    
    var body: some View {
        HStack {
            Image(systemName: "wifi")
                .foregroundColor(device.isOnline ? .green : .red)
                .padding(.trailing, 4)
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                Text("Port: \(device.port)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            if device.deviceType == .light || device.deviceType == .fan || device.deviceType == .door {
                PowerButton(device: $device, logManager: logManager)
            }
        }
        .padding(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

struct DeviceRowView_Previews: PreviewProvider {
    @State static var device = Device.create(name: "Test Device", status: "Off", deviceType: .light, port: availablePorts[.light]?.first ?? "")
    static var previews: some View {
        DeviceRowView(device: $device, logManager: EventLogManager())
    }
}
