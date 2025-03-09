import SwiftUI

struct AutomationsAreaView: View {
    var automationRules: [AutomationRule]
    var onAdd: () -> Void
    var onContextAction: (AutomationRule, AutomationContextAction) -> Void
    var addEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header banner for Automations (blue outline)
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.blue)
                    .padding(.trailing, 4)
                Text("Automations")
                    .font(.headline)
                Spacer()
                if automationRules.isEmpty {
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                    }
                    .foregroundColor(addEnabled ? .blue : .gray)
                    .disabled(!addEnabled)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .padding(.horizontal)
            
            if automationRules.isEmpty {
                Text("No automation rules. Tap '+' to add one.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ForEach(automationRules) { rule in
                    AutomationRowView(
                        rule: rule,
                        onToggle: { newState in
                            onContextAction(rule, newState ? .toggleOn : .toggleOff)
                        },
                        onEdit: { onContextAction(rule, .edit) },
                        onDelete: { onContextAction(rule, .delete) }
                    )
                    Divider()
                        .background(Color.blue)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct AutomationsAreaView_Previews: PreviewProvider {
    static var previews: some View {
        AutomationsAreaView(
            automationRules: [
                AutomationRule(
                    id: UUID(),
                    name: "Turn on Fan",
                    condition: "Temp > 80°F",
                    action: "Fan On",
                    activeDays: "M,Tu,W,Th,F",
                    triggerEnabled: true,
                    triggerTime: Date()
                )
            ],
            onAdd: { print("Add tapped") },
            onContextAction: { rule, action in
                print("\(rule.name) context action: \(action)")
            },
            addEnabled: true
        )
    }
}
