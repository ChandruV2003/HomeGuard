import SwiftUI

struct ErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .cornerRadius(8)
            .padding([.horizontal, .top])
    }
}
