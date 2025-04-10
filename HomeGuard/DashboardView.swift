import SwiftUI

struct DashboardView: View {
    @State private var devices: [Device] = []
    @State private var automationRules: [AutomationRule] = []
    
    @StateObject var speechManager = SpeechManager()
    @StateObject var logManager = EventLogManager()
    
    @State private var isConnected: Bool = false
    
    @State private var showEditAutomation: AutomationRule? = nil
    @State private var deviceForEdit: Device? = nil
    @State private var showLog = false
    @State private var errorMessage: String = ""
    @State private var lastAISuggestionFetch = Date.distantPast
    
    @State private var selectedLCDDevice: Device? = nil
    @State private var selectedCameraDevice: Device? = nil
    @State private var showLCDSettings = false
    @State private var showCameraLivestream = false
    @State private var isReordering: Bool = false
    
    @State private var showSecuritySettings = false
    
    @State private var showAddAutomation = false
    
    @State private var securityAutomation: AutomationRule = AutomationRule(
        id: UUID().uuidString,
        name: "Security System",
        condition: "RFID Allowed",
        action: "Active",
        activeDays: "M,Tu,W,Th,F,Sa,Su",
        triggerEnabled: true,
        triggerTime: Date()
    )
    
    @State private var sensorTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State private var aiGeneratedAutomation: AutomationRule? = nil
    @State private var showAIProcessing = false

    // We'll store the board's simTime from the last fetch
    @State private var boardSimTime: Double = 0.0
    
