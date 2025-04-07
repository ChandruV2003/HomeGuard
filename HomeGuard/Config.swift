import Foundation

struct Config {
    static let globalESPIP: String = "172.20.10.4"
}

// Updated port mappings...
let availablePorts: [DeviceType: [String]] = [
    .light: ["GPIO32", "GPIO33"],
    .statusLED: ["GPIO2"],
    .fan: ["GPIO26"],
    .door: ["GPIO14"],
    .sensor: ["GPIO4"],
    .motion: ["GPIO16"],
    .servo: ["GPIO14", "GPIO27"],
    .temperature: ["GPIO4"],
    .humidity: ["GPIO4"],
    .rfid: ["GPIO5", "GPIO19"],
    .lcd: ["GPIO21/22"],
    .buzzer: ["GPIO17"],
    .espCam: ["(Handled by ESP32-CAM board)"]
]

enum DeviceType: String, Codable, Equatable, Hashable, CaseIterable {
    case light, fan, door, sensor, motion, servo, temperature, humidity, rfid, lcd, buzzer, espCam, statusLED
}

struct SensorData: Codable, Equatable, Hashable {
    let temperature: Double
    let humidity: Double
}

struct Device: Identifiable, Hashable {
    let id: UUID
    var name: String
    var ipAddress: String
    var port: String
    var status: String
    var sensorData: SensorData?
    var isOn: Bool
    var isOnline: Bool
    var deviceType: DeviceType
    var group: String?
    var isFavorite: Bool
}

extension Device {
    static func create(name: String, status: String, deviceType: DeviceType, port: String) -> Device {
        return Device(
            id: UUID(),
            name: name,
            ipAddress: Config.globalESPIP,
            port: port,
            status: status,
            sensorData: nil,
            isOn: false,
            isOnline: false,
            deviceType: deviceType,
            group: nil,
            isFavorite: false
        )
    }
    
    /// Returns the fixed set of default devices.
    static func defaultDevices() -> [Device] {
        return [
            Device.create(name: "Living Room Lights", status: "Off", deviceType: .light, port: availablePorts[.light]?[0] ?? ""),
            Device.create(name: "Kitchen Lights", status: "Off", deviceType: .light, port: availablePorts[.light]?[1] ?? ""),
            Device.create(name: "Security Status LED", status: "Off", deviceType: .statusLED, port: availablePorts[.statusLED]?.first ?? ""),
            Device.create(name: "PIR Sensor", status: "Idle", deviceType: .motion, port: availablePorts[.motion]?.first ?? ""),
            Device.create(name: "DHT11 Sensor", status: "72°F, 55%", deviceType: .temperature, port: availablePorts[.temperature]?.first ?? ""),
            Device.create(name: "Garage Door", status: "Closed", deviceType: .servo, port: availablePorts[.servo]?[0] ?? ""),
            Device.create(name: "Front Door", status: "Closed", deviceType: .servo, port: availablePorts[.servo]?[1] ?? ""),
            Device.create(name: "RFID Sensor", status: "Active", deviceType: .rfid, port: availablePorts[.rfid]?.first ?? ""),
            Device.create(name: "LCD Screen", status: "Ready", deviceType: .lcd, port: availablePorts[.lcd]?.first ?? ""),
            Device.create(name: "Buzzer", status: "Off", deviceType: .buzzer, port: availablePorts[.buzzer]?.first ?? ""),
            Device.create(name: "Main Fan", status: "Off", deviceType: .fan, port: availablePorts[.fan]?.first ?? ""),
            Device.create(name: "ESP-CAM", status: "Streaming", deviceType: .espCam, port: availablePorts[.espCam]?.first ?? "")
        ]
    }
}

struct AutomationRule: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var condition: String
    var action: String
    var activeDays: String
    var triggerEnabled: Bool
    var triggerTime: Date
    // New properties for editing:
    var inputDeviceID: UUID?
    var outputDeviceID: UUID?
}

enum AutomationContextAction {
    case favoriteToggle, edit, delete, toggleOn, toggleOff
}

enum DeviceContextAction {
    case favoriteToggle, edit, delete
}

func pollSensorData(for device: Device, completion: @escaping (SensorData?) -> Void) {
    guard let url = URL(string: "http://\(device.ipAddress)/sensor") else {
        completion(nil)
        return
    }
    URLSession.shared.dataTask(with: url) { data, _, error in
        if let data = data {
            let decoder = JSONDecoder()
            do {
                let sensorData = try decoder.decode(SensorData.self, from: data)
                completion(sensorData)
            } catch {
                print("Error decoding sensor data: \(error)")
                completion(nil)
            }
        } else {
            print("Error: \(error?.localizedDescription ?? "unknown error")")
            completion(nil)
        }
    }.resume()
}

extension Notification.Name {
    static let voiceCommandReceived = Notification.Name("voiceCommandReceived")
}
