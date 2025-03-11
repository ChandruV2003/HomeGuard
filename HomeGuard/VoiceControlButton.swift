import SwiftUI

struct VoiceControlButton: View {
    @ObservedObject var speechManager: SpeechManager
    @State private var isPressed: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // Recognized text box appears only while pressed.
            if isPressed {
                Text(speechManager.recognizedText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .transition(.opacity)
            }
            Button(action: {}) {
                Image(systemName: "mic.fill")
                    .font(.largeTitle)
                    .padding()
                    .background(isPressed ? Color.green : Color.blue)  // Blue when pressed; red when idle.
                    .clipShape(Circle())
                    .foregroundColor(.white)
            }
            .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                if pressing {
                    // Button is being pressed.
                    if !isPressed {
                        isPressed = true
                        print("Mic button pressed – starting listening")
                        speechManager.startListening()
                    }
                } else {
                    // Button released.
                    isPressed = false
                    print("Mic button released – stopping listening")
                    speechManager.stopListening()
                    speechManager.processCommand(speechManager.recognizedText)
                }
            }, perform: {})
        }
        .padding()
    }
}

struct VoiceControlButton_Previews: PreviewProvider {
    static var previews: some View {
        VoiceControlButton(speechManager: SpeechManager())
    }
}
