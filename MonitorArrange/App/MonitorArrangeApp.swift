import SwiftUI

@main
struct MonitorArrangeApp: App {
    @StateObject private var appState = AppState.shared

    init() {
        AppState.shared.bootstrap()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState, displayManager: appState.displayManager, edgeDetector: appState.edgeDetector)
        } label: {
            Image(systemName: "display.2")
        }

        Settings {
            SettingsView(edgeDetector: appState.edgeDetector)
        }
    }
}
