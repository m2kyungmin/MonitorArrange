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
            MenuBarLabel(displayManager: appState.displayManager)
        }

        Settings {
            SettingsView(edgeDetector: appState.edgeDetector, indicator: appState.edgeIndicator)
        }
    }
}

/// 메뉴바 아이콘 — 외장 모니터가 붙어있는 방향을 반영한다.
struct MenuBarLabel: View {
    @ObservedObject var displayManager: DisplayManager

    var body: some View {
        let _ = displayManager.displayConfigVersion
        let hasExternal = DisplayManager.externalDisplay() != nil
        let pos = DisplayManager.currentPosition()
        // 외장이 있는데 위치를 판별할 수 없는 경우는 일반 아이콘과 구분되도록 경고 배지를 쓴다.
        Image(systemName: hasExternal ? (pos?.icon ?? "display.trianglebadge.exclamationmark") : "display")
    }
}
