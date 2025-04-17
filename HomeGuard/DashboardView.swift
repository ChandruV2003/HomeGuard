//
//  DashboardView.swift
//  HomeGuard
//

import SwiftUI

struct DashboardView: View {

    // ------------------------------------------------------------
    // MARK: – State
    // ------------------------------------------------------------
    @State private var devices: [Device]                 = []
    @State private var automationRules: [AutomationRule] = []

    @StateObject private var speechManager = SpeechManager()
    @StateObject private var logManager    = EventLogManager()

    @State private var isConnected = false

    // Context‑menus / sheets
    @State private var showEditAutomation: AutomationRule?
    @State private var deviceForEdit: Device?
    @State private var showLog            = false
    @State private var showAddAutomation  = false
    @State private var showLCDSettings    = false
    @State private var showCameraLive     = false
    @State private var showSecuritySettings = false
    @State private var isReordering       = false

    // AI
    @State private var aiGeneratedAutomation: AutomationRule?

    // Firmware clock
    @State private var boardSimTime: Double = 0.0
    @State private var sensorTimer = Timer.publish(every: 1,
                                                   on: .main,
                                                   in: .common).autoconnect()

    // ---------- Security rule (fixed) ----------
    @State private var securityAutomation = AutomationRule(
        id: UUID().uuidString,
        name: "Security System",
        condition: "RFID Allowed",
        action: "Active",
        activeDays: "M,Tu,W,Th,F,Sa,Su",
        triggerEnabled: true,
        triggerTime: Date()
    )

    // ---------- Banner ----------
    @State private var banner: BannerData?
    @State private var bannerTimer: Timer?

