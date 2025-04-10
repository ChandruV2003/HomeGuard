import SwiftUI

struct EditAutomationView: View {
    @Environment(\.dismiss) var dismiss
    @State var rule: AutomationRule
    var inputDevices: [Device]
    var outputDevices: [Device]

    @State private var selectedSensorID: String? = nil
    @State private var comparison: String = "Greater Than"
    @State private var thresholdValue: Double = 70

    @State private var selectedOutputID: String? = nil
    @State private var outputAction: String = "On"

    @State private var useTriggerTime: Bool = false
    @State private var triggerTime: Date = Date()
    @State private var activeDays: [Bool] = Array(repeating: false, count: 7)

    let dayAbbreviations = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    let comparisonOptions = ["Greater Than", "Less Than"]
    let onOffOptions      = ["On", "Off"]

    var onSave: (AutomationRule) -> Void

    init(rule: AutomationRule,
         inputDevices: [Device],
         outputDevices: [Device],
         onSave: @escaping (AutomationRule) -> Void)
    {
        self._rule = State(initialValue: rule)
        self.inputDevices = inputDevices
        self.outputDevices = outputDevices
        self.onSave = onSave

        if let sensorID = rule.inputDeviceID {
            self._selectedSensorID = State(initialValue: sensorID)
        }
        // parse condition
        if let sensorID = rule.inputDeviceID,
           let sensor = inputDevices.first(where: { $0.id.uuidString == sensorID }),
           (sensor.deviceType == .temperature || sensor.deviceType == .humidity) {
            let comps = rule.condition.split(separator: " ")
            if comps.count >= 3 {
                let firstTwo = comps[0] + " " + comps[1]
                self._comparison = State(initialValue: String(firstTwo))
                if let value = Double(comps[2]) {
                    self._thresholdValue = State(initialValue: value)
                }
            }
        }
        if let outputID = rule.outputDeviceID {
            self._selectedOutputID = State(initialValue: outputID)
        }
        let actionComponents = rule.action.split(separator: " ")
        if let last = actionComponents.last {
            self._outputAction = State(initialValue: String(last))
        }
        self._useTriggerTime = State(initialValue: rule.triggerEnabled)
        self._triggerTime = State(initialValue: rule.triggerTime)
        
        let daysFromRule = rule.activeDays.split(separator: ",").map { String($0) }
        var actives = [Bool](repeating: false, count: 7)
        for (index, dayAbbrev) in dayAbbreviations.enumerated() {
            if daysFromRule.contains(dayAbbrev) {
                actives[index] = true
            }
        }
        self._activeDays = State(initialValue: actives)
    }

