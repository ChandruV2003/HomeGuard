import SwiftUI

struct DashboardView: View {
    @State private var devices: [Device] = []  // User-added devices
    @State private var automationRules: [AutomationRule] = []  // Automation rules

    @StateObject var speechManager = SpeechManager()
    @StateObject var logManager = EventLogManager()
    
    @State private var showAddDevice = false
    @State private var showAddAutomation = false
    @State private var showEditAutomation: AutomationRule? = nil
    @State private var deviceForEdit: Device? = nil
    @State private var showLog = false
    @State private var errorMessage: String = ""
    
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
                        // Automations Area
                        AutomationsAreaView(
                            automationRules: automationRules,
                            onAdd: {
                                if devices.isEmpty {
                                    showError("Please add a device before creating automations.")
                                } else {
                                    showAddAutomation = true
                                }
                            },
                            onContextAction: { rule, action in
                                switch action {
                                case .edit:
                                    showEditAutomation = rule
                                case .delete:
                                    if let index = automationRules.firstIndex(where: { $0.id == rule.id }) {
                                        automationRules.remove(at: index)
                                        logManager.addLog("Deleted automation: \(rule.name)")
                                    }
                                case .toggleOn:
                                    logManager.addLog("\(rule.name) toggled on.")
                                case .toggleOff:
                                    logManager.addLog("\(rule.name) toggled off.")
                                default:
                                    break
                                }
                            },
                            addEnabled: !devices.isEmpty
                        )
                        
                        // Devices Area
                        DevicesAreaView(
                            devices: $devices,
                            onAdd: { showAddDevice = true },
                            onSelect: { device in
                                // Tapping a device row does nothing extra.
                            },
                            onContextAction: { device, action in
                                switch action {
                                case .edit:
                                    deviceForEdit = device
                                case .delete:
                                    if let index = devices.firstIndex(where: { $0.id == device.id }) {
                                        devices.remove(at: index)
                                        logManager.addLog("Deleted device: \(device.name)")
                                    }
                                default:
                                    break
                                }
                            },
                            logManager: logManager
                        )
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
                                showAddAutomation = true
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
            .sheet(isPresented: $showAddAutomation) {
                AddAutomationView(inputDevices: devices.filter { device in
                    return device.deviceType == .sensor ||
                           device.deviceType == .temperature ||
                           device.deviceType == .humidity ||
                           device.deviceType == .motion
                }) { rule in
                    automationRules.append(rule)
                    logManager.addLog("Added automation: \(rule.name)")
                }
            }
            .sheet(item: $showEditAutomation) { rule in
                EditAutomationView(
                    rule: rule,
                    inputDevices: devices.filter { device in
                        return device.deviceType == .sensor ||
                               device.deviceType == .temperature ||
                               device.deviceType == .humidity ||
                               device.deviceType == .motion
                    }
                ) { updatedRule in
                    if let index = automationRules.firstIndex(where: { $0.id == updatedRule.id }) {
                        automationRules[index] = updatedRule
                        logManager.addLog("Updated automation: \(updatedRule.name)")
                    }
                    showEditAutomation = nil
                }
            }
            .sheet(item: $deviceForEdit) { device in
                EditDeviceView(device: device) { updatedDevice in
                    if let index = devices.firstIndex(where: { $0.id == updatedDevice.id }) {
                        devices[index] = updatedDevice
                        logManager.addLog("Updated device: \(updatedDevice.name)")
                    }
                    deviceForEdit = nil
                }
            }
            .sheet(isPresented: $showLog) {
                EventLogView(logManager: logManager)
            }
            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
                let currentDevices = devices  // Snapshot
                for device in currentDevices {
                    if let actualIndex = devices.firstIndex(where: { $0.id == device.id }) {
                        if device.deviceType == .sensor ||
                           device.deviceType == .temperature ||
                           device.deviceType == .humidity {
                            pollSensorData(for: device) { sensorData in
                                DispatchQueue.main.async {
                                    if let sensorData = sensorData {
                                        devices[actualIndex].sensorData = sensorData
                                        devices[actualIndex].status = "\(sensorData.temperature)°F"
                                        devices[actualIndex].isOnline = true
                                    } else if devices.indices.contains(actualIndex) {
                                        devices[actualIndex].isOnline = false
                                    }
                                }
                            }
                        } else {
                            NetworkManager.sendCommand(port: device.port, action: "status") { state in
                                DispatchQueue.main.async {
                                    if let state = state {
                                        devices[actualIndex].status = state
                                        devices[actualIndex].isOnline = true
                                    } else if devices.indices.contains(actualIndex) {
                                        devices[actualIndex].isOnline = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
