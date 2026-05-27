import Cocoa
import Combine

final class DisplayManager: ObservableObject {

    static let shared = DisplayManager()

    @Published var displayConfigVersion: UInt = 0
    private var previousPosition: DisplayPosition?

    struct DisplayInfo {
        let id: CGDirectDisplayID
        let bounds: CGRect
        let isBuiltin: Bool
    }

    private init() {
        CGDisplayRegisterReconfigurationCallback({ _, _, userInfo in
            guard let userInfo else { return }
            let manager = Unmanaged<DisplayManager>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async {
                manager.displayConfigVersion &+= 1
            }
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    deinit {
        CGDisplayRemoveReconfigurationCallback({ _, _, _ in }, nil)
    }

    static func activeDisplays() -> [DisplayInfo] {
        let maxDisplays: UInt32 = 10
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var count: UInt32 = 0
        CGGetActiveDisplayList(maxDisplays, &ids, &count)

        return (0..<Int(count)).map { i in
            DisplayInfo(
                id: ids[i],
                bounds: CGDisplayBounds(ids[i]),
                isBuiltin: CGDisplayIsBuiltin(ids[i]) != 0
            )
        }
    }

    static func builtinDisplay() -> DisplayInfo? {
        activeDisplays().first(where: \.isBuiltin)
    }

    static func externalDisplay() -> DisplayInfo? {
        activeDisplays().first(where: { !$0.isBuiltin })
    }

    // Tolerance band for position detection — handles offset arrangements after sleep/wake
    static func currentPosition() -> DisplayPosition? {
        guard let builtin = builtinDisplay(), let external = externalDisplay() else { return nil }
        let b = builtin.bounds
        let e = external.bounds
        let tolerance: CGFloat = 50

        let isAbove = e.maxY <= b.minY + tolerance && abs(e.midX - b.midX) < b.width
        let isBelow = e.minY >= b.maxY - tolerance && abs(e.midX - b.midX) < b.width
        let isLeft = e.maxX <= b.minX + tolerance && abs(e.midY - b.midY) < b.height
        let isRight = e.minX >= b.maxX - tolerance && abs(e.midY - b.midY) < b.height

        if isAbove { return .top }
        if isBelow { return .bottom }
        if isLeft { return .left }
        if isRight { return .right }
        return nil
    }

    @discardableResult
    func arrange(position: DisplayPosition) -> Bool {
        previousPosition = Self.currentPosition()

        guard let builtin = Self.builtinDisplay(), let external = Self.externalDisplay() else { return false }
        let b = builtin.bounds
        let e = external.bounds

        let origin: (x: Int32, y: Int32)
        switch position {
        case .top:
            let cx = (b.width - e.width) / 2
            origin = (Int32(b.origin.x + cx), Int32(b.origin.y - e.height))
        case .bottom:
            let cx = (b.width - e.width) / 2
            origin = (Int32(b.origin.x + cx), Int32(b.origin.y + b.height))
        case .left:
            let cy = (b.height - e.height) / 2
            origin = (Int32(b.origin.x - e.width), Int32(b.origin.y + cy))
        case .right:
            let cy = (b.height - e.height) / 2
            origin = (Int32(b.origin.x + b.width), Int32(b.origin.y + cy))
        }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let cfg = config else { return false }

        CGConfigureDisplayOrigin(cfg, external.id, origin.x, origin.y)

        if CGCompleteDisplayConfiguration(cfg, .permanently) == .success {
            return true
        } else {
            CGCancelDisplayConfiguration(cfg)
            return false
        }
    }

    @discardableResult
    func undoLastArrangement() -> Bool {
        guard let prev = previousPosition else { return false }
        previousPosition = nil
        return arrange(position: prev)
    }

    var canUndo: Bool { previousPosition != nil }
}
