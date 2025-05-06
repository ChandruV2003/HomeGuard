import SwiftUI

struct AddAutomationView: View {
    // External bindings
    @Binding var automationRules: [AutomationRule]
    var inputDevices: [Device]
    var outputDevices: [Device]
    var onSave: (AutomationRule) -> Void

    // Environment
    @EnvironmentObject var logManager: EventLogManager
    @Environment(\.dismiss)     private var dismiss

    // Form state
    @State private var ruleName         = ""
    @State private var selectedSensorID: String? = nil
    @State private var comparison       = "Greater Than"
    @State private var thresholdValue   = 70.0
    @State private var selectedOutputID: String? = nil
    @State private var outputAction     = "On"
    @State private var useTriggerTime   = true
    @State private var triggerTime      = Date()
    @State private var activeDays       = Array(repeating: false, count: 7)

    // Constants
    private let dayAbbreviations = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    private let comparisonOptions = ["Greater Than", "Less Than"]
    private let onOffOptions      = ["On", "Off"]

    // MARK: – Body -----------------------------------------------------------
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

    // MARK: – Sections -------------------------------------------------------
    private var automationDetailsSection: some View {
        Section(header: Text("Automation Details")) {
            TextField("Rule Name", text: $ruleName)

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

    private var triggerTimeSection: some View {
        Section(header: Text("Trigger Time")) {
            Toggle("Enable Trigger Time", isOn: $useTriggerTime)
            if useTriggerTime {
                DatePicker("Time", selection: $triggerTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
            }
        }
    }

    private var activeDaysSection: some View {
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

    private var addCancelToolbar: some ToolbarContent {
        Group {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { saveAutomation() }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    // MARK: – Save logic -----------------------------------------------------
    private func saveAutomation() {
        // 1) Compile day string
        let activeDayString = dayAbbreviations.enumerated()
            .filter { activeDays[$0.offset] }
            .map(\.element)
            .joined(separator: ",")

        // 2) Determine devices
        let sensor    = inputDevices.first { $0.id.uuidString == selectedSensorID }
        let outputDev = outputDevices.first { $0.id.uuidString == selectedOutputID }

        // 3) Condition + action text
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

        // 4) Which kind of rule?
        let isConditionBased: Bool = {
            guard let s = sensor else { return false }
            return [.temperature, .humidity, .motion].contains(s.deviceType)
        }()

        var newRule = AutomationRule(
            id: UUID().uuidString,
            name: ruleName,
            condition: cond,
            action: actText,
            activeDays: activeDayString,
            triggerEnabled: (isConditionBased || useTriggerTime),
            triggerTime: Date(timeIntervalSince1970: 0),
            inputDeviceID: sensor?.id.uuidString,
            outputDeviceID: outputDev?.id.uuidString
        )

        // 5) Fix triggerTime using firmware’s accelerated clock
        NetworkManager.fetchSensorData { dict in
            guard
                let dict = dict,
                let boardNow = dict["simTime"] as? Double
            else { sendRuleToBoard(newRule); return }

            if !isConditionBased && useTriggerTime {
                let msPerDay  = 86_400_000.0
                let boardDay  = boardNow.truncatingRemainder(dividingBy: msPerDay)
                let pickerDay = (triggerTime.timeIntervalSince1970 * 1000.0)
                                .truncatingRemainder(dividingBy: msPerDay)
                var delta = pickerDay - boardDay
                if delta < 0 { delta += msPerDay }     // schedule for tomorrow if already passed
                newRule.triggerTime = Date(timeIntervalSince1970: boardNow + delta)
            }

            sendRuleToBoard(newRule)
        }
    }

    private func sendRuleToBoard(_ rule: AutomationRule) {
        NetworkManager.sendAutomationRule(rule: rule) { ok in
            DispatchQueue.main.async {
                if ok {
                    NetworkManager.fetchAutomationRules { fetched in
                        if let fetched = fetched {
                            automationRules = mergeAutomationRules(local: automationRules,
                                                                   fetched: fetched)
                        }
                    }
                }
                onSave(rule)      // let caller refresh UI
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
