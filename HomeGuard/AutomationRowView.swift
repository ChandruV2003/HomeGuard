import SwiftUI

struct AutomationRowView: View {
    var rule: AutomationRule
    var onToggle: (Bool) -> Void  // Callback for enabling/disabling the rule
    var onEdit: () -> Void        // Callback for editing
    var onDelete: () -> Void      // Callback for deleting
    @State private var isActive: Bool = true
    
    // Abbreviated day labels
    private let dayLabels: [String] = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    
    // Parse activeDays (e.g., "M,Tu,W,Th,F")
    private var activeDays: [String] {
        rule.activeDays.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    var body: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundColor(.blue)
                .padding(.trailing, 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name)
                    .font(.headline)
                Text(rule.condition)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(rule.action)
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            Spacer()
            // Day indicators
            HStack(spacing: 8) {
                ForEach(dayLabels, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(activeDays.contains(day) ? Color.blue : Color.gray.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(activeDays.contains(day) ? .white : .black)
                }
            }
            Spacer()
            // Use the unified power button style for automation rule toggle
            AutomationPowerButton(isActive: $isActive) {
                isActive.toggle()
                onToggle(isActive)
            }
        }
        .padding(.horizontal)
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
}

struct AutomationRowView_Previews: PreviewProvider {
    static var previews: some View {
        AutomationRowView(
            rule: AutomationRule(
                id: UUID(),
                name: "Turn on Fan",
                condition: "Temp > 80°F",
                action: "Fan On",
                activeDays: "M,Tu,W,Th,F",
                triggerEnabled: true,
                triggerTime: Date()
            ),
            onToggle: { state in print("Toggled to \(state ? "On" : "Off")") },
            onEdit: { print("Edit tapped") },
            onDelete: { print("Delete tapped") }
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
