import SwiftUI
import UniformTypeIdentifiers

struct DeviceCardView: View {
    @Binding var device: Device
    @Binding var devices: [Device]  // For reordering
    @ObservedObject var logManager: EventLogManager

    /// This is called if the device type isn't specifically handled,
    /// or if you want to do some default logic.
    var onSelect: () -> Void
    
    /// Called when the user taps the "Edit" context menu item
    var onEdit: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - State for the various sheets
    @State private var showColorPicker = false
    @State private var showLCDSettings = false
    @State private var showCameraView  = false
    @State private var showDHTChart = false  // New state for DHT sensor charts
    
    // Determines if the device is controllable (e.g., lights, fans, servos)
    private var isControllable: Bool {
        switch device.deviceType {
        case .light, .fan, .door, .servo, .buzzer, .statusLED:
            return true
        default:
            return false
        }
    }
    
    // Determines if the device should show a sensor reading (temp/hum/motion).
    private var isSensorReadingDevice: Bool {
        switch device.deviceType {
        case .temperature, .humidity, .motion, .rfid, .lcd, .espCam:
            return true
        default:
            return false
        }
    }
    
    var body: some View {
        // The entire card is a single Button
        Button(action: handleTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    DeviceIcon(deviceType: device.deviceType)
                        .frame(width: 30, height: 30)
                    
                    Text(device.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // If controllable, show a PowerButton on the right
                    if isControllable {
                        PowerButton(device: $device, logManager: logManager)
                            .frame(width: 40, height: 40)
                    }
                    // If not controllable but is a sensor device, show the sensor reading
                    else if isSensorReadingDevice {
                        sensorReadingView
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        
        
        // Context menu for "Edit"
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
        }
        
        // MARK: - Sheets
        .sheet(isPresented: $showColorPicker) {
            // Show your LED color picker
            LEDColorPickerView(
                devicePort: device.port,
                onDismiss: { showColorPicker = false }
            )
        }
        .sheet(isPresented: $showLCDSettings) {
            LCDSettingsView()
        }
        .sheet(isPresented: $showCameraView) {
            CameraLivestreamView(streamURL: URL(string: "http://\(Config.cameraIP):81/stream")!)
        }
        .sheet(isPresented: $showDHTChart) {
            DHT11ChartView()
        }
    }
    
    // MARK: - Tapping the card
    private func handleTap() {
        switch device.deviceType {
        case .light:
            showColorPicker = true
        case .lcd:
            showLCDSettings = true
        case .espCam:
            showCameraView = true
        case .temperature, .humidity:
            showDHTChart = true
        default:
            onSelect()
        }
    }
    
    // MARK: - Sensor reading
    @ViewBuilder
    private var sensorReadingView: some View {
        if device.isOnline {
            Text(device.status)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.green)
                .padding(4)
        } else {
            Text("Offline")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.gray)
        }
    }
}

struct DeviceIcon: View {
    let deviceType: DeviceType
    var body: some View {
        Image(systemName: iconName(for: deviceType))
            .resizable()
            .scaledToFit()
            .foregroundColor(color(for: deviceType))
    }
    
    private func iconName(for type: DeviceType) -> String {
        switch type {
        case .light: return "lightbulb"
        case .fan: return "fanblades"
        case .door: return "door.closed"
        case .sensor: return "antenna.radiowaves.left.and.right"
        case .motion: return "figure.walk"
        case .servo: return "gauge"
        case .temperature: return "thermometer"
        case .humidity: return "drop"
        case .rfid: return "creditcard"
        case .lcd: return "display"
        case .buzzer: return "speaker.wave.2"
        case .espCam: return "video"
        case .statusLED: return "lock.shield"
        }
    }
    
    private func color(for type: DeviceType) -> Color {
        switch type {
        case .light: return .yellow
        case .fan: return .blue
        case .door: return .gray
        case .sensor: return .purple
        case .motion: return .orange
        case .servo: return .pink
        case .temperature: return .red
        case .humidity: return .blue
        case .rfid: return .green
        case .lcd: return .indigo
        case .buzzer: return .red
        case .espCam: return .primary
        case .statusLED: return .green
        }
    }
}

// MARK: - Preview

struct DeviceCardView_Previews: PreviewProvider {
    @State static var devices: [Device] = Device.defaultDevices()
    static var previews: some View {
        DeviceCardView(
            device: .constant(devices[0]),
            devices: .constant(devices),
            logManager: EventLogManager(),
            onSelect: { print("Select default") },
            onEdit: { print("Edit") }
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
