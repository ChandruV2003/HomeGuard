import SwiftUI

struct PowerButton: View {
    @Binding var device: Device
    @ObservedObject var logManager: EventLogManager
    
    var body: some View {
        Button(action: {
            guard device.isOnline else { return }
            let newState = !device.isOn
            device.isOn = newState
            let command: String
            switch device.deviceType {
            case .light, .fan:
                command = newState ? "lightOn" : "lightOff"
            case .door:
                command = newState ? "garageOpen" : "garageClose"
            default:
                command = ""
            }
            if !command.isEmpty {
                sendCommand(command, for: device.ipAddress) { success in
                    if success {
                        device.status = newState ? "On" : "Off"
                        logManager.addLog("\(device.name) turned \(newState ? "On" : "Off")")
                    }
                }
            }
        }) {
            Text(buttonLabel)
                .font(.subheadline)
                .padding(8)
                .frame(minWidth: 60)
                .background(device.isOnline ? (device.isOn ? Color.green.opacity(0.7) : Color.gray.opacity(0.7)) : Color.clear)
                .cornerRadius(8)
                .overlay(
                    Group {
                        if !device.isOnline {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundColor(.red)
                        }
                    }
                )
                .foregroundColor(device.isOnline ? .white : .red)
        }
        .disabled(!device.isOnline)
    }
    
    private var buttonLabel: String {
        switch device.deviceType {
        case .light, .fan:
            return device.isOn ? "On" : "Off"
        case .door:
            return device.isOn ? "Close" : "Open"
        default:
            return ""
        }
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
