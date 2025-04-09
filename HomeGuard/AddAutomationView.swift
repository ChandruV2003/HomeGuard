import SwiftUI

struct AddAutomationView: View {
    @Binding var automationRules: [AutomationRule]
    @EnvironmentObject var logManager: EventLogManager

    @Environment(\.dismiss) var dismiss

    var inputDevices: [Device]
    var outputDevices: [Device]

    @State private var ruleName: String = ""

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
                automationDetailsSection
                conditionSection
                outputSection
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
        // The first half just builds up the new AutomationRule object
        // with placeholders for triggerTime = 0.  Then, asynchronously,
        // we fetch the board's current simTime and adjust it.

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

        // We do want to treat time-based vs condition-based differently:
        let isConditionBased: Bool = {
            if let s = sensor {
                return s.deviceType == .temperature
                    || s.deviceType == .humidity
                    || s.deviceType == .motion
            }
            return false
        }()
        
        // Build the skeleton rule
        var newRule = AutomationRule(
            id: UUID().uuidString,
            name: ruleName,
            condition: condition,
            action: finalAction,
            activeDays: activeDayString,
            triggerEnabled: !isConditionBased && useTriggerTime,
            triggerTime: Date(timeIntervalSince1970: 0),
            inputDeviceID: sensor?.id.uuidString,
            outputDeviceID: outDevice?.id.uuidString
        )

        // If condition-based, the firmware will ignore the time factor; set 0
        if isConditionBased {
            newRule.triggerTime = Date(timeIntervalSince1970: 0)
        }
        
        // Next: asynchronously fetch /sensor to get the board's simTime
        NetworkManager.fetchSensorData { dict in
            guard let dict = dict, let boardNow = dict["simTime"] as? Double else {
                // Could not fetch, fallback => do normal call with triggerTime = 0
                sendRuleToBoard(rule: newRule)
                return
            }
            // If it IS time-based, we want to convert from real seconds to scaled
            if !isConditionBased && useTriggerTime {
                let realDiffSeconds = triggerTime.timeIntervalSinceNow // can be negative if time is in the past
                // Each real second => 1000 ms => multiplied by TIME_ACCEL_FACTOR
                let scaledDiff: Double = realDiffSeconds * 1000.0 * Config.timeAcceleration
                let finalScaled = max(boardNow + scaledDiff, 0)
                
                newRule.triggerTime = Date(timeIntervalSince1970: finalScaled)
            } else {
                // For condition-based or disabled time
                newRule.triggerTime = Date(timeIntervalSince1970: 0)
            }
            sendRuleToBoard(rule: newRule)
        }
    }

    private func sendRuleToBoard(rule: AutomationRule) {
        NetworkManager.sendAutomationRule(rule: rule) { success in
            DispatchQueue.main.async {
                if success {
                    // Now fetch updated rules to refresh the local array
                    NetworkManager.fetchAutomationRules { fetchedRules in
                        if let fetched = fetchedRules {
                            DispatchQueue.main.async {
                                self.automationRules = mergeAutomationRules(local: self.automationRules, fetched: fetched)
                            }
                        }
                    }
                }
                dismiss()
            }
        }
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
