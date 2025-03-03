import SwiftUI

struct SplashScreenView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            VStack {
                Spacer()
                Image("splash_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                Text("HomeGuard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(.top, 20)
                Spacer()
            }
        }
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SplashScreenView().preferredColorScheme(.light)
            SplashScreenView().preferredColorScheme(.dark)
        }
    }
}
