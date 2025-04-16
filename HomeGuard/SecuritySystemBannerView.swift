import SwiftUI

struct SecuritySystemBannerView: View {
    var rule: AutomationRule
    var onSelect: () -> Void
    
    var body: some View {
        // REMOVED the Button(...) wrapper so that tapping the banner does nothing
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
                    .foregroundColor(.green)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red, lineWidth: 2)
        )
        .padding(.vertical, 4)
        // The context menu is still available, but the banner itself is not tappable
        .contextMenu {
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
                id: UUID().uuidString,
                name: "Security System",
                condition: "RFID Allowed",
                action: "Active",
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
