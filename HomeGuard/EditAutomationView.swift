import SwiftUI

struct EditAutomationView: View {
    // External props
    @Environment(\.dismiss) private var dismiss
    @State var rule: AutomationRule
    var inputDevices: [Device]
    var outputDevices: [Device]
    var onSave: (AutomationRule) -> Void

    // Form state
    @State private var selectedSensorID: String? = nil
    @State private var comparison       = "Greater Than"
    @State private var thresholdValue   = 70.0
    @State private var selectedOutputID: String? = nil
    @State private var outputAction     = "On"
    @State private var useTriggerTime   = false
    @State private var triggerTime      = Date()
    @State private var activeDays       = Array(repeating: false, count: 7)

    // Constants
    private let dayAbbreviations = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    private let comparisonOptions = ["Greater Than", "Less Than"]
    private let onOffOptions      = ["On", "Off"]

    // MARK: – Initialiser ----------------------------------------------------
    init(rule: AutomationRule,
         inputDevices: [Device],
         outputDevices: [Device],
         onSave: @escaping (AutomationRule) -> Void)
    {
        self._rule          = State(initialValue: rule)
        self.inputDevices   = inputDevices
        self.outputDevices  = outputDevices
        self.onSave         = onSave

        // Pre‑populate form‐specific state
        _selectedSensorID = State(initialValue: rule.inputDeviceID)
        _selectedOutputID = State(initialValue: rule.outputDeviceID)
        if let lastWord = rule.action.split(separator: " ").last {
            _outputAction = State(initialValue: String(lastWord))
        }
        if let s = inputDevices.first(where: { $0.id.uuidString == rule.inputDeviceID }),
           (s.deviceType == .temperature || s.deviceType == .humidity),
           rule.condition.split(separator: " ").count >= 3
        {
            let comps = rule.condition.split(separator: " ")
            _comparison     = State(initialValue: comps[0] + " " + comps[1])
            _thresholdValue = State(initialValue: Double(comps[2]) ?? 70)
        }
        _useTriggerTime = State(initialValue: rule.triggerEnabled && rule.triggerTime != Date(timeIntervalSince1970: 0))
        _triggerTime    = State(initialValue: rule.triggerTime)
        // Active days
        var actives = [Bool](repeating: false, count: 7)
        let current = rule.activeDays.split(separator: ",").map(String.init)
        for (idx, abbrev) in dayAbbreviations.enumerated() { actives[idx] = current.contains(abbrev) }
        _activeDays = State(initialValue: actives)
    }

    // MARK: – View body ------------------------------------------------------
    var body: some View {
        NavigationView {
            Form {
                // ––– same UI sections as Add view –––
                detailsSection
                conditionSection
                outputSection
                triggerSection
                daysSection
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

    // MARK: – Sections -------------------------------------------------------
    private var detailsSection: some View {
        Section(header: Text("Automation Details")) {
            TextField("Rule Name", text: $rule.name)
            if !inputDevices.isEmpty {
                Picker("Input Sensor", selection: $selectedSensorID) {
                    Text("None").tag(String?.none)
                    ForEach(inputDevices) { dev in
                        Text(dev.name).tag(Optional(dev.id.uuidString))
                    }
                }
            }
        }
    }

    private var conditionSection: some View {
        Group {
            if let sensor = inputDevices.first(where: { $0.id.uuidString == selectedSensorID }) {
                switch sensor.deviceType {
                case .temperature, .humidity:
                    Section(header: Text("Condition")) {
                        Picker("Comparison", selection: $comparison) {
                            ForEach(comparisonOptions, id: \.self) { Text($0) }
                        }
                        Slider(value: $thresholdValue,
                               in: sensor.deviceType == .temperature ? 0...120 : 0...100,
                               step: 1)
                        Text("Threshold: \(Int(thresholdValue))\(sensor.deviceType == .temperature ? "°F" : "%")")
                    }
                case .motion:
                    Section(header: Text("Condition")) { Text("Motion Detected") }
                default: EmptyView()
                }
            }
        }
    }

    private var outputSection: some View {
        Section(header: Text("Output Device & Action")) {
            if !outputDevices.isEmpty {
                Picker("Output Device", selection: $selectedOutputID) {
                    Text("None").tag(String?.none)
                    ForEach(outputDevices) { dev in
                        Text(dev.name).tag(Optional(dev.id.uuidString))
                    }
                }
            }
            Picker("Action", selection: $outputAction) {
                ForEach(onOffOptions, id: \.self) { Text($0) }
            }
        }
    }

    private var triggerSection: some View {
        Section(header: Text("Trigger Time")) {
            Toggle("Enable Trigger Time", isOn: $useTriggerTime)
            if useTriggerTime {
                DatePicker("Time", selection: $triggerTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
            }
        }
    }

    private var daysSection: some View {
        Section(header: Text("Active Days")) {
            HStack {
                ForEach(dayAbbreviations.indices, id: \.self) { idx in
                    Button {
                        activeDays[idx].toggle()
                    } label: {
                        Text(dayAbbreviations[idx])
                            .font(.caption)
                            .frame(width: 30, height: 30)
                            .background(activeDays[idx] ? Color.blue : Color.gray.opacity(0.3))
                            .clipShape(Circle())
                            .foregroundColor(activeDays[idx] ? .white : .black)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                }
            }
        }
    }

    // MARK: – Save logic -----------------------------------------------------
    private func saveAutomation() {
        // 1) Update rule fields
        let activeDayString = dayAbbreviations.enumerated()
            .filter { activeDays[$0.offset] }
            .map(\.element)
            .joined(separator: ",")

        let sensor    = inputDevices.first { $0.id.uuidString == selectedSensorID }
        let outputDev = outputDevices.first { $0.id.uuidString == selectedOutputID }

        var cond = ""
        if let s = sensor {
            switch s.deviceType {
            case .temperature, .humidity: cond = "\(comparison) \(Int(thresholdValue))"
            case .motion:                 cond = "Motion Detected"
            default: break
            }
        }
        var actText = "Execute"
        if let o = outputDev { actText = "\(o.name) \(outputAction)" }

        let isConditionBased: Bool = {
            guard let s = sensor else { return false }
            return [.temperature, .humidity, .motion].contains(s.deviceType)
        }()

        rule.condition      = cond
        rule.action         = actText
        rule.activeDays     = activeDayString
        rule.triggerEnabled = (isConditionBased || useTriggerTime)
        rule.inputDeviceID  = selectedSensorID
        rule.outputDeviceID = selectedOutputID
        rule.triggerTime    = Date(timeIntervalSince1970: 0)

        // 2) Fix triggerTime against firmware clock
        NetworkManager.fetchSensorData { dict in
            guard
                let dict = dict,
                let boardNow = dict["simTime"] as? Double
            else { send(rule); return }

            if !isConditionBased && useTriggerTime {
                let msPerDay  = 86_400_000.0
                let boardDay  = boardNow.truncatingRemainder(dividingBy: msPerDay)
                let pickerDay = (triggerTime.timeIntervalSince1970 * 1000.0)
                                .truncatingRemainder(dividingBy: msPerDay)
                var delta = pickerDay - boardDay
                if delta < 0 { delta += msPerDay }
                rule.triggerTime = Date(timeIntervalSince1970: boardNow + delta)
            }

            send(rule)
        }
    }

    private func send(_ updatedRule: AutomationRule) {
        NetworkManager.sendAutomationRule(rule: updatedRule) { ok in
            DispatchQueue.main.async {
                onSave(updatedRule)        // optimistic UI
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
