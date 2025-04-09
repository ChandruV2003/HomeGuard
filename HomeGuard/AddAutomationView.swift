import SwiftUI

struct AddAutomationView: View {
    @Binding var automationRules: [AutomationRule] // Add this
    @EnvironmentObject var logManager: EventLogManager // Add this


    @Environment(\.dismiss) var dismiss

    var inputDevices: [Device]      // e.g. temperature, motion, humidity
    var outputDevices: [Device]     // e.g. lights, fan, servo, etc.

    @State private var ruleName: String = ""

    // Use only the ID states for selection.
    @State private var selectedSensorID: String? = nil
    @State private var comparison: String = "Greater Than"
    @State private var thresholdValue: Double = 70

    @State private var selectedOutputID: String? = nil
    @State private var outputAction: String = "On"  // "On" or "Off"

    @State private var useTriggerTime: Bool = true
    @State private var triggerTime: Date = Date()
    @State private var activeDays: [Bool] = Array(repeating: false, count: 7)

    let dayAbbreviations = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    let comparisonOptions = ["Greater Than", "Less Than"]
    let onOffOptions      = ["On", "Off"]

    var onSave: (AutomationRule) -> Void

    var body: some View {
        NavigationView {
            Form {
                // Rule name + input sensor
                automationDetailsSection
                // If sensor is temperature/humidity, show slider
                conditionSection
                // Output device + On/Off
                outputSection
                // Optional time scheduling
                triggerTimeSection
                activeDaysSection
            }
            .navigationTitle("Add Automation")
            .toolbar { addCancelToolbar }
        }
    }

    // MARK: - Subviews
    private var automationDetailsSection: some View {
        Section(header: Text("Automation Details")) {
            TextField("Rule Name", text: $ruleName)
            
            if !inputDevices.isEmpty {
                Picker("Input Sensor", selection: $selectedSensorID) {
                    Text("None").tag(String?.none)
                    ForEach(inputDevices) { device in
                        Text(device.name).tag(Optional(device.id.uuidString))
                    }
                }
            }
        }
    }
    
    private var conditionSection: some View {
        Group {
            if let sensor = inputDevices.first(where: { $0.id.uuidString == selectedSensorID }) {
                if sensor.deviceType == .temperature || sensor.deviceType == .humidity {
                    Section(header: Text("Condition")) {
                        Picker("Comparison", selection: $comparison) {
                            ForEach(comparisonOptions, id: \.self) { Text($0) }
                        }
                        Slider(value: $thresholdValue,
                               in: (sensor.deviceType == .temperature) ? 0...120 : 0...100,
                               step: 1)
                        Text("Threshold: \(Int(thresholdValue))\(sensor.deviceType == .temperature ? "°F" : "%")")
                    }
                } else if sensor.deviceType == .motion {
                    Section(header: Text("Condition")) {
                        Text("Motion Detected")
                    }
                }
            }
        }
    }
    
    private var outputSection: some View {
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
    }
    
    private var triggerTimeSection: some View {
        Section(header: Text("Trigger Time")) {
            Toggle("Enable Trigger Time", isOn: $useTriggerTime)
            if useTriggerTime {
                DatePicker("Time", selection: $triggerTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
            }
        }
    }
    
    private var activeDaysSection: some View {
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
    
    private var addCancelToolbar: some ToolbarContent {
        Group {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    saveAutomation()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
    
    // MARK: - Methods
    private func saveAutomation() {
        let activeDayString = dayAbbreviations.enumerated()
            .filter { activeDays[$0.offset] }
            .map { $0.element }
            .joined(separator: ",")
        
        // Look up the selected sensor and output devices using the IDs:
        let sensor = inputDevices.first(where: { $0.id.uuidString == selectedSensorID })
        let outDevice = outputDevices.first(where: { $0.id.uuidString == selectedOutputID })
        
        // Build condition string
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
        
        // Build output action string (e.g. "Kitchen Lights On", "Fan Off", etc.)
        var finalAction = "Execute"
        if let outDevice = outDevice {
            finalAction = "\(outDevice.name) \(outputAction)"
        }
        
        // Determine whether this is a condition-based rule
        let isConditionBased: Bool = {
            if let sensor = sensor {
                return sensor.deviceType == .temperature ||
                    sensor.deviceType == .humidity ||
                    sensor.deviceType == .motion
            }
            return false
        }()
        
        // For condition-based rules, force triggerTime to 0.
        let triggerTimeValue: TimeInterval = isConditionBased ? 0 : max(triggerTime.timeIntervalSinceNow * 1000, 0)
        let newTriggerEnabled: Bool = isConditionBased ? true : useTriggerTime
        
        let newRule = AutomationRule(
            id: UUID().uuidString,         // <--- generate a String
            name: ruleName,
            condition: condition,
            action: finalAction,
            activeDays: activeDayString,
            triggerEnabled: newTriggerEnabled,
            triggerTime: Date(timeIntervalSince1970: triggerTimeValue),
                    // Save them as strings:
            inputDeviceID: sensor?.id.uuidString,
            outputDeviceID: outDevice?.id.uuidString
        )
        
        // Debug: Log new rule creation before sending
        print("DEBUG: New rule created: \(newRule)")
        
        onSave(newRule)
        // Remove onSave(newRule) from here if you don't want duplicates.
        // Instead, use the network call as the single source of truth.
        NetworkManager.sendAutomationRule(rule: newRule, completion: { success in
            DispatchQueue.main.async {
                if success {
                    logManager.addLog("Added automation: \(newRule.name)")
                    // Delay fetch so firmware has time to update its list.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NetworkManager.fetchAutomationRules { fetchedRules in
                            if let fetched = fetchedRules {
                                DispatchQueue.main.async {
                                    self.automationRules = mergeAutomationRules(local: self.automationRules, fetched: fetched)
                                    print("DEBUG: After merge, automation rules: \(self.automationRules)")
                                }
                            } else {
                                print("DEBUG: Failed to fetch updated rules")
                            }
                        }
                    }
                } else {
                    logManager.addLog("Failed to add automation: \(newRule.name)")
                }
                dismiss()
            }
        })
    }
}

struct AddAutomationView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSensor = Device.create(name: "Temperature Sensor", status: "Off", deviceType: .temperature, port: "GPIO4")
        let sampleOutput = Device.create(name: "Kitchen Lights", status: "Off", deviceType: .light, port: "GPIO32")
        
        return AddAutomationView(
            automationRules: .constant([]),  // New binding parameter
            inputDevices: [sampleSensor],
            outputDevices: [sampleOutput],
            onSave: { rule in
                print("New rule: \(rule)")
            }
        )
    }
}
