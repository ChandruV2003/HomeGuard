import SwiftUI

struct AddAutomationView: View {
    @Environment(\.dismiss) var dismiss
    
    var inputDevices: [Device]      // e.g. temperature, motion, humidity
    var outputDevices: [Device]     // e.g. lights, fan, servo, etc.
    
    @State private var ruleName: String = ""
    
    // INPUT states
    @State private var selectedSensor: Device?
    @State private var comparison: String = "Greater Than"
    @State private var thresholdValue: Double = 70
    
    // OUTPUT states
    @State private var selectedOutput: Device?
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
                // optional time scheduling
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
                Picker("Input Sensor", selection: $selectedSensor) {
                    Text("None").tag(Device?.none)
                    ForEach(inputDevices) { device in
                        Text(device.name).tag(Optional(device))
                    }
                }
            }
        }
    }
    
    private var conditionSection: some View {
        Group {
            if let sensor = selectedSensor {
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
                }
                else if sensor.deviceType == .motion {
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
                Picker("Output Device", selection: $selectedOutput) {
                    Text("None").tag(Device?.none)
                    ForEach(outputDevices) { device in
                        Text(device.name).tag(Optional(device))
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
        
        // Build condition string
        var condition = ""
        if let sensor = selectedSensor {
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
        if let outDev = selectedOutput {
            finalAction = "\(outDev.name) \(outputAction)"
        }
        
        // Determine whether this is a condition‐only rule
        let isConditionBased: Bool = {
            if let sensor = selectedSensor {
                // For our purposes, temperature, humidity and motion rules are condition-based
                return sensor.deviceType == .temperature ||
                sensor.deviceType == .humidity ||
                sensor.deviceType == .motion
            }
            return false
        }()
        
        // For condition-based rules, we force triggerTime to 0.
        // For time-based rules, we calculate the delay (in milliseconds) from now.
        let triggerTimeValue: TimeInterval = isConditionBased ? 0 : max(triggerTime.timeIntervalSinceNow * 1000, 0)
        
        // For condition-based rules, we always want them active.
        let newTriggerEnabled: Bool = isConditionBased ? true : useTriggerTime
        
        let newRule = AutomationRule(
            id: UUID(),
            name: ruleName,
            condition: condition,
            action: finalAction,
            activeDays: activeDayString,
            triggerEnabled: newTriggerEnabled,
            triggerTime: Date(timeIntervalSince1970: triggerTimeValue),
            inputDeviceID: selectedSensor?.id,
            outputDeviceID: selectedOutput?.id
        )
        
        // Call your onSave closure to update local state
        onSave(newRule)
        
        // Send it to the firmware
        NetworkManager.sendAutomationRule(rule: newRule) { success in
            if success {
                // Optionally fetch updated rules from the ESP32
                NetworkManager.fetchAutomationRules { fetchedRules in
                    DispatchQueue.main.async {
                        // Update your local state if needed.
                    }
                }
            }
            dismiss()
        }
    }
}
    
struct AddAutomationView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSensor = Device.create(name: "Temperature Sensor", status: "Off", deviceType: .temperature, port: "GPIO4")
        let sampleOutput = Device.create(name: "Kitchen Lights", status: "Off", deviceType: .light, port: "GPIO32")
        
        return AddAutomationView(
            inputDevices: [sampleSensor],
            outputDevices: [sampleOutput]
        ) { rule in
            print("New rule: \(rule)")
        }
    }
}
