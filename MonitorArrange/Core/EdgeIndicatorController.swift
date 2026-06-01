import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.kyungmin.MonitorArrange", category: "EdgeIndicator")

/// 맥북 내장 화면의 가장자리에 외장 모니터가 붙어있는 방향을 은은하게 표시한다.
///
/// 표시 소스는 세 가지(항상 표시 · 위치 변경 시 깜빡임 · 커서 근접)이며,
/// 서로 충돌하지 않도록 각 소스의 세기(0...1) 중 최댓값에 밝기를 곱한 값을
/// 단일 윈도우 알파로 환산해 구동한다.
@MainActor
final class EdgeIndicatorController: ObservableObject {

    // MARK: - 설정 (UserDefaults 영속)

    @Published var flashOnChange: Bool { didSet { defaults.set(flashOnChange, forKey: Keys.flash) } }
    @Published var cursorApproach: Bool {
        didSet {
            defaults.set(cursorApproach, forKey: Keys.cursor)
            if !cursorApproach { cursorStrength = 0; apply(animated: true) }
        }
    }
    @Published var alwaysOn: Bool {
        didSet {
            defaults.set(alwaysOn, forKey: Keys.always)
            alwaysOnStrength = alwaysOn ? 1 : 0
            apply(animated: true)
        }
    }
    @Published var intensity: Double {
        didSet {
            defaults.set(intensity, forKey: Keys.intensity)
            apply(animated: false)
        }
    }
    /// 외장 모니터의 맞닿는(내장을 향한) 가장자리에도 글로우를 미러링한다.
    @Published var mirrorOnExternal: Bool {
        didSet {
            defaults.set(mirrorOnExternal, forKey: Keys.mirror)
            rebuildWindows()
            apply(animated: true)
        }
    }
    /// 글로우 색상(사용자 지정). 투명도는 intensity가 별도로 담당한다.
    @Published var glowColor: Color {
        didSet {
            if let c = NSColor(glowColor).usingColorSpace(.sRGB) {
                defaults.set([Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent)],
                             forKey: Keys.color)
            }
        }
    }

    // MARK: - 렌더 상태

    /// 외장 모니터가 붙어있는 방향 = 글로우를 그릴 가장자리.
    @Published private(set) var position: DisplayPosition?

    private var alwaysOnStrength: Double = 0
    private var cursorStrength: Double = 0
    private var flashStrength: Double = 0

    // MARK: - 구성값

    private let animationDuration: Double = 0.35
    private let flashHold: Double = 1.1
    private let cursorThreshold: CGFloat = 160

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let flash = "edgeIndicator.flashOnChange"
        static let cursor = "edgeIndicator.cursorApproach"
        static let always = "edgeIndicator.alwaysOn"
        static let intensity = "edgeIndicator.intensity"
        static let mirror = "edgeIndicator.mirrorExternal"
        static let color = "edgeIndicator.color"
    }

    private var builtinWindow: EdgeIndicatorWindow?
    private var externalWindow: EdgeIndicatorWindow?
    private var flashWork: DispatchWorkItem?
    private var orderOutWork: DispatchWorkItem?

    init() {
        defaults.register(defaults: [
            Keys.flash: true,
            Keys.cursor: true,
            Keys.always: false,
            Keys.intensity: 0.5,
            Keys.mirror: true,
        ])
        flashOnChange = defaults.bool(forKey: Keys.flash)
        cursorApproach = defaults.bool(forKey: Keys.cursor)
        alwaysOn = defaults.bool(forKey: Keys.always)
        intensity = defaults.double(forKey: Keys.intensity)
        mirrorOnExternal = defaults.bool(forKey: Keys.mirror)
        if let comps = defaults.array(forKey: Keys.color) as? [Double], comps.count == 3 {
            glowColor = Color(.sRGB, red: comps[0], green: comps[1], blue: comps[2])
        } else {
            // 저장된 색이 없으면 기존 강조색(accent)을 기본값으로.
            let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB)
            glowColor = Color(.sRGB,
                              red: Double(accent?.redComponent ?? 0.0),
                              green: Double(accent?.greenComponent ?? 0.48),
                              blue: Double(accent?.blueComponent ?? 1.0))
        }
        alwaysOnStrength = alwaysOn ? 1 : 0
    }

    // MARK: - 디스플레이 변화 반영

    /// 디스플레이 구성이 바뀔 때마다 호출. 현재 위치·윈도우 프레임을 갱신한다.
    func refreshDisplays() {
        position = DisplayManager.currentPosition()
        cursorStrength = 0
        // 주의: 여기서 진행 중인 flash를 취소하면 안 된다. arrange() 자체가 디스플레이 재구성을
        // 일으켜 이 함수가 곧바로 호출되므로, flash를 끄면 위치 변경 깜빡임이 즉시 사라진다.
        // 언플러그 등으로 position이 nil이 되면 뷰가 Color.clear를 그리므로 잔상은 없다.
        rebuildWindows()
        apply(animated: true)
    }

    // MARK: - 깜빡임 / 미리보기

    /// 배치가 바뀌었을 때 해당 가장자리를 잠깐 빛낸다. (설정 꺼져있으면 위치만 갱신)
    func flash(_ position: DisplayPosition?) {
        guard flashOnChange else {
            if let position { self.position = position }
            return
        }
        triggerFlash(position)
    }

    /// 설정 화면의 "표시 테스트" — 토글과 무관하게 해당 가장자리를 강제로 한 번 빛낸다.
    func preview(_ position: DisplayPosition) {
        triggerFlash(position)
    }

    private func triggerFlash(_ position: DisplayPosition?) {
        guard let position else { return }
        self.position = position
        rebuildWindows()
        flashWork?.cancel()
        flashStrength = 1
        apply(animated: true)

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.flashStrength = 0
            // 미리보기로 임시 변경된 위치를 실제 현재 위치로 되돌린다.
            self.position = DisplayManager.currentPosition()
            self.apply(animated: true)
        }
        flashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + flashHold, execute: work)
    }

    // MARK: - 커서 근접

    /// 마우스 이동 콜백(CG 좌표, top-left 원점). 경계(맞닿는 가장자리)에 가까울수록 진하게.
    /// 내장 화면에서는 외장을 향한 가장자리, 외장 화면에서는 내장을 향한(반대편) 가장자리 기준.
    func handleMouse(cgLocation loc: CGPoint) {
        guard cursorApproach, let pos = position,
              let builtin = DisplayManager.builtinDisplay() else {
            setCursorStrength(0)
            return
        }
        var strength = 0.0
        if builtin.bounds.contains(loc) {
            strength = proximity(loc, in: builtin.bounds, facing: pos)
        } else if let external = DisplayManager.externalDisplay(), external.bounds.contains(loc) {
            strength = proximity(loc, in: external.bounds, facing: pos.opposite)
        }
        setCursorStrength(strength)
    }

    /// 지정한 가장자리까지의 거리를 0...1 세기로 환산(threshold 안쪽에서만).
    private func proximity(_ loc: CGPoint, in bounds: CGRect, facing edge: DisplayPosition) -> Double {
        let dist: CGFloat
        switch edge {
        case .top: dist = loc.y - bounds.minY
        case .bottom: dist = bounds.maxY - loc.y
        case .left: dist = loc.x - bounds.minX
        case .right: dist = bounds.maxX - loc.x
        }
        return dist < cursorThreshold ? Double(1 - max(0, dist) / cursorThreshold) : 0
    }

    private func setCursorStrength(_ value: Double) {
        guard abs(value - cursorStrength) > 0.01 else { return }
        cursorStrength = value
        apply(animated: false) // 커서 추적은 즉시 반영(이징 없음)
    }

    // MARK: - 윈도우 구동

    private func apply(animated: Bool) {
        let effective = max(alwaysOnStrength, cursorStrength, flashStrength) * intensity
        orderOutWork?.cancel()

        setAlpha(builtinWindow, to: effective, animated: animated)
        setAlpha(externalWindow, to: effective, animated: animated)

        if effective <= 0.001 {
            let work = DispatchWorkItem { [weak self] in
                self?.builtinWindow?.orderOut(nil)
                self?.externalWindow?.orderOut(nil)
            }
            orderOutWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 0.1, execute: work)
        }
    }

    private func setAlpha(_ window: EdgeIndicatorWindow?, to value: Double, animated: Bool) {
        guard let window else { return }
        if value > 0.001 { window.orderFrontRegardless() }
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = animationDuration
                window.animator().alphaValue = value
            }
        } else {
            window.alphaValue = value
        }
    }

    private func rebuildWindows() {
        // 내장 화면 — 외장을 향한 가장자리
        if let screen = builtinScreen() {
            if builtinWindow == nil {
                let w = EdgeIndicatorWindow(contentRect: screen.frame)
                w.contentView = NSHostingView(rootView: EdgeIndicatorView(controller: self, mirrored: false))
                builtinWindow = w
            }
            builtinWindow?.setFrame(screen.frame, display: false)
        } else {
            if DisplayManager.builtinDisplay() == nil {
                logger.notice("내장 디스플레이가 없어 오버레이를 표시하지 않습니다")
            } else {
                logger.error("내장 디스플레이에 대응하는 NSScreen(NSScreenNumber) 매칭 실패 — 오버레이를 생성할 수 없습니다")
            }
            builtinWindow?.orderOut(nil)
            builtinWindow = nil
        }

        // 외장 화면 — 미러링 켜짐 + 위치 판별됨 + 외장 NSScreen 매칭 성공일 때만
        if mirrorOnExternal, position != nil, let screen = externalScreen() {
            if externalWindow == nil {
                let w = EdgeIndicatorWindow(contentRect: screen.frame)
                w.contentView = NSHostingView(rootView: EdgeIndicatorView(controller: self, mirrored: true))
                externalWindow = w
            }
            externalWindow?.setFrame(screen.frame, display: false)
        } else {
            externalWindow?.orderOut(nil)
            externalWindow = nil
        }
    }

    /// 내장 디스플레이에 대응하는 NSScreen을 NSScreenNumber로 매칭(수동 Y-flip 금지).
    private func builtinScreen() -> NSScreen? {
        screen(for: DisplayManager.builtinDisplay()?.id)
    }

    /// 외장 디스플레이에 대응하는 NSScreen.
    private func externalScreen() -> NSScreen? {
        screen(for: DisplayManager.externalDisplay()?.id)
    }

    private func screen(for id: CGDirectDisplayID?) -> NSScreen? {
        guard let id else { return nil }
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return NSScreen.screens.first {
            ($0.deviceDescription[key] as? NSNumber)?.uint32Value == id
        }
    }
}

