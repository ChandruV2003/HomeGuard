// Models.swift
import Foundation

// Global ESP IP – change as needed.
let globalESPIP: String = "192.168.4.1"

// Define available ports by device type.
let availablePorts: [DeviceType: [String]] = [
    .light: ["D1", "D2", "D3"],
    .fan:   ["D1", "D2", "D3"],
    .door:  ["D4", "D5"],
    .sensor:["A0"]
]

enum DeviceType: String, Codable, Equatable, Hashable, CaseIterable {
    case light, fan, door, sensor
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
    
    init(id: UUID, name: String, ipAddress: String, port: String, status: String, sensorData: SensorData?, isOn: Bool, isOnline: Bool, deviceType: DeviceType, group: String?, isFavorite: Bool) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.port = port
        self.status = status
        self.sensorData = sensorData
        self.isOn = isOn
        self.isOnline = isOnline
        self.deviceType = deviceType
        self.group = group
        self.isFavorite = isFavorite
    }
}

extension Device {
    static func create(name: String, status: String, deviceType: DeviceType, port: String) -> Device {
        return Device(id: UUID(),
                      name: name,
                      ipAddress: globalESPIP,
                      port: port,
                      status: status,
                      sensorData: nil,
                      isOn: false,
                      isOnline: false,
                      deviceType: deviceType,
                      group: nil,
                      isFavorite: false)
    }
}

struct AutomationRule: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var condition: String
    var action: String
}
