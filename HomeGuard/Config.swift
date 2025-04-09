import Foundation

struct Config {
    static let globalESPIP: String = "172.20.10.4"
    static let cameraIP: String = "172.20.10.6"
    
    // For the accelerated time
    static let timeAcceleration: Double = 1440.0
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

struct Device: Identifiable, Equatable, Hashable {
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
            Device.create(name: "Fan", status: "Off", deviceType: .fan, port: availablePorts[.fan]?.first ?? ""),
            Device.create(name: "ESP-CAM", status: "Streaming", deviceType: .espCam, port: availablePorts[.espCam]?.first ?? "")
        ]
    }
}

struct AutomationRule: Identifiable, Codable, Equatable {
    let id: String  // Changed from UUID to String
    var name: String
    var condition: String
    var action: String
    var activeDays: String
    var triggerEnabled: Bool
    var triggerTime: Date
    // New properties for editing
    var inputDeviceID: String?
    var outputDeviceID: String?

    enum CodingKeys: String, CodingKey {
        case id = "uid"  // Map JSON "uid" to the id property
        case name, condition, action, activeDays, triggerEnabled, triggerTime, inputDeviceID, outputDeviceID
    }
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

func mergeAutomationRules(local: [AutomationRule], fetched: [AutomationRule]) -> [AutomationRule] {
    // Create a dictionary based on fetched rules, keyed by the rule’s id.
    var mergedDict = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
    
    // Add any local rule that isn't in the fetched results.
    for rule in local {
        if mergedDict[rule.id] == nil {
            mergedDict[rule.id] = rule
        }
    }
    
    // Return the merged values; you might sort them if you need a specific order.
    return Array(mergedDict.values)
}

func scaledMillisToString(_ scaledMillis: Double) -> String {
    // Convert to integer total seconds
    let totalSeconds = Int(scaledMillis / 1000.0)
    
    // Determine how many days have elapsed
    let daysElapsed = totalSeconds / (24 * 3600)
    // We only care about mod 7 for M..Su
    let dayIndex = daysElapsed % 7
    
    // Same abbreviations used in the firmware
    let dayAbbreviations = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    let currentDay = dayAbbreviations[dayIndex]
    
    // leftover seconds in the current day
    let leftover = totalSeconds % (24 * 3600)
    let hour24 = leftover / 3600
    let minute = (leftover % 3600) / 60
    
    // Convert 24h -> 12h
    var displayHour = hour24
    var ampm = "AM"
    if displayHour == 0 {
        displayHour = 12
        ampm = "AM"
    } else if displayHour == 12 {
        ampm = "PM"
    } else if displayHour > 12 {
        displayHour -= 12
        ampm = "PM"
    }
    
    return String(format: "%@ %d:%02d %@", currentDay, displayHour, minute, ampm)
}



