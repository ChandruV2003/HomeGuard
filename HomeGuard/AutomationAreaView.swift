import SwiftUI

struct AutomationAreaView: View {
    var automationRules: [AutomationRule]
    var onAdd: () -> Void
    var onSelect: (AutomationRule) -> Void
    var addEnabled: Bool  // True only if there is at least one device

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
            
            if automationRules.isEmpty {
                Text("No automation rules. Tap '+' to add one.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ForEach(automationRules.indices, id: \.self) { i in
                    let rule = automationRules[i]
                    Button(action: { onSelect(rule) }) {
                        HStack {
                            Text(rule.name)
                                .font(.subheadline)
                            Spacer()
                            Text(rule.condition)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                    }
                    if i < automationRules.count - 1 {
                        Divider()
                            .background(Color.blue)
                    }
                }
            }
        }
    }
}

struct AutomationAreaView_Previews: PreviewProvider {
    static var previews: some View {
        AutomationAreaView(automationRules: [], onAdd: {}, onSelect: { _ in }, addEnabled: true)
    }
}
