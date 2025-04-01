import SwiftUI

struct SecuritySystemBannerView: View {
    var rule: AutomationRule
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "lock.shield")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.red)
                VStack(alignment: .leading) {
                    Text(rule.name)
                        .font(.headline)
                    Text(rule.action)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(
                // Use systemBackground to match other banners/cards.
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
            )
            .overlay(
                // Red border to emphasize the security system.
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red, lineWidth: 2)
            )
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            // If you want to allow editing from a context menu, keep this.
            // Otherwise, remove it if you prefer no context menu.
            Button(action: onSelect) {
                Label("Edit Security Settings", systemImage: "pencil")
            }
        }
    }
}

struct SecuritySystemBannerView_Previews: PreviewProvider {
    static var previews: some View {
        SecuritySystemBannerView(
            rule: AutomationRule(
                id: UUID(),
                name: "Security System",
                condition: "RFID Allowed",
                action: "Display: Welcome; Buzzer: Off",
                activeDays: "M,Tu,W,Th,F,Sa,Su",
                triggerEnabled: true,
                triggerTime: Date()
            )
        ) {
            print("Edit tapped")
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
