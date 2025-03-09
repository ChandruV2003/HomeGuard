import Foundation

// Global ESP IP (used across the app and firmware)
let globalESPIP: String = "192.168.4.1"

// Expanded port options for every device type.
let availablePorts: [DeviceType: [String]] = [
    .light: ["D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "A0"],
    .fan:   ["D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "A0"],
    .door:  ["D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "A0"],
    .sensor:["D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "A0"],
    .motion:["D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8"],
    .servo: ["D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8"],
    .temperature: ["A0"],
    .humidity: ["A0"],
    .rfid:  ["D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8"],
    .lcd:   ["D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8"],
    .buzzer:["D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8"],
    .espCam:["D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8"]
]

enum DeviceType: String, Codable, Equatable, Hashable, CaseIterable {
    case light, fan, door, sensor, motion, servo, temperature, humidity, rfid, lcd, buzzer, espCam
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
            ipAddress: globalESPIP,
            port: port,
            status: status,
            sensorData: nil,
            isOn: false,
            isOnline: false,  // New devices start offline.
            deviceType: deviceType,
            group: nil,
            isFavorite: false
        )
    }
}

struct AutomationRule: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var condition: String
    var action: String
    var activeDays: String  // e.g. "M,Tu,W,Th,F,Sa,Su"
    var triggerEnabled: Bool
    var triggerTime: Date
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
