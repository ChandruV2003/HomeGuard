import SwiftUI

struct WiFiStatusView: View {
    var isConnected: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi")
                .foregroundColor(isConnected ? .green : .red)
            Text(isConnected ? "Online" : "Offline")
                .foregroundColor(isConnected ? .green : .red)
                .font(.footnote)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

struct WiFiStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            WiFiStatusView(isConnected: true)
            WiFiStatusView(isConnected: false)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
