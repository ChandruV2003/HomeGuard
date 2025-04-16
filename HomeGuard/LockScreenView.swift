import SwiftUI

struct LockScreenView: View {
    @Binding var isLocked: Bool
    
    @State private var enteredPassword: String = ""
    
    @AppStorage("lockPassword") var savedPassword: String = "1234"
    
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Ensure you have this asset in Assets.xcassets
            Image("splash_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
            
            Text("HomeGuard")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Locked")
                .font(.title2)
                .foregroundColor(.gray)
            
            SecureField("Enter Password", text: $enteredPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 40)
            
            if showError {
                Text("Incorrect password. Try again.")
                    .foregroundColor(.red)
            }
            
            Button(action: unlock) {
                Text("Unlock")
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private func unlock() {
        if enteredPassword == savedPassword {
            isLocked = false
            showError = false
        } else {
            showError = true
        }
    }
}

struct LockScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LockScreenView(isLocked: .constant(true))
    }
}
