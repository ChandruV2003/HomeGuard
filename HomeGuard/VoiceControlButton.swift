import SwiftUI

struct VoiceControlButton: View {
    @ObservedObject var speechManager: SpeechManager
    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                if speechManager.isListening {
                    speechManager.stopListening()
                } else {
                    speechManager.startListening()
                }
            }) {
                Text(speechManager.isListening ? "Stop Voice" : "Start Voice")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(speechManager.isListening ? Color.red : Color.green)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
}

struct VoiceControlButton_Previews: PreviewProvider {
    static var previews: some View {
        VoiceControlButton(speechManager: SpeechManager())
    }
}
