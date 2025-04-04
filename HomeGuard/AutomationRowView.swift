import SwiftUI

struct AutomationRowView: View {
    var rule: AutomationRule
    var onToggle: (Bool) -> Void  // Callback when power button is toggled
    var onEdit: () -> Void          // Callback for edit action
    var onDelete: () -> Void        // Callback for delete action
    @State private var isActive: Bool = true

    // Use abbreviated day labels.
    private let dayLabels: [String] = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]

    // Parse activeDays from rule.activeDays (e.g., "M,Tu,W,Th,F")
    private var activeDays: [String] {
        rule.activeDays.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    var body: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundColor(.blue)
                .padding(.trailing, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.subheadline)
                Text(rule.condition)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            // Day indicators (read-only)
            HStack(spacing: 8) {
                ForEach(dayLabels, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(activeDays.contains(day) ? Color.blue : Color.gray.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(activeDays.contains(day) ? .white : .black)
                }
            }
            Spacer()
            // Use the updated automation power button (minimal style)
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

struct AutomationPowerButton: View {
    @Binding var isActive: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: {
            onToggle()
        }) {
            Image(systemName: "power")
                .font(.title2)
                .foregroundColor(isActive ? .green : .gray)
        }
        .buttonStyle(PlainButtonStyle())
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
