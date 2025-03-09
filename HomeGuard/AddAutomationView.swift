import SwiftUI

struct AddAutomationView: View {
    @Environment(\.dismiss) var dismiss
    // List of available input sensors (only inputs: sensor, temperature, humidity, motion)
    var inputDevices: [Device]
    
    @State private var ruleName: String = ""
    @State private var selectedSensor: Device? = nil
    
    // For temperature/humidity sensors:
    @State private var comparison: String = "Greater Than"
    @State private var thresholdValue: Double = 70
    
    // Always show trigger time; user can enable/disable it.
    @State private var useTriggerTime: Bool = true
    @State private var triggerTime: Date = Date()
    
    // Active days toggles for each day.
    @State private var activeDays: [Bool] = Array(repeating: false, count: 7)
    let dayAbbreviations: [String] = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    
    let comparisonOptions = ["Greater Than", "Less Than"]
    
    var onSave: (AutomationRule) -> Void
    
    var body: some View {
        NavigationView {
            Form {
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
                    DatePicker("Time", selection: $triggerTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                }
                
                Section(header: Text("Active Days")) {
                    HStack {
                        ForEach(0..<dayAbbreviations.count, id: \.self) { index in
                            DayToggleView(isActive: $activeDays[index], day: dayAbbreviations[index])
                        }
                    }
                }
            }
            .navigationTitle("Add Automation")
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
                        
                        let newRule = AutomationRule(
                            id: UUID(),
                            name: ruleName,
                            condition: conditionString,
                            action: "Execute",
                            activeDays: activeDayString,
                            triggerEnabled: useTriggerTime,
                            triggerTime: triggerTime
                        )
                        onSave(newRule)
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

struct DayToggleView: View {
    @Binding var isActive: Bool
    var day: String
    
    var body: some View {
        Button(action: {
            isActive.toggle()
            print("Day \(day) toggled to \(isActive)")
        }) {
            Text(day)
                .font(.caption)
                .frame(width: 30, height: 30)
                .background(isActive ? Color.blue : Color.gray.opacity(0.3))
                .clipShape(Circle())
                .foregroundColor(isActive ? .white : .black)
        }
    }
}

struct AddAutomationView_Previews: PreviewProvider {
    static var previews: some View {
        AddAutomationView(inputDevices: []) { rule in
            print(rule)
        }
    }
}
