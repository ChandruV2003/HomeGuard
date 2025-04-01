import SwiftUI

struct VoiceControlButton: View {
    @ObservedObject var speechManager: SpeechManager
    @State private var isPressed: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // Recognized text box appears only while the mic is pressed.
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
                    .background(isPressed ? Color.blue : Color.red)
                    .clipShape(Circle())
                    .foregroundColor(.white)
            }
            .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                if pressing {
                    if !isPressed {
                        isPressed = true
                        print("Mic button pressed – starting listening")
                        speechManager.startListening()
                    }
                } else {
                    isPressed = false
                    print("Mic button released – waiting for final transcription")
                    // Increase the delay to allow final results to arrive.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("Mic button delayed release – stopping listening")
                        speechManager.stopListening()
                        print("Final transcription after delay: \(speechManager.recognizedText)")
                        speechManager.processCommand(speechManager.recognizedText)
                    }
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