    var body: some View {
        let mainContent = contentView
            .toolbar { toolbarContent }
            .onAppear {
                speechManager.logManager = logManager
                
                if devices.isEmpty {
                    devices = Device.defaultDevices()
                }
                if !automationRules.contains(where: { $0.name == "Security System" }) {
                    automationRules.insert(securityAutomation, at: 0)
                }
                
                syncConnectivity()
                
                NetworkManager.fetchAutomationRules { fetchedRules in
                    if let fetched = fetchedRules {
                        DispatchQueue.main.async {
                            self.automationRules = mergeAutomationRules(local: self.automationRules, fetched: fetched)
                        }
                    }
                }
                
                ChatGPTAPI.fetchAutomation(prompt: "Suggest a new automation rule for my home") { suggestedRule in
                    if let rule = suggestedRule {
                        DispatchQueue.main.async {
                            self.aiGeneratedAutomation = rule
                        }
                    }
                }
            }
            .onReceive(sensorTimer) { _ in
                syncConnectivity()
                NetworkManager.fetchSensorData { sensorDict in
                    guard let sensorDict = sensorDict else { return }
                    DispatchQueue.main.async {
                        // Update statuses
                        updateDeviceStatuses(with: sensorDict)
                        // Grab simTime for the UI clock
                        if let st = sensorDict["simTime"] as? Double {
                            boardSimTime = st
                        }
                    }
                }
                // Also fetch logs from the firmware
                logManager.fetchDeviceLogs { newLogs in
                    DispatchQueue.main.async {
                        // Overwrite or append, your call.
                        // If you want them all, do a merge.
                        // Here, let's just replace with the new logs from the device:
                        logManager.logs = newLogs.reversed()
                    }
                }
                // Optionally refresh automations each poll
                NetworkManager.fetchAutomationRules { fetchedRules in
                    if let fetched = fetchedRules {
                        DispatchQueue.main.async {
                            automationRules = mergeAutomationRules(local: automationRules, fetched: fetched)
                        }
                    }
                }
            }

        let withSheets = NavigationView {
            mainContent
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showAddAutomation) {
            AddAutomationView(
                automationRules: $automationRules,
                inputDevices: filteredSensors,
                outputDevices: filteredOutputs
            ) { newRule in
                // no local logging; firmware handles it
                showAddAutomation = false
                NetworkManager.fetchAutomationRules { fetchedRules in
                    if let rules = fetchedRules {
                        DispatchQueue.main.async {
                            automationRules = rules
                        }
                    }
                }
            }
        }
        .sheet(item: $deviceForEdit) { device in
            EditDeviceView(device: device) { updatedDevice in
                if let index = devices.firstIndex(where: { $0.id == updatedDevice.id }) {
                    devices[index] = updatedDevice
                }
                deviceForEdit = nil
            }
        }
        .sheet(item: $showEditAutomation) { rule in
            if rule.name == "Security System" {
                SecuritySettingsView(rule: $securityAutomation)
            } else {
                EditAutomationView(
                    rule: rule,
                    inputDevices: filteredSensors,
                    outputDevices: filteredOutputs
                ) { updatedRule in
                    if let index = automationRules.firstIndex(where: { $0.id == updatedRule.id }) {
                        automationRules[index] = updatedRule
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
            let streamURL = URL(string: "http://\(Config.cameraIP):81/stream")!
            CameraLivestreamView(streamURL: streamURL)
        }
        .sheet(isPresented: $showSecuritySettings) {
            SecuritySettingsView(rule: $securityAutomation)
        }
        .onChange(of: devices) {
            speechManager.currentDevices = devices
            let deviceIDs = devices.map { $0.id.uuidString }
            UserDefaults.standard.set(deviceIDs, forKey: "deviceOrder")
        }
        .onChange(of: automationRules) {
            speechManager.currentAutomations = automationRules
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceCommandReceived)) { notification in
            processVoiceCommand(notification: notification)
        }

        return withSheets
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Example: add a clock label that matches firmware
                HeaderView(title: "HomeGuard Dashboard")
                
                // Show the scaled time from the board
                Text("Firmware Clock: \(scaledMillisToString(boardSimTime))")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                WiFiStatusView(isConnected: isConnected)
                    .padding(.horizontal)
                
                SecuritySystemBannerView(rule: securityAutomation) {
                    showSecuritySettings = true
                }
                .padding(.horizontal)
                
                AutomationsAreaView(
                    automationRules: automationRules.filter { $0.name != "Security System" },
                    aiGeneratedAutomation: aiGeneratedAutomation,
                    onAdd: { showAddAutomation = true },
                    onAcceptAISuggestion: {
                        if let aiAutomation = aiGeneratedAutomation {
                            // firmware logs it
                            automationRules.append(aiAutomation)
                            aiGeneratedAutomation = nil
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
                    },
                    onContextAction: { rule, action in
                        handleAutomationAction(rule: rule, action: action)
                    },
                    addEnabled: !devices.isEmpty
                )

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
                    logManager: logManager,
                    isReordering: isReordering
                )
                .padding(.horizontal)

                VoiceControlButton(speechManager: speechManager)
            }
            .padding(.vertical)
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    isReordering.toggle()
                }) {
                    Image(systemName: isReordering ? "checkmark" : "gearshape.fill")
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
    
    private var filteredSensors: [Device] {
        devices.filter { d in
            d.deviceType == .sensor ||
            d.deviceType == .temperature ||
            d.deviceType == .humidity ||
            d.deviceType == .motion
        }
    }
    
    private var filteredOutputs: [Device] {
        devices.filter { d in
            d.deviceType == .fan ||
            d.deviceType == .light ||
            d.deviceType == .servo ||
            d.deviceType == .buzzer ||
            d.deviceType == .statusLED ||
            d.deviceType == .door
        }
    }
    
    private func processVoiceCommand(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let _ = userInfo["command"] as? String,
              let fullText = userInfo["fullText"] as? String else { return }
        _ = fullText.lowercased()
        // Example: you can parse or do nothing here, since SpeechManager also does it
    }
    
    private func handleAutomationAction(rule: AutomationRule, action: AutomationContextAction) {
        switch action {
        case .edit:
            showEditAutomation = rule
        case .delete:
            if rule.name != "Security System" {
                NetworkManager.deleteAutomationRule(uid: rule.id) { success in
                    DispatchQueue.main.async {
                        if success {
                            if let idx = automationRules.firstIndex(where: { $0.id == rule.id }) {
                                automationRules.remove(at: idx)
                            }
                        } else {
                            showError("Failed to delete automation on device.")
                        }
                    }
                }
            } else {
                showError("Security System cannot be deleted.")
            }
        case .toggleOn, .toggleOff:
            NetworkManager.toggleAutomationRule(uid: rule.id) { success in
                DispatchQueue.main.async {
                    if !success {
                        showError("Failed to toggle automation on device.")
                    } else {
                        NetworkManager.fetchAutomationRules { fetched in
                            if let fetched = fetched {
                                DispatchQueue.main.async {
                                    self.automationRules = mergeAutomationRules(local: self.automationRules, fetched: fetched)
                                }
                            }
                        }
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
            let isOpen = (angle > 5)
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
