import SwiftUI

struct AddAutomationView: View {
    @Environment(\.dismiss) var dismiss
    var inputDevices: [Device]
    
    @State private var ruleName: String = ""
    @State private var selectedSensor: Device?
    @State private var comparison: String = "Greater Than"
    @State private var thresholdValue: Double = 70
    @State private var useTriggerTime: Bool = true
    @State private var triggerTime: Date = Date()
    @State private var activeDays: [Bool] = Array(repeating: false, count: 7)
    
    let dayAbbreviations = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    let comparisonOptions = ["Greater Than", "Less Than"]
    
    var onSave: (AutomationRule) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                automationDetailsSection
                conditionSection
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
    
    // Inside AddAutomationView
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
        
        let newRule = AutomationRule(
            id: UUID(),
            name: ruleName,
            condition: condition,
            action: "Execute", // if needed, or adjust accordingly
            activeDays: activeDayString,
            triggerEnabled: useTriggerTime,
            triggerTime: triggerTime
        )
        
        NetworkManager.sendAutomationRule(rule: newRule) { success in
            if success {
                // Optionally update your local automationRules array by fetching from the ESP32
                NetworkManager.fetchAutomationRules { fetchedRules in
                    DispatchQueue.main.async {
                        // Update your local state (e.g., via a binding or state object)
                    }
                }
            }
            // Dismiss the view whether or not the update was successful (you can also add error handling)
            dismiss()
        }
    }
}

struct AddAutomationView_Previews: PreviewProvider {
    static var previews: some View {
        // For preview, we create a sample device to populate the picker.
        let sampleDevice = Device.create(name: "Temperature Sensor", status: "Off", deviceType: .temperature, port: availablePorts[.temperature]?.first ?? "")
        return AddAutomationView(inputDevices: [sampleDevice]) { rule in
            print("New rule added: \(rule)")
        }
    }
}

