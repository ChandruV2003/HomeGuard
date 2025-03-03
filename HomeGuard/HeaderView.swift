import SwiftUI

struct HeaderView: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.system(size: 28, weight: .bold))
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                               startPoint: .leading,
                               endPoint: .trailing)
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderView(title: "HomeGuard Dashboard")
    }
}
