import SwiftUI

struct EditAutomationView: View {
    @Environment(\.dismiss) var dismiss
    @State var rule: AutomationRule
    var inputDevices: [Device]  // Sensors
    var outputDevices: [Device] // Outputs

    // Use String? for these IDs, to match AutomationRule.{input,output}DeviceID
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

    // Custom initializer that preloads the state from the rule:
    init(rule: AutomationRule,
         inputDevices: [Device],
         outputDevices: [Device],
         onSave: @escaping (AutomationRule) -> Void)
    {
        self._rule = State(initialValue: rule)
        self.inputDevices = inputDevices
        self.outputDevices = outputDevices
        self.onSave = onSave

        // Set selectedSensorID from rule.inputDeviceID (already a String?).
        if let sensorID = rule.inputDeviceID {
            self._selectedSensorID = State(initialValue: sensorID)
        } else {
            self._selectedSensorID = State(initialValue: nil)
        }

        // If the condition string contains something like "Greater Than 70", parse it.
        if let sensorID = rule.inputDeviceID,
           let sensor = inputDevices.first(where: { $0.id.uuidString == sensorID }),
           (sensor.deviceType == .temperature || sensor.deviceType == .humidity) {
            let comps = rule.condition.split(separator: " ")
            // E.g. comps = ["Greater", "Than", "75"]
            if comps.count >= 3 {
                let firstTwo = comps[0] + " " + comps[1] // "Greater Than" or "Less Than"
                self._comparison = State(initialValue: String(firstTwo))
                if let value = Double(comps[2]) {
                    self._thresholdValue = State(initialValue: value)
                }
            }
        }

        // Set selectedOutputID from rule.outputDeviceID (already a String?).
        if let outputID = rule.outputDeviceID {
            self._selectedOutputID = State(initialValue: outputID)
        } else {
            self._selectedOutputID = State(initialValue: nil)
        }

        // Determine output action by the last word in rule.action (e.g. "Kitchen Lights On")
        let actionComponents = rule.action.split(separator: " ")
        if let last = actionComponents.last {
            self._outputAction = State(initialValue: String(last))
        }

        // Set these from the rule
        self._useTriggerTime = State(initialValue: rule.triggerEnabled)
        self._triggerTime = State(initialValue: rule.triggerTime)

        // Parse activeDays from something like "M,Tu,W,Th,F"
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
                // Rule name + Input sensor
                Section(header: Text("Automation Details")) {
                    TextField("Rule Name", text: $rule.name)

                    if !inputDevices.isEmpty {
                        Picker("Input Sensor", selection: $selectedSensorID) {
                            Text("None").tag(String?.none)  // if user wants no sensor
                            ForEach(inputDevices) { device in
                                // Tag the device's UUID as a string
                                Text(device.name).tag(Optional(device.id.uuidString))
                            }
                        }
                    }
                }

                // Condition
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

                // Output device + on/off
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

                // Trigger time
                Section(header: Text("Trigger Time")) {
                    Toggle("Enable Trigger Time", isOn: $useTriggerTime)
                    if useTriggerTime {
                        DatePicker("Time", selection: $triggerTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                    }
                }

                // Active Days
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
        // Rebuild activeDays string
        let activeDayString = dayAbbreviations.enumerated()
            .filter { activeDays[$0.offset] }
            .map { $0.element }
            .joined(separator: ",")

        // Look up chosen sensor & output
        let sensor = inputDevices.first(where: { $0.id.uuidString == selectedSensorID })
        let outDevice = outputDevices.first(where: { $0.id.uuidString == selectedOutputID })

        // Build condition
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

        // Build final action
        var finalAction = "Execute"
        if let outDevice = outDevice {
            finalAction = "\(outDevice.name) \(outputAction)"
        }

        // Update the rule
        rule.condition = condition
        rule.action = finalAction
        rule.activeDays = activeDayString
        rule.triggerEnabled = useTriggerTime
        rule.triggerTime = triggerTime
        // Store the device IDs as strings (matching the firmware model):
        rule.inputDeviceID = selectedSensorID
        rule.outputDeviceID = selectedOutputID

        onSave(rule)
        dismiss()
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
