import SwiftUI

// MARK: – Central sheet enum
enum DashboardSheet: Identifiable, Equatable {
    case led(Device), lcd, cam, dht, eventLog
    case addAutomation, editAutomation(AutomationRule), editDevice(Device)
    case securitySettings

    var id: String {
        switch self {
        case .led(let d):            return "led"  + d.id.uuidString
        case .lcd:                   return "lcd"
        case .cam:                   return "cam"
        case .dht:                   return "dht"
        case .eventLog:              return "eventLog"
        case .addAutomation:         return "addAutomation"
        case .editAutomation(let r): return "editAuto" + r.id
        case .editDevice(let d):     return "editDev"  + d.id.uuidString
        case .securitySettings:      return "security"
        }
    }
}

struct DashboardView: View {
    // -----------------------------------------------------------------------
    // MARK: – State
    // -----------------------------------------------------------------------
    @State private var devices: [Device]                 = []
    @State private var automationRules: [AutomationRule] = []

    @StateObject private var speechManager = SpeechManager()
    @StateObject private var logManager    = EventLogManager()

    @State private var isConnected  = false
    @State private var isReordering = false
    @State private var activeSheet: DashboardSheet?

    // AI suggestion
    @State private var aiGeneratedAutomation: AutomationRule?

    // Firmware clock
    @State private var boardSimTime: Double = 0.0

    // timers
    @State private var sensorTimer =
        Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    // Banner
    @State private var banner: BannerData?
    @State private var bannerTimer: Timer?

    // fixed security rule (always index 0)
    @State private var securityAutomation = AutomationRule(
        id: UUID().uuidString,
        name: "Security System",
        condition: "RFID Allowed",
        action: "Active",
        activeDays: "M,Tu,W,Th,F,Sa,Su",
        triggerEnabled: true,
        triggerTime: Date()
    )

    // -----------------------------------------------------------------------
    // MARK: – Body
    // -----------------------------------------------------------------------
    var body: some View {
        NavigationView {
            contentView                               // <── root of nav‑stack
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }           // <── attach toolbar HERE
        }
        .navigationViewStyle(.stack)
        .overlay(bannerOverlay, alignment: .top)

        .onAppear(perform: initialLoad)
        .onReceive(sensorTimer) { _ in periodicPoll() }
        .onDisappear { bannerTimer?.invalidate() }

        // ---------- SINGLE SHEET ----------
        .sheet(item: $activeSheet, content: sheetView)

