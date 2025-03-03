import SwiftUI

struct DeviceDetailView: View {
    @Binding var device: Device
    @ObservedObject var logManager: EventLogManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Device Information")) {
                    Text("Name: \(device.name)")
                    Text("Port: \(device.port)")
                    Text("Status: \(device.status)")
                    if let sensor = device.sensorData {
                        Text("Temperature: \(sensor.temperature)°F")
                        Text("Humidity: \(sensor.humidity)%")
                    }
                }
                if device.deviceType == .light || device.deviceType == .fan || device.deviceType == .door {
                    Section(header: Text("Controls")) {
                        PowerButton(device: $device, logManager: logManager)
                            .font(.title)
                            .padding()
                        DatePicker("Set Timer", selection: .constant(Date()), displayedComponents: .hourAndMinute)
                    }
                } else if device.deviceType == .sensor {
                    Section(header: Text("Readings")) {
                        if let sensor = device.sensorData {
                            Text("Temperature: \(sensor.temperature)°F")
                            Text("Humidity: \(sensor.humidity)%")
                        } else {
                            Text("No data available")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(device.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DeviceDetailView_Previews: PreviewProvider {
    @State static var device = Device.create(name: "Living Room Lights", status: "Off", deviceType: .light, port: availablePorts[.light]?.first ?? "")
    static var previews: some View {
        NavigationView {
            DeviceDetailView(device: $device, logManager: EventLogManager())
        }
    }
}
