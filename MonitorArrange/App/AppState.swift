import SwiftUI
import UserNotifications
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let edgeDetector = EdgeDetector()
    let displayManager = DisplayManager.shared
    let edgeIndicator = EdgeIndicatorController()
    @AppStorage("showNotification") var showNotification = true

    private var cancellables = Set<AnyCancellable>()

    private init() {
        edgeDetector.onEdgeTriggered = { [weak self] position in
            self?.applyArrangement(position)
        }
        edgeDetector.onMouseMoved = { [weak self] loc in
            guard let self else { return }
            // CGEventTap 소스는 메인 런루프(CFRunLoopGetMain)에 등록되어 콜백이 메인 스레드에서
            // 실행되지만, 가정이 깨지더라도 크래시하지 않도록 메인 스레드를 명시적으로 보장한다.
            if Thread.isMainThread {
                MainActor.assumeIsolated { self.edgeIndicator.handleMouse(cgLocation: loc) }
            } else {
                DispatchQueue.main.async {
                    self.edgeIndicator.handleMouse(cgLocation: loc)
                }
            }
        }
        displayManager.$displayConfigVersion
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.edgeIndicator.refreshDisplays() }
            }
            .store(in: &cancellables)
    }

    func bootstrap() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        edgeDetector.start()
        edgeIndicator.refreshDisplays()
    }

    /// 모든 배치 변경의 단일 경로: 정렬 → 알림 → 가장자리 깜빡임.
    @discardableResult
    func applyArrangement(_ position: DisplayPosition) -> Bool {
        guard displayManager.arrange(position: position) else { return false }
        if showNotification { sendNotification(position: position) }
        edgeIndicator.flash(position)
        return true
    }

    func undo() {
        guard displayManager.undoLastArrangement() else { return }
        let pos = DisplayManager.currentPosition()
        if showNotification, let pos {
            sendNotification(position: pos, isUndo: true)
        }
        edgeIndicator.flash(pos)
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
