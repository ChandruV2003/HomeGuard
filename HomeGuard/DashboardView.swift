import SwiftUI

struct DashboardView: View {
    @State private var devices: [Device] = []
    @State private var automationRules: [AutomationRule] = []
    
    @StateObject var speechManager = SpeechManager()
    @StateObject var logManager = EventLogManager()
    
    // Global connectivity state
    @State private var isConnected: Bool = false
    
    // For editing modals
    @State private var showEditAutomation: AutomationRule? = nil
    @State private var deviceForEdit: Device? = nil
    @State private var showLog = false
    @State private var errorMessage: String = ""
    
    // For navigating to LCD, Camera, and Security Settings views
    @State private var selectedLCDDevice: Device? = nil
    @State private var selectedCameraDevice: Device? = nil
    @State private var showLCDSettings = false
    @State private var showCameraLivestream = false
    
    // Dedicated binding for Security Settings
    @State private var showSecuritySettings = false
    
    // For adding automations
    @State private var showAddAutomation = false
    
    // Default security automation (non-deletable)
    @State private var securityAutomation: AutomationRule = AutomationRule(
        id: UUID(),
        name: "Security System",
        condition: "RFID Allowed",
        action: "Display: Welcome; Buzzer: Off",
        activeDays: "M,Tu,W,Th,F,Sa,Su",
        triggerEnabled: true,
        triggerTime: Date()
    )
    
    // Polling timer for sensor data (2 seconds)
    @State private var sensorTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    @State private var aiGeneratedAutomation: AutomationRule? = nil
    // For AI automation
    @State private var showAIProcessing = false
    
    var body: some View {
        NavigationView {
            contentView
                .toolbar { toolbarContent }
                .onAppear {
                    if devices.isEmpty {
                        devices = Device.defaultDevices()
                    }
                    if !automationRules.contains(where: { $0.name == "Security System" }) {
                        automationRules.insert(securityAutomation, at: 0)
                    }
                    // Check connectivity once initially
                    syncConnectivity()
                }
                .onReceive(sensorTimer) { _ in
                    // 1) Check connectivity
                    syncConnectivity()
                    // 2) Fetch sensor data & update devices
                    NetworkManager.fetchSensorData { sensorDict in
                        guard let sensorDict = sensorDict else { return }
                        DispatchQueue.main.async {
                            updateDeviceStatuses(with: sensorDict)
                        }
                    }
                }
                // (You could remove your old .onReceive(Timer.publish(...).autoconnect()) if you prefer.)
                .sheet(isPresented: $showAddAutomation) {
                    AddAutomationView(inputDevices: filteredSensors) { newRule in
                        automationRules.append(newRule)
                        logManager.addLog("Added automation: \(newRule.name)")
                        showAddAutomation = false
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
                .sheet(item: $showEditAutomation) { rule in
                    if rule.name == "Security System" {
                        SecuritySettingsView(rule: $securityAutomation)
                    } else {
                        EditAutomationView(rule: rule, inputDevices: filteredSensors) { updatedRule in
                            if let index = automationRules.firstIndex(where: { $0.id == updatedRule.id }) {
                                automationRules[index] = updatedRule
                                logManager.addLog("Updated automation: \(updatedRule.name)")
                            }
                            showEditAutomation = nil
                        }
                    }
                }
                .sheet(isPresented: $showLog) {
                    EventLogView(logManager: logManager)
                }
                .sheet(isPresented: $showLCDSettings) {
                    LCDSettingsView()
                }
                .sheet(isPresented: $showCameraLivestream) {
                    CameraLivestreamView(streamURL: URL(string: "http://\(Config.globalESPIP):81/stream")!)
                }
                // Security Settings
                .sheet(isPresented: $showSecuritySettings) {
                    SecuritySettingsView(rule: $securityAutomation)
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: devices) { newDevices, _ in
            speechManager.currentDevices = newDevices
        }
        .onChange(of: automationRules) { newRules, _ in
            speechManager.currentAutomations = newRules
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceCommandReceived)) { notification in
            processVoiceCommand(notification: notification)
        }
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeaderView(title: "HomeGuard Dashboard")
                
                // WiFi status indicator
                WiFiStatusView(isConnected: isConnected)
                    .padding(.horizontal)
                
                // Security system banner
                SecuritySystemBannerView(rule: securityAutomation) {
                    showSecuritySettings = true
                }
                .padding(.horizontal)
                
                // Automations
                AutomationsAreaView(
                    automationRules: automationRules.filter { $0.name != "Security System" },
                    onAdd: { showAddAutomation = true },
                    onAcceptAISuggestion: {
                            if let aiAutomation = aiGeneratedAutomation {
                                automationRules.append(aiAutomation) // ✅ Accept AI automation
                                aiGeneratedAutomation = nil
                                logManager.addLog("Accepted AI automation: \(aiAutomation.name)")
                            }
                        },
                    onDismissAISuggestion: {
                            aiGeneratedAutomation = nil // ✅ Dismiss AI automation
                            logManager.addLog("Dismissed AI automation")
                        },
                    onContextAction: { rule, action in
                        handleAutomationAction(rule: rule, action: action)
                    },
                    addEnabled: !devices.isEmpty
                )
                
                // Devices
                DevicesAreaView(
                    devices: $devices,
                    onSelect: { device in
                        if device.deviceType == .lcd {
                            selectedLCDDevice = device
                            showLCDSettings = true
                        } else if device.deviceType == .espCam {
                            selectedCameraDevice = device
                            showCameraLivestream = true
                        }
                    },
                    onContextAction: { device, action in
                        handleDeviceAction(device: device, action: action)
                    },
                    logManager: logManager
                )
                .padding(.horizontal)
                
                // Voice control
                VoiceControlButton(speechManager: speechManager)
            }
            .padding(.vertical)
        }
    }
    private func fetchAIAutomations() {
            guard let logs = logManager.logs.last else { return }
        ChatGPTAPI.fetchAutomation(prompt: logs) { suggestedAutomation in
                DispatchQueue.main.async {
                    if let automation = suggestedAutomation {
                        automationRules.append(automation)
                        logManager.addLog("AI suggested automation: \(automation.name)")
                    }
                    showAIProcessing = false
                }
            }
        }
    
