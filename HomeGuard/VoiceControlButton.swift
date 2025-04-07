import SwiftUI

struct VoiceControlButton: View {
    @ObservedObject var speechManager: SpeechManager
    @State private var isPressed: Bool = false
    
    // Decide the size of the transcript area so the mic button never moves.
    private let transcriptWidth: CGFloat = 250
    private let transcriptHeight: CGFloat = 60
    
    var body: some View {
        VStack(spacing: 16) {
            
            // We place the transcript box in a known, fixed size, so the mic button doesn’t shift.
            ZStack(alignment: .center) {
                // A background rectangle
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(width: transcriptWidth, height: transcriptHeight)
                    .opacity(isPressed ? 1.0 : 0.0) // only show the background if pressed
                
                // If pressed, show recognized text (attributed)
                // If not pressed, we can show nothing or a placeholder
                if isPressed {
                    ScrollView(.vertical, showsIndicators: true) {
                        // Display your colored text from speechManager
                        Text(speechManager.recognizedAttributed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                    .frame(width: transcriptWidth - 16, height: transcriptHeight - 16)
                }
            }
            // Because we always have a fixed-size ZStack, the mic button below never shifts.
            
            // The mic button
            Button(action: {}) {
                Image(systemName: "mic.fill")
                    .font(.largeTitle)
                    .padding()
                    .background(buttonColor)
                    .clipShape(Circle())
                    .foregroundColor(.white)
            }
            // The long-press logic
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
                    // Add a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("Mic button delayed release – stopping listening")
                        speechManager.stopListening()
                        print("Final transcription after delay: \(speechManager.recognizedText)")
                        speechManager.processCommand(speechManager.recognizedText)
                    }
                }
            }, perform: {})
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    /// Decide the background color for the mic button:
    /// - Green if a command was recognized
    /// - Blue if currently pressed
    /// - Red otherwise
    private var buttonColor: Color {
        if speechManager.commandRecognized {
            return .green
        } else if isPressed {
            return .blue
        } else {
            return .red
        }
    }
}

struct VoiceControlButton_Previews: PreviewProvider {
    static var previews: some View {
        VoiceControlButton(speechManager: SpeechManager())
    }
}
