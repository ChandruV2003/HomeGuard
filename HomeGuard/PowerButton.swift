import SwiftUI

struct PowerButton: View {
    @Binding var device: Device
    @ObservedObject var logManager: EventLogManager
    @Environment(\.colorScheme) var colorScheme

    @State private var isBusy = false          // 🆕
    private let circleSize: CGFloat = 44

    var body: some View {
        Button(action: toggleDevice) {
            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: circleSize, height: circleSize)

                if isBusy {                     // spinning ring during network I/O
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "power")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy || !device.isOnline)   // 🚫 no hammer‑tapping
    }

    // MARK: - Helpers ---------------------------------------------------------

    private func toggleDevice() {
        guard device.isOnline, !isBusy else { return }
        isBusy = true

        // Decide the requested action
        let requestAct = "toggle"

        NetworkManager.sendCommandWithRetry(port: device.port,
                                            action: requestAct) { state, ok in
            DispatchQueue.main.async {
                defer { isBusy = false }

                guard ok, let state = state else {
                    logManager.addLog("⚠️  \(device.name) did not respond")
                    return
                }

                // Normal state update (same logic as before)
                switch device.deviceType {
                case .door, .servo:
                    device.status = state
                    device.isOn   = (state == "Opened")
                case .light, .fan, .buzzer:
                    device.isOn   = (state == "On")
                    device.status = device.isOn ? "On" : "Off"
                default:
                    device.isOn.toggle()
                    device.status = device.isOn ? "On" : "Off"
                }
                logManager.addLog("\(device.name) → \(device.status)")
            }
        }
    }

    private var fillColor: Color {
        device.isOnline
            ? (device.isOn ? .green : .gray)
            : .clear
    }

    private var iconColor: Color {
        device.isOnline ? .white : (colorScheme == .dark ? .white : .black)
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
