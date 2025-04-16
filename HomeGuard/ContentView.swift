import SwiftUI

struct ContentView: View {
    @State private var showSplash = true
    
    // Lock screen state
    @State private var isLocked = true
    
    // Lock timeout (seconds). Default to 5 minutes
    @AppStorage("lockTimeout") var lockTimeout: Double = 300
    
    // Track the last time the user did something
    @State private var lastInteractionTime = Date()
    
    // Scene phase lets us detect backgrounding
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView()
            } else {
                if isLocked {
                    LockScreenView(isLocked: $isLocked)
                } else {
                    // Your main UI after unlocking
                    HomeGuardMainView()
                        .onAppear {
                            resetInactivityTimer()
                        }
                        // Trigger on user interaction:
                        .onTapGesture {
                            resetInactivityTimer()
                        }
                        // Check inactivity every second
                        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                            checkInactivity()
                        }
                        // NEW: automatically lock if the app goes into background or inactive
                        .onChange(of: scenePhase) { newPhase, _ in
                            if newPhase == .background || newPhase == .inactive {
                                isLocked = true
                            }
                        }                }
            }
        }
        .onAppear {
            // Simulate splash for 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut) {
                    showSplash = false
                }
            }
        }
    }
    
    private func resetInactivityTimer() {
        lastInteractionTime = Date()
    }
    
    private func checkInactivity() {
        let elapsed = Date().timeIntervalSince(lastInteractionTime)
        if elapsed >= lockTimeout {
            // Lock the app again
            isLocked = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
