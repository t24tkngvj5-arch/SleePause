import SwiftUI

@main
struct SleepPauseApp: App {
    @StateObject private var app = AppState()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(app)
        }
    }
}
