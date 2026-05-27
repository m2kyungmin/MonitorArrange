import SwiftUI
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let edgeDetector = EdgeDetector()
    let displayManager = DisplayManager.shared
    @AppStorage("showNotification") var showNotification = true

    private init() {
        edgeDetector.onEdgeTriggered = { [weak self] position in
            guard let self else { return }
            if self.displayManager.arrange(position: position) && self.showNotification {
                self.sendNotification(position: position)
            }
        }
    }

    func bootstrap() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        edgeDetector.start()
    }

    func undo() {
        if displayManager.undoLastArrangement(), showNotification {
            if let pos = DisplayManager.currentPosition() {
                sendNotification(position: pos, isUndo: true)
            }
        }
    }

    private func sendNotification(position: DisplayPosition, isUndo: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = "MonitorArrange"
        content.body = isUndo
            ? "이전 위치(\(position.label))로 되돌렸습니다"
            : "외장 모니터를 \(position.label)으로 이동했습니다"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
