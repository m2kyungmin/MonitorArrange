import Cocoa
import Combine
import os.log

private let logger = Logger(subsystem: "com.kyungmin.MonitorArrange", category: "EdgeDetector")

final class EdgeDetector: ObservableObject {

    @Published var isEnabled = true {
        didSet { isEnabled ? start() : stop() }
    }

    @Published var dwellThreshold: TimeInterval = 0.1
    @Published var lastTriggeredPosition: DisplayPosition?
    @Published var isRunning = false

    var onEdgeTriggered: ((DisplayPosition) -> Void)?
    var onMouseMoved: ((CGPoint) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pushingEdge: DisplayPosition?
    private var pushStartTime: Date?
    private var cooldownUntil: Date = .distantPast
    private var retryTimer: Timer?

    private static let cooldownDuration: TimeInterval = 3.0

    func start() {
        retryTimer?.invalidate()
        retryTimer = nil

        guard eventTap == nil else {
            logger.info("Event tap already exists")
            isRunning = true
            return
        }

        if !AXIsProcessTrusted() {
            logger.error("Accessibility not trusted — retrying in 2s")
            scheduleRetry()
            return
        }

        logger.info("Starting edge detector...")

        let mask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)

        let unmanagedSelf = Unmanaged.passUnretained(self)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let detector = Unmanaged<EdgeDetector>.fromOpaque(refcon).takeUnretainedValue()
                detector.handleMouseEvent(event)
                return Unmanaged.passRetained(event)
            },
            userInfo: unmanagedSelf.toOpaque()
        ) else {
            logger.error("Failed to create CGEventTap — retrying in 2s")
            scheduleRetry()
            return
        }

        logger.info("CGEventTap created successfully")
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        resetState()
    }

    private func scheduleRetry() {
        isRunning = false
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, self.isEnabled else { return }
            self.start()
        }
    }

    private func resetState() {
        pushingEdge = nil
        pushStartTime = nil
    }

    private func handleMouseEvent(_ event: CGEvent) {
        let loc = event.location
        onMouseMoved?(loc) // 커서 근접 표시용 — 쿨다운/감지 비활성과 무관하게 항상 전달

        guard isEnabled, Date() > cooldownUntil else { return }
        guard let builtin = DisplayManager.builtinDisplay(),
              DisplayManager.externalDisplay() != nil else { return }

        let deltaX = event.getIntegerValueField(.mouseEventDeltaX)
        let deltaY = event.getIntegerValueField(.mouseEventDeltaY)
        let b = builtin.bounds
        let tolerance: CGFloat = 1.0

        var detectedEdge: DisplayPosition?

        if loc.y <= b.origin.y + tolerance && deltaY < 0 {
            detectedEdge = .top
        } else if loc.y >= b.origin.y + b.height - tolerance && deltaY > 0 {
            detectedEdge = .bottom
        }

        if loc.x <= b.origin.x + tolerance && deltaX < 0 {
            detectedEdge = detectedEdge ?? .left
        } else if loc.x >= b.origin.x + b.width - tolerance && deltaX > 0 {
            detectedEdge = detectedEdge ?? .right
        }

        if let edge = detectedEdge, DisplayManager.currentPosition() == edge {
            detectedEdge = nil
        }

        guard let edge = detectedEdge else {
            resetState()
            return
        }

        if pushingEdge == edge {
            guard let start = pushStartTime else { return }
            if Date().timeIntervalSince(start) >= dwellThreshold {
                trigger(position: edge)
            }
        } else {
            pushingEdge = edge
            pushStartTime = Date()
        }
    }

    private func trigger(position: DisplayPosition) {
        logger.info("Edge triggered: \(position.rawValue)")
        cooldownUntil = Date().addingTimeInterval(Self.cooldownDuration)
        resetState()

        DispatchQueue.main.async { [weak self] in
            self?.lastTriggeredPosition = position
            self?.onEdgeTriggered?(position)
        }
    }

    deinit { stop() }
}