// MARK: - 오버레이 윈도우

/// 포커스를 빼앗지 않고 클릭을 통과시키는 전체 화면 투명 패널.
final class EdgeIndicatorWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        alphaValue = 0
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - 글로우 뷰

struct EdgeIndicatorView: View {
    @ObservedObject var controller: EdgeIndicatorController
    /// true면 외장 화면용 — 맞닿는 반대편 가장자리에 그린다.
    var mirrored: Bool = false

    var body: some View {
        if let pos = controller.position {
            EdgeGlow(position: mirrored ? pos.opposite : pos, color: controller.glowColor)
        } else {
            Color.clear
        }
    }
}

/// 지정한 가장자리에서 화면 안쪽으로 부드럽게 사라지는 그라데이션.
struct EdgeGlow: View {
    let position: DisplayPosition
    var color: Color = .accentColor
    var thickness: CGFloat = 160

    private var horizontal: Bool { position == .left || position == .right }

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(gradient(span: horizontal ? geo.size.width : geo.size.height))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func gradient(span: CGFloat) -> LinearGradient {
        let frac = Double(min(0.6, thickness / max(span, 1)))
        let stops: [Gradient.Stop]
        switch position {
        case .right, .bottom:
            stops = [
                .init(color: color.opacity(0), location: 0),
                .init(color: color.opacity(0), location: 1 - frac),
                .init(color: color, location: 1),
            ]
        case .left, .top:
            stops = [
                .init(color: color, location: 0),
                .init(color: color.opacity(0), location: frac),
                .init(color: color.opacity(0), location: 1),
            ]
        }
        return LinearGradient(
            gradient: Gradient(stops: stops),
            startPoint: horizontal ? .leading : .top,
            endPoint: horizontal ? .trailing : .bottom
        )
    }
}
