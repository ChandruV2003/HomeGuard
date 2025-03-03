import SwiftUI

enum DeviceContextAction {
    case favoriteToggle, edit, delete
}

struct DashboardView: View {
    @State private var devices: [Device] = []  // Start empty
    @State private var automationRules: [AutomationRule] = []  // Start empty
    
    @StateObject var speechManager = SpeechManager()
    @StateObject var logManager = EventLogManager()
    
    @State private var showAddDevice = false
    @State private var showAutomationRule = false
    @State private var showLog = false
    @State private var selectedDevice: Device? = nil
    @State private var editDevice: Device? = nil
    @State private var errorMessage: String = ""
    
    // Grouping
    private var favoriteDevices: [Device] {
        devices.filter { $0.isFavorite }
    }
    private var nonFavoriteDevices: [Device] {
        devices.filter { !$0.isFavorite }
    }
    private var groupedNonFavorites: [DeviceType: [Device]] {
        Dictionary(grouping: nonFavoriteDevices, by: { $0.deviceType })
    }
    private var sortedDeviceTypes: [DeviceType] {
        [.light, .door, .sensor, .fan]
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                HeaderView(title: "HomeGuard Dashboard")
                if #available(iOS 15.0, *) {
                    VoiceCommandView(speechManager: speechManager)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voice Command:")
                            .font(.headline)
                        Text(speechManager.recognizedText)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                if !errorMessage.isEmpty {
                    ErrorBanner(message: errorMessage)
                        .transition(.move(edge: .top))
                }
                ScrollView {
                    VStack(spacing: 16) {
                        // Automation Area
                        AutomationAreaView(automationRules: automationRules, onAdd: {
                            if devices.isEmpty {
                                showError("Please add a device before creating automations.")
                            } else {
                                showAutomationRule = true
                            }
                        }, onSelect: { rule in
                            logManager.addLog("Selected automation: \(rule.name)")
                        }, addEnabled: !devices.isEmpty)
                        
                        // Devices Area
                        DevicesAreaView(devices: devices, onAdd: {
                            showAddDevice = true
                        }, onSelect: { device in
                            selectedDevice = device
                        }, onContextAction: { device, action in
                            handleDeviceContextAction(device: device, action: action)
                        })
                    }
                    .padding(.vertical)
                }
                VoiceControlButton(speechManager: speechManager)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showAddDevice = true }) {
                            Label("Add Device", systemImage: "plus.circle")
                        }
                        Button(action: {
                            if devices.isEmpty {
                                showError("Please add a device before creating automations.")
                            } else {
                                showAutomationRule = true
                            }
                        }) {
                            Label("Add Automation", systemImage: "bolt.circle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showLog = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddDevice) {
                AddDeviceView { newDevice in
                    devices.append(newDevice)
                    logManager.addLog("Added device: \(newDevice.name)")
                }
            }
            .sheet(isPresented: $showAutomationRule) {
                AutomationRuleView { rule in
                    automationRules.append(rule)
                    logManager.addLog("Added automation: \(rule.name)")
                }
            }
            .sheet(item: $selectedDevice) { device in
                DeviceDetailView(device: binding(for: device), logManager: logManager)
            }
            .sheet(item: $editDevice) { device in
                EditDeviceView(device: device) { updatedDevice in
                    if let index = devices.firstIndex(where: { $0.id == updatedDevice.id }) {
                        devices[index] = updatedDevice
                        logManager.addLog("Updated device: \(updatedDevice.name)")
                    }
                    editDevice = nil
                }
            }
            .sheet(isPresented: $showLog) {
                EventLogView(logManager: logManager)
            }
            .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
                let snapshot = devices
                for snapshotDevice in snapshot {
                    if let idx = devices.firstIndex(where: { $0.id == snapshotDevice.id }),
                       devices.indices.contains(idx) {
                        pollSensorData(for: snapshotDevice) { sensorData in
                            DispatchQueue.main.async {
                                if let sensorData = sensorData {
                                    devices[idx].sensorData = sensorData
                                    devices[idx].status = "\(sensorData.temperature)°F"
                                    devices[idx].isOnline = true
                                } else {
                                    devices[idx].isOnline = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func binding(for device: Device) -> Binding<Device> {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else {
            fatalError("Device not found")
        }
        return $devices[index]
    }
    
    private func handleDeviceContextAction(device: Device, action: DeviceContextAction) {
        switch action {
        case .favoriteToggle:
            if let idx = devices.firstIndex(where: { $0.id == device.id }) {
                devices[idx].isFavorite.toggle()
                let favText = devices[idx].isFavorite ? "marked as favorite" : "removed from favorites"
                logManager.addLog("\(devices[idx].name) \(favText)")
            }
        case .edit:
            editDevice = device
        case .delete:
            withAnimation {
                if let idx = devices.firstIndex(where: { $0.id == device.id }) {
                    logManager.addLog("Deleted device: \(devices[idx].name)")
                    devices.remove(at: idx)
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        withAnimation {
            errorMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                errorMessage = ""
            }
        }
    }
}

@available(iOS 15.0, *)
extension DashboardView {
    private var highlightedVoiceText: AttributedString {
        var attr = AttributedString(speechManager.recognizedText)
        for keyword in speechManager.magicKeywords {
            if let range = attr.range(of: keyword, options: .caseInsensitive) {
                attr[range].foregroundColor = .orange
            }
        }
        if speechManager.commandRecognized {
            attr.foregroundColor = .green
        }
        return attr
    }
}

func pollSensorData(for device: Device, completion: @escaping (SensorData?) -> Void) {
    guard let url = URL(string: "http://\(device.ipAddress)/sensor") else {
        completion(nil)
        return
    }
    URLSession.shared.dataTask(with: url) { data, response, error in
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
            completion(nil)
        }
    }.resume()
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
