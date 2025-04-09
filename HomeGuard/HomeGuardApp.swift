import SwiftUI
import Speech

@main
struct HomeGuardApp: App {
    @StateObject private var logManager = EventLogManager()

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
            ContentView()
                .environmentObject(logManager)
        }
    }
}
