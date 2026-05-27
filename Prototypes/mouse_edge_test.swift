#!/usr/bin/swift
// CLI prototype: verify CGEventTap captures mouse position + delta at screen edges
// Run: swift mouse_edge_test.swift
// Requires: Accessibility permission (System Settings > Privacy > Accessibility)

import Cocoa

print("=== Mouse Edge Detection Prototype ===")
print("Accessibility trusted: \(AXIsProcessTrusted())")

if !AXIsProcessTrusted() {
    print("⚠ Accessibility 권한이 필요합니다.")
    print("  System Settings > Privacy & Security > Accessibility 에서 Terminal을 추가하세요.")
    print("  권한 부여 후 다시 실행해주세요.")

    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
    exit(1)
}

// List all displays
let maxDisplays: UInt32 = 10
var displays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
var displayCount: UInt32 = 0
CGGetActiveDisplayList(maxDisplays, &displays, &displayCount)

print("\n--- Connected Displays ---")
for i in 0..<Int(displayCount) {
    let id = displays[i]
    let bounds = CGDisplayBounds(id)
    let isBuiltin = CGDisplayIsBuiltin(id) != 0
    print("  Display \(id): \(Int(bounds.width))x\(Int(bounds.height)) at (\(Int(bounds.origin.x)), \(Int(bounds.origin.y))) \(isBuiltin ? "[Built-in]" : "[External]")")
}

// Find built-in and external displays
let builtinID = displays[0..<Int(displayCount)].first { CGDisplayIsBuiltin($0) != 0 }
let externalID = displays[0..<Int(displayCount)].first { CGDisplayIsBuiltin($0) == 0 }

guard let builtin = builtinID else {
    print("Built-in 디스플레이를 찾을 수 없습니다.")
    exit(1)
}

let builtinBounds = CGDisplayBounds(builtin)
print("\nBuilt-in bounds: \(builtinBounds)")
print("Monitoring mouse position and delta... (Ctrl+C to stop)\n")
print("Format: pos=(x,y) delta=(dx,dy) edge=[TOP/LEFT/RIGHT/BOTTOM/none] pushing=[yes/no]")

var edgeDwellStart: Date?
var currentEdge: String = "none"
let dwellThreshold: TimeInterval = 0.7

func eventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .mouseMoved || type == .leftMouseDragged || type == .rightMouseDragged {
        let location = event.location
        let deltaX = event.getIntegerValueField(.mouseEventDeltaX)
        let deltaY = event.getIntegerValueField(.mouseEventDeltaY)

        let tolerance: CGFloat = 1.0
        var edge = "none"
        var pushing = false

        // Top edge: y == builtinBounds.origin.y (top of screen in CG coords)
        if location.y <= builtinBounds.origin.y + tolerance {
            edge = "TOP"
            pushing = deltaY < 0
        }
        // Bottom edge
        else if location.y >= builtinBounds.origin.y + builtinBounds.height - tolerance {
            edge = "BOTTOM"
            pushing = deltaY > 0
        }
        // Left edge
        if location.x <= builtinBounds.origin.x + tolerance {
            edge = (edge == "none") ? "LEFT" : edge
            pushing = pushing || deltaX < 0
        }
        // Right edge
        else if location.x >= builtinBounds.origin.x + builtinBounds.width - tolerance {
            edge = (edge == "none") ? "RIGHT" : edge
            pushing = pushing || deltaX > 0
        }

        if edge != "none" && pushing {
            if currentEdge != edge {
                currentEdge = edge
                edgeDwellStart = Date()
            }
            let dwellTime = Date().timeIntervalSince(edgeDwellStart ?? Date())
            print("pos=(\(Int(location.x)),\(Int(location.y))) delta=(\(deltaX),\(deltaY)) edge=\(edge) pushing=yes dwell=\(String(format: "%.1f", dwellTime))s")

            if dwellTime >= dwellThreshold {
                print(">>> TRIGGER: Rearrange external monitor to \(edge)! <<<")
                edgeDwellStart = Date().addingTimeInterval(5) // cooldown
            }
        } else {
            if currentEdge != "none" {
                currentEdge = "none"
                edgeDwellStart = nil
            }
        }
    }
    return Unmanaged.passRetained(event)
}

let eventMask = (1 << CGEventType.mouseMoved.rawValue)
    | (1 << CGEventType.leftMouseDragged.rawValue)
    | (1 << CGEventType.rightMouseDragged.rawValue)

guard let eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: eventCallback,
    userInfo: nil
) else {
    print("CGEventTap 생성 실패. Accessibility 권한을 확인하세요.")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)

print("Event tap active. Move mouse to screen edges to test.\n")
CFRunLoopRun()
