import SwiftUI

struct AutomationPowerButton: View {
    @Binding var isActive: Bool
    var onToggle: () -> Void
    @Environment(\.colorScheme) var colorScheme
    private let circleSize: CGFloat = 44

    var body: some View {
        Button(action: onToggle) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.green : Color.gray)
                    .frame(width: circleSize, height: circleSize)
                Image(systemName: "power")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .contentShape(Circle())                           // ← treat the full circle as tappable
        .frame(width: circleSize, height: circleSize)     // ← reinforce the tappable area
        .buttonStyle(PlainButtonStyle())                  // no cosmetic change
    }
}


struct AutomationPowerButton_Previews: PreviewProvider {
    @State static var state = true
    static var previews: some View {
        AutomationPowerButton(isActive: $state, onToggle: { state.toggle() })
    }
}
