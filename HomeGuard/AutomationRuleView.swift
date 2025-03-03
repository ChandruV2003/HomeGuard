import SwiftUI

struct AutomationRuleView: View {
    @Environment(\.dismiss) var dismiss
    @State private var ruleName: String = ""
    @State private var condition: String = ""
    @State private var action: String = ""
    
    var onSave: (AutomationRule) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Rule Details")) {
                    TextField("Rule Name", text: $ruleName)
                    TextField("Condition", text: $condition)
                    TextField("Action", text: $action)
                }
            }
            .navigationTitle("Add Automation Rule")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let rule = AutomationRule(id: UUID(), name: ruleName, condition: condition, action: action)
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

struct AutomationRuleView_Previews: PreviewProvider {
    static var previews: some View {
        AutomationRuleView { rule in
            print(rule)
        }
    }
}
