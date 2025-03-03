import SwiftUI
import Speech

@main
struct HomeGuardApp: App {
    init() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("Speech recognition authorized")
            default:
                print("Speech recognition not authorized")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            HomeGuardMainView()
        }
    }
}