    // ------------------------------------------------------------
    // MARK: – View
    // ------------------------------------------------------------
    var body: some View {
        let main = contentView
            .toolbar { toolbarContent }
            .onAppear(perform: initialLoad)
            .onReceive(sensorTimer) { _ in periodicPoll() }
            .overlay(
                Group {
                    if let banner = banner {
                        BannerView(data: banner)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(1)
                    }
                },
                alignment: .top
            )
            .onDisappear { bannerTimer?.invalidate() }

        return NavigationView { main }
            .navigationViewStyle(.stack)
            // ------------------------------------------------
            // MARK: – Sheets
            // ------------------------------------------------
            .sheet(isPresented: $showAddAutomation) {
                AddAutomationView(
                    automationRules: $automationRules,
                    inputDevices: filteredSensors,
                    outputDevices: filteredOutputs
                ) { _ in refreshAutomationRules() }
            }
            .sheet(item: $deviceForEdit) { device in
                EditDeviceView(device: device) { updated in
                    if let idx = devices.firstIndex(where: { $0.id == updated.id }) {
                        devices[idx] = updated
                    }
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
                    ) { updated in
                        if let idx = automationRules.firstIndex(where: { $0.id == updated.id }) {
                            automationRules[idx] = updated
                        }
                    }
                }
            }
            .sheet(isPresented: $showLog) {
                EventLogView(logManager: logManager)
            }
            .sheet(isPresented: $showLCDSettings) {
                LCDSettingsView()
            }
            .sheet(isPresented: $showCameraLive) {
                let url = URL(string: "http://\(Config.cameraIP):81/stream")!
                CameraLivestreamView(streamURL: url)
            }
            .sheet(isPresented: $showSecuritySettings) {
                SecuritySettingsView(rule: $securityAutomation)
            }
            // ------------------------------------------------
            // MARK: – Propagate changes
            // ------------------------------------------------
            .onChange(of: devices) {
                speechManager.currentDevices = devices
                let ids = devices.map { $0.id.uuidString }
                UserDefaults.standard.set(ids, forKey: "deviceOrder")
            }
            .onChange(of: automationRules) {
                speechManager.currentAutomations = automationRules
            }
            .onReceive(NotificationCenter.default.publisher(for: .voiceCommandReceived)) {
                processVoiceCommand(notification: $0)
            }
    }

    // ------------------------------------------------------------
    // MARK: – Content
    // ------------------------------------------------------------
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
                    showSecuritySettings = true
                }
                .padding(.horizontal)

                AutomationsAreaView(
                    automationRules: automationRules.filter { $0.name != "Security System" },
                    aiGeneratedAutomation: aiGeneratedAutomation,
                    onAdd: { showAddAutomation = true },
                    onAcceptAISuggestion: acceptAISuggestion,
                    onDismissAISuggestion: { aiGeneratedAutomation = nil },
                    onContextAction: handleAutomationAction,
                    addEnabled: !devices.isEmpty
                )

                DevicesAreaView(
                    devices: $devices,
                    onSelect: { device in
                        switch device.deviceType {
                        case .lcd:    showLCDSettings = true
                        case .espCam: showCameraLive  = true
                        default:      break
                        }
                    },
                    onContextAction: handleDeviceAction,
                    logManager: logManager,
                    isReordering: isReordering
                )
                .padding(.horizontal)

                VoiceControlButton(speechManager: speechManager)
            }
            .padding(.vertical)
        }
    }

    // ------------------------------------------------------------
    // MARK: – Toolbar
    // ------------------------------------------------------------
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { isReordering.toggle() } label: {
                    Image(systemName: isReordering ? "checkmark" : "gearshape.fill")
                        .font(.title)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showLog = true } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                }
            }
        }
    }

    // ------------------------------------------------------------
    // MARK: – Initial & periodic work
    // ------------------------------------------------------------
    private func initialLoad() {
        speechManager.logManager = logManager

        if devices.isEmpty { devices = Device.defaultDevices() }
        if !automationRules.contains(where: { $0.name == "Security System" }) {
            automationRules.insert(securityAutomation, at: 0)
        }

        syncConnectivity()
        refreshAutomationRules()

        // ---- AI suggestion ------------------------------------
        ChatGPTAPI.fetchAutomation(prompt: "Suggest a new automation rule for my home") {
            rule, err in
            DispatchQueue.main.async {
                if let r = rule {
                    aiGeneratedAutomation = r
                } else if let err = err {
                    pushBanner(err)
                }
            }
        }
    }

    private func periodicPoll() {
        syncConnectivity()

        NetworkManager.fetchSensorData { dict in
            guard let dict = dict else { return }
            DispatchQueue.main.async {
                updateDeviceStatuses(with: dict)
                if let st = dict["simTime"] as? Double { boardSimTime = st }
            }
        }

        logManager.fetchDeviceLogs { logs in
            DispatchQueue.main.async { logManager.logs = logs.reversed() }
        }

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

    // ------------------------------------------------------------
    // MARK: – Banner helper
    // ------------------------------------------------------------
    private func pushBanner(_ text: String,
                            style: BannerData.BannerStyle = .error) {
        banner = BannerData(title: text, style: style)
        bannerTimer?.invalidate()
        bannerTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            withAnimation { banner = nil }
        }
        withAnimation { } // trigger transition
    }

    // ------------------------------------------------------------
    // MARK: – Context‑menu handlers
    // ------------------------------------------------------------
    private func handleAutomationAction(rule: AutomationRule,
                                        action: AutomationContextAction) {
        switch action {
        case .edit:
            showEditAutomation = rule

        case .delete:
            guard rule.name != "Security System" else {
                pushBanner("Security System cannot be deleted.")
                return
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

    private func handleDeviceAction(device: Device,
                                    action: DeviceContextAction) {
        switch action {
        case .edit:
            deviceForEdit = device
        case .delete:
            pushBanner("Core devices cannot be deleted.")
        default:
            break
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

    // ------------------------------------------------------------
    // MARK: – Helpers
    // ------------------------------------------------------------
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

    private func processVoiceCommand(notification: Notification) {
        guard let info = notification.userInfo,
              let _ = info["command"] as? String,
              let full = info["fullText"] as? String else { return }
        _ = full.lowercased()
        // The heavy lifting already happens inside SpeechManager.
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
            devices[idx].isOn = isOn
            devices[idx].status = isOn ? "On" : "Off"
        }
    }

    private func updateServoStatus(port: String, angle: Int) {
        if let idx = devices.firstIndex(where: { $0.port == port }) {
            let open = angle > 5
            devices[idx].isOn    = open
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

// ------------------------------------------------------------
// MARK: – Preview
// ------------------------------------------------------------
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