    // MARK: - Updating Device Statuses from sensor JSON
    private func updateDeviceStatuses(with sensorDict: [String: Any]) {
        // Parse temperature: if it comes as a Double or a String.
        let temperatureStr: String
        if let tempNum = sensorDict["temperature"] as? Double {
            temperatureStr = String(format: "%.1f", tempNum)
        } else if let tempStr = sensorDict["temperature"] as? String {
            temperatureStr = tempStr
        } else {
            temperatureStr = "NaN"
        }
        
        // Parse humidity similarly.
        let humidityStr: String
        if let humNum = sensorDict["humidity"] as? Double {
            humidityStr = String(format: "%.1f", humNum)
        } else if let humStr = sensorDict["humidity"] as? String {
            humidityStr = humStr
        } else {
            humidityStr = "NaN"
        }
        
        // Convert Celsius to Fahrenheit (if temperature is valid)
        var fahrenheitStr = "NaN"
        if let celsius = Double(temperatureStr) {
            let fahrenheit = celsius * 9.0 / 5.0 + 32.0
            fahrenheitStr = String(format: "%.0f", fahrenheit)
        }
        
        // Build the combined temperature/humidity reading.
        let temperatureCombined = fahrenheitStr + "°F, " + humidityStr + "%"
        
        // Other sensor fields.
        let pir = sensorDict["pir"] as? String ?? "No motion"
        let rfid = sensorDict["rfid"] as? String ?? "Active"
        let lcd = sensorDict["lcd"] as? String ?? "Ready"
        
        // Update each device based on its type.
        for i in devices.indices {
            switch devices[i].deviceType {
            case .temperature:
                devices[i].status = temperatureCombined
            case .humidity:
                devices[i].status = humidityStr + "%"
            case .motion:
                devices[i].status = pir
            case .rfid:
                devices[i].status = rfid
            case .lcd:
                devices[i].status = lcd
            default:
                break
            }
        }
    }
    
    // Filter sensors for automations
    private var filteredSensors: [Device] {
        devices.filter { device in
            device.deviceType == .sensor ||
            device.deviceType == .temperature ||
            device.deviceType == .humidity ||
            device.deviceType == .motion
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showError("Dashboard rearrangement coming soon!")
                }) {
                    Image(systemName: "gearshape.fill")
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
    }
    
    private func syncConnectivity() {
        SyncManager.checkConnection(globalIP: Config.globalESPIP) { connected in
            isConnected = connected
            // Update every device's online status.
            for index in devices.indices {
                devices[index].isOnline = connected
            }
        }
    }
    
    private func processVoiceCommand(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let command = userInfo["command"] as? String,
              let fullText = userInfo["fullText"] as? String else { return }
        print("Voice command received: \(command) from: \(fullText)")
        // Example handling...
        if command == "turn on light" {
            if let device = devices.first(where: { $0.name.lowercased().contains("light") }) {
                NetworkManager.sendCommand(port: device.port, action: "lightOn") { state in
                    DispatchQueue.main.async {
                        if let state = state {
                            logManager.addLog("\(device.name) turned \(state)")
                        }
                    }
                }
            }
        }
    }
    
    private func handleAutomationAction(rule: AutomationRule, action: AutomationContextAction) {
        switch action {
        case .edit:
            showEditAutomation = rule
        case .delete:
            if rule.name != "Security System",
               let idx = automationRules.firstIndex(where: { $0.id == rule.id }) {
                automationRules.remove(at: idx)
                logManager.addLog("Deleted automation: \(rule.name)")
            } else {
                showError("Security System cannot be deleted.")
            }
        case .toggleOn:
            logManager.addLog("\(rule.name) toggled on.")
        case .toggleOff:
            logManager.addLog("\(rule.name) toggled off.")
        default:
            break
        }
    }
    
    private func handleDeviceAction(device: Device, action: DeviceContextAction) {
        switch action {
        case .edit:
            deviceForEdit = device
        case .delete:
            showError("Core devices cannot be deleted.")
        default:
            break
        }
    }
    
    private func showError(_ message: String) {
        withAnimation {
            errorMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { errorMessage = "" }
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
