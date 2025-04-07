import SwiftUI

struct EditAutomationView: View {
    @Environment(\.dismiss) var dismiss
    @State var rule: AutomationRule
    var inputDevices: [Device]  // Sensors
    var outputDevices: [Device] // Outputs (can be different from inputDevices)
    
    // Input states – initialize from the rule using the new IDs:
    @State private var selectedSensor: Device? = nil
    @State private var comparison: String = "Greater Than"
    @State private var thresholdValue: Double = 70
    
    // Output states
    @State private var selectedOutput: Device? = nil
    @State private var outputAction: String = "On"  // "On" or "Off"
    
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
             onSave: @escaping (AutomationRule) -> Void) {
            self._rule = State(initialValue: rule)
            self.inputDevices = inputDevices
            self.outputDevices = outputDevices
            self.onSave = onSave

            // Set selectedSensor based on rule.inputDeviceID (if available)
            if let sensorID = rule.inputDeviceID,
               let sensor = inputDevices.first(where: { $0.id == sensorID }) {
                self._selectedSensor = State(initialValue: sensor)
            } else {
                self._selectedSensor = State(initialValue: nil)
            }

            // If the condition string contains a comparison, try to parse it.
            if let sensor = self._selectedSensor.wrappedValue,
               sensor.deviceType == .temperature || sensor.deviceType == .humidity {
                let comps = rule.condition.split(separator: " ")
                if comps.count >= 3 {
                    self._comparison = State(initialValue: "\(comps[0]) \(comps[1])")
                    if let value = Double(comps[2]) {
                        self._thresholdValue = State(initialValue: value)
                    }
                }
            }

            // Set selectedOutput based on rule.outputDeviceID (if available)
            if let outputID = rule.outputDeviceID,
               let output = outputDevices.first(where: { $0.id == outputID }) {
                self._selectedOutput = State(initialValue: output)
            } else {
                self._selectedOutput = State(initialValue: nil)
            }

            // Determine the output action by splitting rule.action (e.g., "Kitchen Lights On")
            let actionComponents = rule.action.split(separator: " ")
            if let last = actionComponents.last {
                self._outputAction = State(initialValue: String(last))
            }

            self._useTriggerTime = State(initialValue: rule.triggerEnabled)
            self._triggerTime = State(initialValue: rule.triggerTime)

            // Parse active days from the rule.activeDays string (e.g., "M,Tu,W,Th,F")
            let days = rule.activeDays.split(separator: ",").map { String($0) }
            var actives = [Bool](repeating: false, count: 7)
            for (index, day) in dayAbbreviations.enumerated() {
                if days.contains(day) {
                    actives[index] = true
                }
            }
            self._activeDays = State(initialValue: actives)
        }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Automation Details")) {
                    TextField("Rule Name", text: $rule.name)
                    
                    if !inputDevices.isEmpty {
                        Picker("Input Sensor", selection: $selectedSensor) {
                            Text("None").tag(Device?.none)
                            ForEach(inputDevices) { device in
                                Text(device.name).tag(Optional(device))
                            }
                        }
                    }
                }
                
                if let sensor = selectedSensor {
                    if sensor.deviceType == .temperature || sensor.deviceType == .humidity {
                        Section(header: Text("Condition")) {
                            Picker("Comparison", selection: $comparison) {
                                ForEach(comparisonOptions, id: \.self) { Text($0) }
                            }
                            Slider(value: $thresholdValue,
                                   in: (sensor.deviceType == .temperature ? 0...120 : 0...100),
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
                            Button(action: { activeDays[index].toggle() }) {
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
    
    private func saveAutomation() {
        let activeDayString = dayAbbreviations.enumerated()
            .filter { activeDays[$0.offset] }
            .map { $0.element }
            .joined(separator: ",")
        
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
        
        var finalAction = "Execute"
        if let outDev = selectedOutput {
            finalAction = "\(outDev.name) \(outputAction)"
        }
        
        // Update rule properties including the new device IDs
        rule.condition = condition
        rule.action = finalAction
        rule.activeDays = activeDayString
        rule.triggerEnabled = useTriggerTime
        rule.triggerTime = triggerTime
        rule.inputDeviceID = selectedSensor?.id
        rule.outputDeviceID = selectedOutput?.id
        
        onSave(rule)
        dismiss()
    }
}

struct EditAutomationView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSensor = Device.create(name: "Temperature Sensor", status: "Off", deviceType: .temperature, port: "GPIO4")
        let sampleOutput = Device.create(name: "Kitchen Lights", status: "Off", deviceType: .light, port: "GPIO32")
        let sampleRule = AutomationRule(
            id: UUID(),
            name: "Test Automation",
            condition: "Greater Than 75",
            action: "Kitchen Lights On",
            activeDays: "M,Tu,W,Th,F",
            triggerEnabled: true,
            triggerTime: Date(),
            inputDeviceID: sampleSensor.id,
            outputDeviceID: sampleOutput.id
        )
        
        return EditAutomationView(
            rule: sampleRule,
            inputDevices: [sampleSensor],
            outputDevices: [sampleOutput],
            onSave: { updatedRule in
                print("Updated rule: \(updatedRule)")
            }
        )
    }
}
