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
                        // Invert the logic: if firmware returns "On", then actualOn is false, and vice versa.
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
                // Background: if device is online, green if on, gray if off; offline is red.
                .background(device.isOnline ? (device.isOn ? Color.green : Color.gray) : Color.red)
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