    var body: some View {
        NavigationView {
            Form {
                // same sections
                Section(header: Text("Automation Details")) {
                    TextField("Rule Name", text: $rule.name)
                    if !inputDevices.isEmpty {
                        Picker("Input Sensor", selection: $selectedSensorID) {
                            Text("None").tag(String?.none)
                            ForEach(inputDevices) { device in
                                Text(device.name).tag(Optional(device.id.uuidString))
                            }
                        }
                    }
                }

                if let sensorID = selectedSensorID,
                   let sensor = inputDevices.first(where: { $0.id.uuidString == sensorID }) {
                    if sensor.deviceType == .temperature || sensor.deviceType == .humidity {
                        Section(header: Text("Condition")) {
                            Picker("Comparison", selection: $comparison) {
                                ForEach(comparisonOptions, id: \.self) { Text($0) }
                            }
                            Slider(value: $thresholdValue,
                                   in: sensor.deviceType == .temperature ? 0...120 : 0...100,
                                   step: 1)
                            Text("Threshold: \(Int(thresholdValue))\(sensor.deviceType == .temperature ? "°F" : "%")")
                        }
                    } else if sensor.deviceType == .motion {
                        Section(header: Text("Condition")) {
                            Text("Motion Detected")
                        }
                    }
                }

                Section(header: Text("Output Device & Action")) {
                    if !outputDevices.isEmpty {
                        Picker("Output Device", selection: $selectedOutputID) {
                            Text("None").tag(String?.none)
                            ForEach(outputDevices) { device in
                                Text(device.name).tag(Optional(device.id.uuidString))
                            }
                        }
                    }
                    Picker("Action", selection: $outputAction) {
                        ForEach(onOffOptions, id: \.self) { Text($0) }
                    }
                }

                Section(header: Text("Trigger Time")) {
                    Toggle("Enable Trigger Time", isOn: $useTriggerTime)
                    if useTriggerTime {
                        DatePicker("Time", selection: $triggerTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                    }
                }

                Section(header: Text("Active Days")) {
                    HStack {
                        ForEach(0..<dayAbbreviations.count, id: \.self) { index in
                            Button(action: {
                                activeDays[index].toggle()
                            }) {
                                Text(dayAbbreviations[index])
                                    .font(.caption)
                                    .frame(width: 30, height: 30)
                                    .background(activeDays[index] ? Color.blue : Color.gray.opacity(0.3))
                                    .clipShape(Circle())
                                    .foregroundColor(activeDays[index] ? .white : .black)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contentShape(Circle())
                        }
                    }
                }
            }
            .navigationTitle("Edit Automation")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAutomation() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Save
    private func saveAutomation() {
        let activeDayString = dayAbbreviations.enumerated()
            .filter { activeDays[$0.offset] }
            .map { $0.element }
            .joined(separator: ",")

        let sensor = inputDevices.first(where: { $0.id.uuidString == selectedSensorID })
        let outDevice = outputDevices.first(where: { $0.id.uuidString == selectedOutputID })

        var condition = ""
        if let sensor = sensor {
            switch sensor.deviceType {
            case .temperature, .humidity:
                condition = "\(comparison) \(Int(thresholdValue))"
            case .motion:
                condition = "Motion Detected"
            default:
                break
            }
        }

        var finalAction = "Execute"
        if let outDevice = outDevice {
            finalAction = "\(outDevice.name) \(outputAction)"
        }

        let isConditionBased: Bool = {
            if let s = sensor {
                return s.deviceType == .temperature
                    || s.deviceType == .humidity
                    || s.deviceType == .motion
            }
            return false
        }()

        // Rebuild the rule in memory
        rule.condition = condition
        rule.action = finalAction
        rule.activeDays = activeDayString
        rule.triggerEnabled = !isConditionBased && useTriggerTime
        rule.inputDeviceID = selectedSensorID
        rule.outputDeviceID = selectedOutputID

        // Temporarily set to 0, then adjust after we fetch the board's time
        rule.triggerTime = Date(timeIntervalSince1970: 0)

        // If it's condition-based, firmware ignores time
        if isConditionBased {
            rule.triggerTime = Date(timeIntervalSince1970: 0)
        }

        // Fetch the board’s simTime first
        NetworkManager.fetchSensorData { dict in
            guard let dict = dict, let boardNow = dict["simTime"] as? Double else {
                // fallback
                sendRuleToFirmware(rule)
                return
            }
            if !isConditionBased && self.useTriggerTime {
                let realDiffSeconds = self.triggerTime.timeIntervalSinceNow
                let scaledDiff = realDiffSeconds * 1000.0 * Config.timeAcceleration
                let finalScaled = max(boardNow + scaledDiff, 0)
                rule.triggerTime = Date(timeIntervalSince1970: finalScaled)
            } else {
                rule.triggerTime = Date(timeIntervalSince1970: 0)
            }
            sendRuleToFirmware(rule)
        }
    }

    private func sendRuleToFirmware(_ updatedRule: AutomationRule) {
        NetworkManager.sendAutomationRule(rule: updatedRule) { success in
            DispatchQueue.main.async {
                if success {
                    NetworkManager.fetchAutomationRules { fetchedRules in
                        if fetchedRules != nil {
                            DispatchQueue.main.async {
                                // Merge them locally if you wish
                                // Or just replace automation rules
                                self.onSave(updatedRule)
                            }
                        }
                    }
                } else {
                    // Even if not successful, do local onSave
                    self.onSave(updatedRule)
                }
                dismiss()
            }
        }
    }
}


// MARK: - Preview
struct EditAutomationView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSensor = Device.create(
            name: "Temperature Sensor",
            status: "Off",
            deviceType: .temperature,
            port: "GPIO4"
        )
        let sampleOutput = Device.create(
            name: "Kitchen Lights",
            status: "Off",
            deviceType: .light,
            port: "GPIO32"
        )
        let sampleRule = AutomationRule(
            id: UUID().uuidString,
            name: "Test Automation",
            condition: "Greater Than 75",
            action: "Kitchen Lights On",
            activeDays: "M,Tu,W,Th,F",
            triggerEnabled: true,
            triggerTime: Date(),
            // Note how we store device IDs as strings:
            inputDeviceID: sampleSensor.id.uuidString,
            outputDeviceID: sampleOutput.id.uuidString
        )

        return EditAutomationView(
            rule: sampleRule,
            inputDevices: [sampleSensor],
            outputDevices: [sampleOutput]
        ) { updatedRule in
            print("Updated rule: \(updatedRule)")
        }
    }
}
