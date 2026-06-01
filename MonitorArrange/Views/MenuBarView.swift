import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var displayManager: DisplayManager
    @ObservedObject var edgeDetector: EdgeDetector
    @AppStorage("showNotification") private var showNotification = true

    var body: some View {
        // displayConfigVersion forces re-render when displays change
        let _ = displayManager.displayConfigVersion
        let currentPos = DisplayManager.currentPosition()
        let hasExternal = DisplayManager.externalDisplay() != nil

        if hasExternal {
            if let pos = currentPos {
                Text("현재: 외장모니터 \(pos.label)")
                    .font(.headline)
            }
            Divider()

            Text("모니터 위치 변경")
                .font(.caption)
            ForEach(DisplayPosition.allCases, id: \.self) { position in
                Button {
                    rearrange(to: position)
                } label: {
                    HStack {
                        Image(systemName: position.icon)
                        Text(position.label)
                        if currentPos == position {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .keyboardShortcut(shortcut(for: position))
            }

            if displayManager.canUndo {
                Divider()
                Button("되돌리기") {
                    appState.undo()
                }
                .keyboardShortcut("z")
            }
        } else {
            Text("외장 모니터 없음")
                .foregroundStyle(.secondary)
        }

        Divider()

        Toggle("자동 감지", isOn: $edgeDetector.isEnabled)
            .keyboardShortcut("a")

        Toggle("알림 표시", isOn: $showNotification)

        Divider()

        SettingsLink {
            Text("설정...")
        }
        .keyboardShortcut(",")

        Button("종료") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func rearrange(to position: DisplayPosition) {
        appState.applyArrangement(position)
    }

    private func shortcut(for position: DisplayPosition) -> KeyboardShortcut {
        switch position {
        case .top: KeyboardShortcut(.upArrow, modifiers: .command)
        case .bottom: KeyboardShortcut(.downArrow, modifiers: .command)
        case .left: KeyboardShortcut(.leftArrow, modifiers: .command)
        case .right: KeyboardShortcut(.rightArrow, modifiers: .command)
        }
    }
}
