import SwiftUI

struct EditAutomationView: View {
    @Environment(\.dismiss) var dismiss
    @State var rule: AutomationRule
    var inputDevices: [Device]
    
    @State private var selectedSensor: Device? = nil
    @State private var comparison: String = "Greater Than"
    @State private var thresholdValue: Double = 70
    
    @State private var useTriggerTime: Bool = false
    @State private var triggerTime: Date = Date()
    
    // Active days toggles.
    @State private var activeDays: [Bool] = Array(repeating: false, count: 7)
    let dayAbbreviations: [String] = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    let comparisonOptions = ["Greater Than", "Less Than"]
    
    var onSave: (AutomationRule) -> Void
    
    init(rule: AutomationRule, inputDevices: [Device], onSave: @escaping (AutomationRule) -> Void) {
        _rule = State(initialValue: rule)
        self.inputDevices = inputDevices
        self.onSave = onSave
        // Parse the activeDays string to initialize the toggles.
        let activeDaysFromRule = rule.activeDays.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        _activeDays = State(initialValue: dayAbbreviations.map { activeDaysFromRule.contains($0) })
        _useTriggerTime = State(initialValue: rule.triggerEnabled)
        _triggerTime = State(initialValue: rule.triggerTime)
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
                Section(header: Text("Condition")) {
                    if let sensor = selectedSensor {
                        if sensor.deviceType == .temperature || sensor.deviceType == .humidity {
                            Picker("Comparison", selection: $comparison) {
                                ForEach(comparisonOptions, id: \.self) { option in
                                    Text(option)
                                }
                            }
                            Slider(value: $thresholdValue, in: sensor.deviceType == .temperature ? 0...120 : 0...100, step: 1)
                            Text("Threshold: \(Int(thresholdValue))\(sensor.deviceType == .temperature ? "°F" : "%")")
                        } else if sensor.deviceType == .motion {
                            Text("Trigger on Motion Detected")
                        }
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
                                print("Day \(dayAbbreviations[index]) toggled to \(activeDays[index])")
                            }) {
                                Text(dayAbbreviations[index])
                                    .font(.caption)
                                    .frame(width: 30, height: 30)
                                    .background(activeDays[index] ? Color.blue : Color.gray.opacity(0.3))
                                    .clipShape(Circle())
                                    .foregroundColor(activeDays[index] ? .white : .black)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Automation")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let activeDayString = dayAbbreviations.enumerated()
                            .filter { activeDays[$0.offset] }
                            .map { $0.element }
                            .joined(separator: ",")
                        var conditionString = ""
                        if let sensor = selectedSensor {
                            if sensor.deviceType == .temperature || sensor.deviceType == .humidity {
                                conditionString = "\(comparison) \(Int(thresholdValue))"
                            } else if sensor.deviceType == .motion {
                                conditionString = "Motion Detected"
                            }
                        }
                        rule.condition = conditionString
                        rule.activeDays = activeDayString
                        rule.triggerEnabled = useTriggerTime
                        rule.triggerTime = triggerTime
                        onSave(rule)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct EditAutomationView_Previews: PreviewProvider {
    static var previews: some View {
        EditAutomationView(
            rule: AutomationRule(
                id: UUID(),
                name: "Test Automation",
                condition: "Greater Than 75",
                action: "Light On",
                activeDays: "M,Tu,W",
                triggerEnabled: true,
                triggerTime: Date()
            ),
            inputDevices: []
        ) { rule in
            print(rule)
        }
    }
}
