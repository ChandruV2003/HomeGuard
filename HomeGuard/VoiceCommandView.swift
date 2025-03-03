import SwiftUI

@available(iOS 15.0, *)
struct VoiceCommandView: View {
    @ObservedObject var speechManager: SpeechManager
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voice Command:")
                .font(.headline)
            Text(highlightedVoiceText)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            if !speechManager.feedbackMessage.isEmpty {
                Text(speechManager.feedbackMessage)
                    .foregroundColor(.green)
                    .font(.subheadline)
            }
        }
        .padding(.horizontal)
    }
    
    private var highlightedVoiceText: AttributedString {
        var attr = AttributedString(speechManager.recognizedText)
        for keyword in speechManager.magicKeywords {
            if let range = attr.range(of: keyword, options: .caseInsensitive) {
                attr[range].foregroundColor = .orange
            }
        }
        if speechManager.commandRecognized {
            attr.foregroundColor = .green
        }
        return attr
    }
}

struct VoiceCommandView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 15.0, *) {
            VoiceCommandView(speechManager: SpeechManager())
        } else {
            Text("Requires iOS 15")
        }
    }
}