        // ---------- Propagation ----------
        .onChange(of: devices)         { speechManager.currentDevices = devices }
        .onChange(of: automationRules) { speechManager.currentAutomations = automationRules }
        .onReceive(NotificationCenter.default.publisher(for: .voiceCommandReceived)) {
            processVoiceCommand(notification: $0)
        }
        .onReceive(logManager.$suggestedAutomation) { aiGeneratedAutomation = $0 }
    }

    // -----------------------------------------------------------------------
    // MARK: – Content
    // -----------------------------------------------------------------------
    private var contentView: some View {
        ScrollView {
            
            VStack(spacing: 16) {
                HeaderView(title: "HomeGuard Dashboard")

                Text("Firmware Clock: \(scaledMillisToString(boardSimTime))")
                    .font(.caption)
                    .foregroundColor(.gray)

                WiFiStatusView(isConnected: isConnected)
                    .padding(.horizontal)

                SecuritySystemBannerView(rule: securityAutomation) {
                    activeSheet = .securitySettings
                }
                .padding(.horizontal)

                AutomationsAreaView(
                    automationRules: automationRules.filter { $0.name != "Security System" },
                    aiGeneratedAutomation: aiGeneratedAutomation,
                    onAdd: { activeSheet = .addAutomation },
                    onAcceptAISuggestion: { self.acceptAISuggestion() },
                    onDismissAISuggestion: {
                        aiGeneratedAutomation = nil
                        activeSheet = nil
                    },
                    onContextAction: handleAutomationAction,
                    addEnabled: !devices.isEmpty
                )

                DevicesAreaView(
                    devices: $devices,
                    onSelect: { _ in },
                    onContextAction: handleDeviceAction,
                    onOpenSheet: { activeSheet = $0 },
                    logManager: logManager,
                    isReordering: isReordering
                )
                .padding(.horizontal)

                VoiceControlButton(speechManager: speechManager)
            }
            .padding(.vertical)
        }
        .scrollDisabled(isReordering)
    }

    // -----------------------------------------------------------------------
    // MARK: – Toolbar
    // -----------------------------------------------------------------------
    // MARK: – Toolbar
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { activeSheet = .eventLog } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title)       // larger
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { isReordering.toggle() } label: {
                    Image(systemName: isReordering ? "checkmark" : "gearshape.fill")
                        .font(.title)       // larger
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // MARK: – Sheet factory
    // -----------------------------------------------------------------------
    @ViewBuilder private func sheetView(for sheet: DashboardSheet) -> some View {
        switch sheet {

        case .led(let dev):
            LEDColorPickerView(devicePort: dev.port) { activeSheet = nil }

        case .lcd:
            LCDSettingsView()

        case .cam:
            CameraLivestreamView(
                streamURL: URL(string: "http://\(Config.cameraIP):81/stream")!
            )

        case .dht:
            DHT11ChartView()

        case .eventLog:
            EventLogView(logManager: logManager)

        case .addAutomation:
            AddAutomationView(
                automationRules: $automationRules,
                inputDevices: filteredSensors,
                outputDevices: filteredOutputs
            ) { _ in refreshAutomationRules() }

        case .editAutomation(let rule):
            if rule.name == "Security System" {
                SecuritySettingsView(rule: $securityAutomation)
            } else {
                EditAutomationView(
                    rule: rule,
                    inputDevices: filteredSensors,
                    outputDevices: filteredOutputs
                ) { updated in
                    if let idx = automationRules
                        .firstIndex(where: { $0.id == updated.id }) {
                        automationRules[idx] = updated
                    }
                }
            }

        case .editDevice(let dev):
            EditDeviceView(device: dev) { updated in
                if let idx = devices.firstIndex(where: { $0.id == updated.id }) {
                    devices[idx] = updated
                }
            }

        case .securitySettings:
            SecuritySettingsView(rule: $securityAutomation)
        }
    }

    // -----------------------------------------------------------------------
    // MARK: – Banner overlay
    // -----------------------------------------------------------------------
    private var bannerOverlay: some View {
        Group {
            if let banner = banner {
                BannerView(data: banner)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
    }

    // -----------------------------------------------------------------------
    // MARK: – Context‑menu handlers
    // -----------------------------------------------------------------------
    private func handleAutomationAction(
        rule: AutomationRule,
        action: AutomationContextAction
    ) {
        switch action {
        case .edit:
            activeSheet = .editAutomation(rule)

        case .delete:
            guard rule.name != "Security System" else {
                pushBanner("Security System cannot be deleted."); return
            }
            NetworkManager.deleteAutomationRule(uid: rule.id) { ok in
                DispatchQueue.main.async {
                    if ok {
                        automationRules.removeAll { $0.id == rule.id }
                    } else {
                        pushBanner("Failed to delete automation on device.")
                    }
                }
            }

        case .toggleOn, .toggleOff:
            NetworkManager.toggleAutomationRule(uid: rule.id) { ok in
                DispatchQueue.main.async {
                    if !ok { pushBanner("Failed to toggle automation on device.") }
                    refreshAutomationRules()
                }
            }

        default: break
        }
    }

    private func handleDeviceAction(
        device: Device,
        action: DeviceContextAction
    ) {
        switch action {
        case .edit:
            activeSheet = .editDevice(device)
        case .delete:
            pushBanner("Core devices cannot be deleted.")
        default:
            break
        }
    }

    // -----------------------------------------------------------------------
    // MARK: – Initial / periodic work
    // -----------------------------------------------------------------------
    private func initialLoad() {
        speechManager.logManager = logManager

        if devices.isEmpty { devices = Device.defaultDevices() }
        if !automationRules.contains(where: { $0.name == "Security System" }) {
            automationRules.insert(securityAutomation, at: 0)
        }

        syncConnectivity()
        refreshAutomationRules()

        ChatGPTAPI.fetchAutomation(prompt: "Suggest a new automation rule for my home") {
            rule, err in
            DispatchQueue.main.async {
                if let r = rule
                { aiGeneratedAutomation = r }
                else if let err = err
                { pushBanner(err) }
            }
        }
    }

    private func periodicPoll() {
        syncConnectivity()

        // 1 – sensor JSON
        NetworkManager.fetchSensorData { dict in
            guard let dict = dict else { return }
            DispatchQueue.main.async {
                updateDeviceStatuses(with: dict)
                if let st = dict["simTime"] as? Double { boardSimTime = st }
            }
        }

        // 2 – logs
        logManager.fetchDeviceLogs { logs in
            DispatchQueue.main.async {
                logManager.logs = logs.reversed()
                logManager.analyzeLogsForAutomation(
                    inputDevices: filteredSensors,
                    outputDevices: filteredOutputs
                )
            }
        }

        // 3 – rules
        refreshAutomationRules()
    }

    private func refreshAutomationRules() {
        NetworkManager.fetchAutomationRules { fetched in
            guard let fetched = fetched else { return }
            DispatchQueue.main.async {
                automationRules = mergeAutomationRules(
                    local: automationRules,
                    fetched: fetched
                )
            }
        }
    }

    // -----------------------------------------------------------------------
    // MARK: – Banner helper
    // -----------------------------------------------------------------------
    private func pushBanner(
        _ text: String,
        style: BannerData.BannerStyle = .error
    ) {
        banner = BannerData(title: text, style: style)
        bannerTimer?.invalidate()
        bannerTimer = Timer.scheduledTimer(withTimeInterval: 3,
                                           repeats: false) { _ in
            withAnimation { banner = nil }
        }
        withAnimation { }      // trigger transition
    }

    // -----------------------------------------------------------------------
    // MARK: – Helpers
    // -----------------------------------------------------------------------
    private var filteredSensors: [Device] {
        devices.filter {
            [.sensor, .temperature, .humidity, .motion].contains($0.deviceType)
        }
    }

    private var filteredOutputs: [Device] {
        devices.filter {
            [.fan, .light, .servo, .buzzer, .statusLED, .door].contains($0.deviceType)
        }
    }

    private func acceptAISuggestion() {
        guard let aiRule = aiGeneratedAutomation else { return }
        NetworkManager.sendAutomationRule(rule: aiRule) { ok in
            DispatchQueue.main.async {
                if ok {
                    pushBanner("AI rule saved!", style: .success)
                    aiGeneratedAutomation = nil
                    refreshAutomationRules()
                } else {
                    pushBanner("Failed to save AI rule.")
                }
            }
        }
    }

    private func processVoiceCommand(notification: Notification) {
        guard let info = notification.userInfo,
              let _ = info["command"] as? String,
              let full = info["fullText"] as? String else { return }
        _ = full.lowercased()
        // heavy lifting is inside SpeechManager
    }

    // ---------- Device‑status parsing ----------
    private func updateDeviceStatuses(with dict: [String: Any]) {
        // --- Temperature & humidity string build ---
        let tempStr: String
        if let v = dict["temperature"] as? Double {
            tempStr = String(format: "%.1f", v)
        } else {
            tempStr = dict["temperature"] as? String ?? "NaN"
        }
        let humStr: String
        if let v = dict["humidity"] as? Double {
            humStr = String(format: "%.1f", v)
        } else {
            humStr = dict["humidity"] as? String ?? "NaN"
        }
        var fahrenheit = "NaN"
        if let c = Double(tempStr) {
            fahrenheit = String(format: "%.0f", c * 9/5 + 32)
        }
        let tempCombined = "\(fahrenheit)°F, \(humStr)%"

        // --- Update every device row ---
        for i in devices.indices {
            switch devices[i].deviceType {
            case .temperature: devices[i].status = tempCombined
            case .humidity:    devices[i].status = "\(humStr)%"
            case .motion:      devices[i].status = dict["pir"] as? String ?? "No motion"
            case .rfid:        devices[i].status = dict["rfid"] as? String ?? "Active"
            case .lcd:         devices[i].status = dict["lcd"]  as? String ?? "Ready"
            default: break
            }
        }

        // Simple on/off helpers
        if let s1 = dict["strip1Color"] as? String {
            updateDeviceStatus(port: "GPIO32", isOn: s1 != "000000")
        }
        if let s2 = dict["strip2Color"] as? String {
            updateDeviceStatus(port: "GPIO33", isOn: s2 != "000000")
        }
        if let fan = dict["fanOn"] as? Bool    { updateDeviceStatus(port: "GPIO26", isOn: fan) }
        if let buz = dict["buzzerOn"] as? Bool { updateDeviceStatus(port: "GPIO17", isOn: buz) }
        if let led = dict["statusLedOn"] as? Bool { updateDeviceStatus(port: "GPIO2", isOn: led) }

        // Servos
        if let s1 = dict["servo1"] as? Int { updateServoStatus(port: "GPIO27", angle: s1) }
        if let s2 = dict["servo2"] as? Int { updateServoStatus(port: "GPIO14", angle: s2) }
    }

    private func updateDeviceStatus(port: String, isOn: Bool) {
        if let idx = devices.firstIndex(where: { $0.port == port }) {
            devices[idx].isOn   = isOn
            devices[idx].status = isOn ? "On" : "Off"
        }
    }

    private func updateServoStatus(port: String, angle: Int) {
        if let idx = devices.firstIndex(where: { $0.port == port }) {
            let open = angle > 5
            devices[idx].isOn   = open
            devices[idx].status = open ? "Opened" : "Closed"
        }
    }

    // ---------- Connectivity ----------
    private func syncConnectivity() {
        SyncManager.checkConnection(globalIP: Config.globalESPIP) { ok in
            isConnected = ok
            for i in devices.indices { devices[i].isOnline = ok }
        }
    }
}

// -----------------------------------------------------------------------
// MARK: – Preview
// -----------------------------------------------------------------------
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
