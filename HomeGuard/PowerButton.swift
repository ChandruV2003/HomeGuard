import SwiftUI

struct PowerButton: View {
    @Binding var device: Device
    @ObservedObject var logManager: EventLogManager
    @Environment(\.colorScheme) var colorScheme

    // Circle size for the power button.
    private let circleSize: CGFloat = 44

    var body: some View {
        Button(action: {
            guard device.isOnline else { return }
            // Send a toggle command
            NetworkManager.sendCommand(port: device.port, action: "toggle") { state in
                DispatchQueue.main.async {
                    guard let state = state else {
                        logManager.addLog("Failed to update \(device.name)")
                        return
                    }
                    
                    // Handle different device types
                    switch device.deviceType {
                    case .door, .servo:
                        device.status = state
                        device.isOn = (state == "Opened")
                    case .light, .fan, .buzzer:
                        device.isOn = (state == "On")
                        device.status = device.isOn ? "On" : "Off"
                    default:
                        device.isOn.toggle()
                        device.status = device.isOn ? "On" : "Off"
                    }
                    
                    logManager.addLog("\(device.name) is now \(device.status)")
                }
            }
        }) {
            ZStack {
                // If offline, show a dashed red circle.
                if !device.isOnline {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .foregroundColor(.red)
                        .frame(width: circleSize, height: circleSize)
                } else {
                    // For door/servo devices, use doorFillColor() to decide the color.
                    // Otherwise, default to green if on and gray if off.
                    Circle()
                        .fill(doorFillColor())
                        .frame(width: circleSize, height: circleSize)
                }
                // Power icon in the center.
                Image(systemName: "power")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Determines the fill color for the power button.
    /// For door or servo devices, green indicates "Opened" (i.e. not in the home position), and gray indicates "Closed."
    /// For other devices, green is used when on, and gray when off.
    private func doorFillColor() -> Color {
        if device.deviceType == .door || device.deviceType == .servo {
            return (device.status == "Opened") ? .green : .gray
        }
        return device.isOn ? .green : .gray
    }

    /// Dynamically choose the icon color:
    /// - If offline, black in light mode and white in dark mode.
    /// - If online, always white for contrast.
    private var iconColor: Color {
        if !device.isOnline {
            return colorScheme == .dark ? .white : .black
        } else {
            return .white
        }
    }
}

struct PowerButton_Previews: PreviewProvider {
    @State static var doorOpenDevice = Device.create(name: "Front Door", status: "Opened", deviceType: .door, port: "GPIO27")
    @State static var doorClosedDevice = Device.create(name: "Front Door", status: "Closed", deviceType: .door, port: "GPIO27")
    @State static var lightDeviceOn = Device.create(name: "Living Room Light", status: "On", deviceType: .light, port: "GPIO32")
    @State static var lightDeviceOff = Device.create(name: "Kitchen Light", status: "Off", deviceType: .light, port: "GPIO33")
    @State static var offlineDevice = Device.create(name: "Garage Light", status: "Off", deviceType: .light, port: "GPIO4")

    static var previews: some View {
        VStack(spacing: 20) {
            PowerButton(device: $doorOpenDevice, logManager: EventLogManager())
            PowerButton(device: $doorClosedDevice, logManager: EventLogManager())
            PowerButton(device: $lightDeviceOn, logManager: EventLogManager())
            PowerButton(device: $lightDeviceOff, logManager: EventLogManager())
            PowerButton(device: $offlineDevice, logManager: EventLogManager())
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
