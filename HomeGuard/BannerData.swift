import SwiftUI

struct BannerData: Identifiable {
    let id = UUID()
    let title:  String
    let style:  BannerStyle
    enum BannerStyle { case error, success }
}

struct BannerView: View {
    let data: BannerData
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: data.style == .error ? "exclamationmark.triangle" : "checkmark.circle")
            Text(data.title)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(data.style == .error ? Color.red : Color.green)
        .foregroundColor(.white)
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.top, 8)          // keep away from status bar
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    BannerView(data: .init(title: "Hello World!", style: .success))
}