// AutomationsAreaView.swift
import SwiftUI

struct AutomationsAreaView: View {
    var automationRules: [AutomationRule]
    var aiGeneratedAutomation: AutomationRule?
    var onAdd: () -> Void
    var onAcceptAISuggestion: () -> Void
    var onDismissAISuggestion: () -> Void
    var onContextAction: (AutomationRule, AutomationContextAction) -> Void
    var addEnabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            
            if let aiAutomation = aiGeneratedAutomation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Suggested Automation")
                        .font(.headline)
                        .foregroundColor(.blue)
                    AutomationRowView(
                        rule: aiAutomation,
                        onToggle: { _ in },
                        onEdit: {},
                        onDelete: {}
                    )
                    HStack {
                        Button(action: onAcceptAISuggestion) {
                            Text("Accept")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                        Button(action: onDismissAISuggestion) {
                            Text("Dismiss")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.1)))
                .padding(.horizontal)
            }
            
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
            aiGeneratedAutomation: AutomationRule(
                id: UUID(),
                name: "Turn off Lights",
                condition: "No motion detected",
                action: "Lights Off",
                activeDays: "M,Tu,W,Th,F,Sa,Su",
                triggerEnabled: true,
                triggerTime: Date()
            ),
            onAdd: { print("Add tapped") },
            onAcceptAISuggestion: { print("AI automation accepted") },
            onDismissAISuggestion: { print("AI automation dismissed") },
            onContextAction: { rule, action in
                print("\(rule.name) context action: \(action)")
            },
            addEnabled: true
        )
    }
}
