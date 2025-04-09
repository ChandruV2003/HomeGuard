import SwiftUI

struct DashboardView: View {
    @State private var devices: [Device] = []
    @State private var automationRules: [AutomationRule] = []
    
    // Created as a StateObject so it's not private
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
        id: UUID().uuidString,
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
        // 1) Build the main content in a helper
        let mainContent = contentView
        
        // 2) Put it in a NavigationView and add your .toolbar, .onAppear, .onReceive, etc.
        let navigationContainer = NavigationView {
            mainContent
                .toolbar { toolbarContent }
                .onAppear {
                    // Link speechManager's logManager:
                    speechManager.logManager = logManager
                    
                    if devices.isEmpty {
                        devices = Device.defaultDevices()
                    }
                    // Insert securityAutomation if not already present
                    if !automationRules.contains(where: { $0.name == "Security System" }) {
                        automationRules.insert(securityAutomation, at: 0)
                    }
                    // Check connectivity
                    syncConnectivity()
                    // Fetch automation rules from firmware on launch
                    NetworkManager.fetchAutomationRules { fetchedRules in
                        if let fetched = fetchedRules {
                            DispatchQueue.main.async {
                                // Merge fetched rules with any local ones
                                self.automationRules = mergeAutomationRules(local: self.automationRules, fetched: fetched)
                                print("DEBUG: Merged automation rules count: \(self.automationRules.count)")
                            }
                        }
                    }
                    ChatGPTAPI.fetchAutomation(prompt: "Suggest a new automation rule for my home") { suggestedRule in
                            if let rule = suggestedRule {
                                DispatchQueue.main.async {
                                    // Put it into aiGeneratedAutomation so AutomationsAreaView can show the "AI Suggested Automation" block
                                    self.aiGeneratedAutomation = rule
                                    print("DEBUG: AI suggested rule: \(rule)")
                                }
                            } else {
                                print("DEBUG: No AI rule returned (or failed to parse).")
                            }
                        }
                }
                .onReceive(sensorTimer) { _ in
                    syncConnectivity()
                    NetworkManager.fetchSensorData { sensorDict in
                        guard let sensorDict = sensorDict else { return }
                        DispatchQueue.main.async {
                            updateDeviceStatuses(with: sensorDict)
                        }
                    }
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
        // 3) Now attach the .sheet, .onChange, etc. to that container in smaller pieces:

        let withSheets = navigationContainer
            // Sheet for "Add Automation"
            .sheet(isPresented: $showAddAutomation) {
                AddAutomationView(
                    automationRules: $automationRules,
                    inputDevices: filteredSensors,
                    outputDevices: filteredOutputs // Add this line
                ) { newRule in
                    automationRules.append(newRule)
                    logManager.addLog("Added automation: \(newRule.name)")
                    showAddAutomation = false
                    // Refresh from firmware
                    NetworkManager.fetchAutomationRules { fetchedRules in
                        if let rules = fetchedRules {
                            DispatchQueue.main.async {
                                automationRules = rules
                            }
                        }
                    }
                }
            }
            // Sheet for editing devices
            .sheet(item: $deviceForEdit) { device in
                EditDeviceView(device: device) { updatedDevice in
                    if let index = devices.firstIndex(where: { $0.id == updatedDevice.id }) {
                        devices[index] = updatedDevice
                        logManager.addLog("Updated device: \(updatedDevice.name)")
                    }
                    deviceForEdit = nil
                }
            }
            // Sheet for editing automations
            .sheet(item: $showEditAutomation) { rule in
                if rule.name == "Security System" {
                    // Security automation => open SecuritySettingsView
                    SecuritySettingsView(rule: $securityAutomation)
                } else {
                    EditAutomationView(
                        rule: rule,
                        inputDevices: filteredSensors,
                        outputDevices: filteredOutputs
                    ) { updatedRule in
                        if let index = automationRules.firstIndex(where: { $0.id == updatedRule.id }) {
                            automationRules[index] = updatedRule
                            logManager.addLog("Updated automation: \(updatedRule.name)")
                        }
                        showEditAutomation = nil
                    }
                }
            }
            // Sheet for event log
            .sheet(isPresented: $showLog) {
                EventLogView(logManager: logManager)
            }
            // Sheet for LCD
            .sheet(isPresented: $showLCDSettings) {
                LCDSettingsView()
            }
            // Sheet for Camera
            .sheet(isPresented: $showCameraLivestream) {
                CameraLivestreamView(streamURL: URL(string: "http://\(Config.globalESPIP):81/stream")!)
            }
            // Separate sheet for security system
            .sheet(isPresented: $showSecuritySettings) {
                SecuritySettingsView(rule: $securityAutomation)
            }
        
        // 4) Attach the .onChange calls
        let withOnChange = withSheets
            .onChange(of: devices) {
                // iOS 17 no-parameter closure
                speechManager.currentDevices = devices
            }
            .onChange(of: automationRules) {
                speechManager.currentAutomations = automationRules
            }
            .onReceive(NotificationCenter.default.publisher(for: .voiceCommandReceived)) { notification in
                processVoiceCommand(notification: notification)
            }
        
        // 5) Return final result
        return withOnChange
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeaderView(title: "HomeGuard Dashboard")
                WiFiStatusView(isConnected: isConnected)
                    .padding(.horizontal)
                
                // Security banner
                SecuritySystemBannerView(rule: securityAutomation) {
                    showSecuritySettings = true
                }
                .padding(.horizontal)
                
                // Automations
                AutomationsAreaView(
                    automationRules: automationRules.filter { $0.name != "Security System" },
                    aiGeneratedAutomation: aiGeneratedAutomation,
                    onAdd: { showAddAutomation = true },
                    onAcceptAISuggestion: {
                        if let aiAutomation = aiGeneratedAutomation {
                            automationRules.append(aiAutomation)
                            aiGeneratedAutomation = nil
                            logManager.addLog("Accepted AI automation: \(aiAutomation.name)")
                            NetworkManager.fetchAutomationRules { fetchedRules in
                                if let rules = fetchedRules {
                                    DispatchQueue.main.async {
                                        automationRules = rules
                                    }
                                }
                            }
                        }
                    },
                    onDismissAISuggestion: {
                        aiGeneratedAutomation = nil
                        logManager.addLog("Dismissed AI automation")
                    },
                    onContextAction: { rule, action in
                        handleAutomationAction(rule: rule, action: action)
                    },
                    addEnabled: !devices.isEmpty
                )
                
                .onAppear {
                    logManager.analyzeLogsForAutomation()
                }
                
                // In DashboardView's body
                .onReceive(sensorTimer) { _ in
                    syncConnectivity()
                    NetworkManager.fetchSensorData { sensorDict in
                        guard let sensorDict = sensorDict else { return }
                        DispatchQueue.main.async {
                            updateDeviceStatuses(with: sensorDict)
                        }
                    }
                    
                    // Additional device state polling
                    NetworkManager.fetchAutomationRules { fetchedRules in
                        if let rules = fetchedRules {
                            DispatchQueue.main.async {
                                automationRules = rules
                            }
                        }
                    }
                }
                
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
    
    // Only includes sensor devices
    private var filteredSensors: [Device] {
        devices.filter { device in
            device.deviceType == .sensor ||
            device.deviceType == .temperature ||
            device.deviceType == .humidity ||
            device.deviceType == .motion
        }
    }
    
    // Adds 'fan', 'light', 'servo', 'buzzer', 'statusLED', 'door' as output devices
    private var filteredOutputs: [Device] {
        devices.filter { device in
            device.deviceType == .fan ||
            device.deviceType == .light ||
            device.deviceType == .servo ||
            device.deviceType == .buzzer ||
            device.deviceType == .statusLED ||
            device.deviceType == .door
        }
    }
    
    private func processVoiceCommand(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let command = userInfo["command"] as? String,
              let fullText = userInfo["fullText"] as? String else { return }
        print("Voice command received: \(command) from: \(fullText)")
        
        let lowerText = fullText.lowercased()
        for device in devices {
            let deviceName = device.name.lowercased()
            if lowerText.contains(deviceName) {
                if lowerText.contains("turn on") {
                    NetworkManager.sendCommand(port: device.port, action: "on") { state in
                        DispatchQueue.main.async {
                            if let state = state {
                                logManager.addLog("\(device.name) turned \(state)")
                            }
                        }
                    }
                } else if lowerText.contains("turn off") {
                    NetworkManager.sendCommand(port: device.port, action: "off") { state in
                        DispatchQueue.main.async {
                            if let state = state {
                                logManager.addLog("\(device.name) turned \(state)")
                            }
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
            if rule.name != "Security System" {
                NetworkManager.deleteAutomationRule(ruleName: rule.name) { success in
                DispatchQueue.main.async {
                    if success {
                        // Now remove it from local
                        if let idx = automationRules.firstIndex(where: { $0.id == rule.id }) {
                                automationRules.remove(at: idx)
                            }
                            logManager.addLog("Deleted automation: \(rule.name)")
                        } else {
                            showError("Failed to delete automation on device.")
                        }
                    }
                }
            } else {
                showError("Security System cannot be deleted.")
            }
        case .toggleOn:
            logManager.addLog("\(rule.name) toggled on.")
            NetworkManager.fetchAutomationRules { fetchedRules in
                if let rules = fetchedRules {
                    DispatchQueue.main.async {
                        automationRules = rules
                    }
                }
            }
        case .toggleOff:
            logManager.addLog("\(rule.name) toggled off.")
            NetworkManager.fetchAutomationRules { fetchedRules in
                if let rules = fetchedRules {
                    DispatchQueue.main.async {
                        automationRules = rules
                    }
                }
            }
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
    
    private func updateDeviceStatuses(with sensorDict: [String: Any]) {
        let temperatureStr: String
        if let tempNum = sensorDict["temperature"] as? Double {
            temperatureStr = String(format: "%.1f", tempNum)
        } else if let tempStr = sensorDict["temperature"] as? String {
            temperatureStr = tempStr
        } else {
            temperatureStr = "NaN"
        }
        
        let humidityStr: String
        if let humNum = sensorDict["humidity"] as? Double {
            humidityStr = String(format: "%.1f", humNum)
        } else if let humStr = sensorDict["humidity"] as? String {
            humidityStr = humStr
        } else {
            humidityStr = "NaN"
        }
        
        var fahrenheitStr = "NaN"
        if let celsius = Double(temperatureStr) {
            let fahrenheit = celsius * 9.0 / 5.0 + 32.0
            fahrenheitStr = String(format: "%.0f", fahrenheit)
        }
        let temperatureCombined = fahrenheitStr + "°F, " + humidityStr + "%"
        
        let pir = sensorDict["pir"] as? String ?? "No motion"
        let rfid = sensorDict["rfid"] as? String ?? "Active"
        let lcd = sensorDict["lcd"] as? String ?? "Ready"
        
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
        // e.g. after your switch statement, still inside updateDeviceStatuses
        if let strip1 = sensorDict["strip1Color"] as? String {
            if let idx = devices.firstIndex(where: { $0.port == "GPIO32" }) {
                devices[idx].isOn = (strip1 != "000000")
                devices[idx].status = devices[idx].isOn ? "On" : "Off"
            }
        }
        if let strip2 = sensorDict["strip2Color"] as? String {
            if let idx = devices.firstIndex(where: { $0.port == "GPIO33" }) {
                devices[idx].isOn = (strip2 != "000000")
                devices[idx].status = devices[idx].isOn ? "On" : "Off"
            }
        }
        if let fanVal = sensorDict["fanOn"] as? Bool {
            if let idx = devices.firstIndex(where: { $0.port == "GPIO26" }) {
                devices[idx].isOn = fanVal
                devices[idx].status = fanVal ? "On" : "Off"
            }
        }
        if let buzzerVal = sensorDict["buzzerOn"] as? Bool {
            if let idx = devices.firstIndex(where: { $0.port == "GPIO17" }) {
                devices[idx].isOn = buzzerVal
                devices[idx].status = buzzerVal ? "On" : "Off"
            }
        }

        if let ledVal = sensorDict["statusLedOn"] as? Bool {
            if let idx = devices.firstIndex(where: { $0.port == "GPIO2" }) {
                devices[idx].isOn = ledVal
                devices[idx].status = ledVal ? "On" : "Off"
            }
        }
        
        // Add these new parsers
            if let fanState = sensorDict["fanOn"] as? Bool {
                updateDeviceStatus(port: "GPIO26", isOn: fanState)
            }
            if let buzzerState = sensorDict["buzzerOn"] as? Bool {
                updateDeviceStatus(port: "GPIO17", isOn: buzzerState)
            }
            if let strip1State = sensorDict["strip1On"] as? Bool {
                updateDeviceStatus(port: "GPIO32", isOn: strip1State)
            }
            if let strip2State = sensorDict["strip2On"] as? Bool {
                updateDeviceStatus(port: "GPIO33", isOn: strip2State)
            }
            if let servo1Angle = sensorDict["servo1"] as? Int {
                updateServoStatus(port: "GPIO27", angle: servo1Angle)
            }
            if let servo2Angle = sensorDict["servo2"] as? Int {
                updateServoStatus(port: "GPIO14", angle: servo2Angle)
            }
    }
    
    private func updateDeviceStatus(port: String, isOn: Bool) {
        if let index = devices.firstIndex(where: { $0.port == port }) {
            devices[index].isOn = isOn
            devices[index].status = isOn ? "On" : "Off"
        }
    }

    private func updateServoStatus(port: String, angle: Int) {
        if let index = devices.firstIndex(where: { $0.port == port }) {
            let isOpen = (angle > 5) // Adjust based on your servo configuration
            devices[index].status = isOpen ? "Opened" : "Closed"
            devices[index].isOn = isOpen
        }
    }
    
    private func syncConnectivity() {
        SyncManager.checkConnection(globalIP: Config.globalESPIP) { connected in
            isConnected = connected
            for index in devices.indices {
                devices[index].isOnline = connected
            }
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
