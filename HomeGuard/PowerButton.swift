import SwiftUI

struct PowerButton: View {
    @Binding var device: Device
    @ObservedObject var logManager: EventLogManager

    var body: some View {
        Button(action: {
            guard device.isOnline else { return }
            NetworkManager.sendCommand(port: device.port, action: "toggle") { state in
                DispatchQueue.main.async {
                    if let state = state {
                        // Invert the state since the hardware is active-low:
                        let actualOn = (state == "On") ? false : true
                        device.status = actualOn ? "On" : "Off"
                        device.isOn = actualOn
                        logManager.addLog("\(device.name) is now \(device.status)")
                    } else {
                        logManager.addLog("Failed to update \(device.name)")
                    }
                }
            }
        }) {
            Image(systemName: "power")
                .font(.title2)
                .padding(10)
                .background(device.isOn ? Color.green : Color.gray)
                .clipShape(Circle())
                .foregroundColor(.white)
        }
        .disabled(!device.isOnline)
    }
}

struct PowerButton_Previews: PreviewProvider {
    @State static var device = Device.create(name: "Test Light", status: "Off", deviceType: .light, port: availablePorts[.light]?.first ?? "")
    static var previews: some View {
        PowerButton(device: $device, logManager: EventLogManager())
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
