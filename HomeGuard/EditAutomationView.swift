import SwiftUI

struct EditAutomationView: View {
    @Environment(\.dismiss) var dismiss
    @State var rule: AutomationRule
    var inputDevices: [Device]
    
    @State private var selectedSensor: Device?
    @State private var comparison: String = "Greater Than"
    @State private var thresholdValue: Double = 70
    @State private var useTriggerTime: Bool = false
    @State private var triggerTime: Date = Date()
    @State private var activeDays: [Bool] = Array(repeating: false, count: 7)
    
    let dayAbbreviations = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    let comparisonOptions = ["Greater Than", "Less Than"]
    
    var onSave: (AutomationRule) -> Void
    
    init(rule: AutomationRule, inputDevices: [Device], onSave: @escaping (AutomationRule) -> Void) {
        self._rule = State(initialValue: rule)
        self.inputDevices = inputDevices
        self.onSave = onSave
        
        // Initialize activeDays
        let activeDaysFromRule = rule.activeDays.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        self._activeDays = State(initialValue: dayAbbreviations.map { activeDaysFromRule.contains($0) })
        
        // Initialize selectedSensor based on condition
        let conditionParts = rule.condition.components(separatedBy: " ")
        self._comparison = State(initialValue: conditionParts.first ?? "Greater Than")
        if conditionParts.count >= 3 { // e.g., "Greater Than 75"
            self._thresholdValue = State(initialValue: Double(conditionParts[2]) ?? 70)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                automationDetailsSection
                conditionSection
                triggerTimeSection
                activeDaysSection
            }
            .navigationTitle("Edit Automation")
            .toolbar { saveCancelToolbar }
        }
    }
    
    // MARK: - Subviews
    private var automationDetailsSection: some View {
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
    }
    
    private var conditionSection: some View {
        Group {
            if let sensor = selectedSensor, (sensor.deviceType == .temperature || sensor.deviceType == .humidity) {
                Section(header: Text("Condition")) {
                    Picker("Comparison", selection: $comparison) {
                        ForEach(comparisonOptions, id: \.self) { Text($0) }
                    }
                    Slider(value: $thresholdValue, in: sensor.deviceType == .temperature ? 0...120 : 0...100, step: 1)
                    Text("Threshold: \(Int(thresholdValue))\(sensor.deviceType == .temperature ? "°F" : "%")")
                }
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
    
    // Inside EditAutomationView
    private var activeDaysSection: some View {
        Section(header: Text("Active Days")) {
            HStack {
                ForEach(0..<dayAbbreviations.count, id: \.self) { index in
                    Button(action: {
                        activeDays[index].toggle() // Direct toggle (works with SwiftUI 5+)
                    }) {
                        Text(dayAbbreviations[index])
                            .font(.caption)
                            .frame(width: 30, height: 30)
                            .background(activeDays[index] ? Color.blue : Color.gray.opacity(0.3))
                            .clipShape(Circle())
                            .foregroundColor(activeDays[index] ? .white : .black)
                    }
                    .buttonStyle(PlainButtonStyle()) // Fix tap area
                    .contentShape(Circle()) // Ensure entire circle is tappable
                }
            }
        }
    }
    
    private var saveCancelToolbar: some ToolbarContent {
        Group {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
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
        
        var condition = ""
        if let sensor = selectedSensor {
            switch sensor.deviceType {
            case .temperature, .humidity:
                condition = "\(comparison) \(Int(thresholdValue))"
            case .motion:
                condition = "Motion Detected"
            default: break
            }
        }
        
        rule.condition = condition
        rule.activeDays = activeDayString
        rule.triggerEnabled = useTriggerTime
        rule.triggerTime = triggerTime
        onSave(rule)
        dismiss()
    }
}

struct EditAutomationView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample rule and a sample device.
        let sampleRule = AutomationRule(
            id: UUID(),
            name: "Test Automation",
            condition: "Greater Than 70",
            action: "Execute",
            activeDays: "M,Tu,W,Th,F",
            triggerEnabled: true,
            triggerTime: Date()
        )
        let sampleDevice = Device.create(name: "Temperature Sensor", status: "Off", deviceType: .temperature, port: availablePorts[.temperature]?.first ?? "")
        return EditAutomationView(rule: sampleRule, inputDevices: [sampleDevice]) { updatedRule in
            print("Updated rule: \(updatedRule)")
        }
    }
}
