#!/usr/bin/swift
// CLI prototype: verify CGConfigureDisplayOrigin rearranges displays
// Usage: swift display_rearrange_test.swift [top|left|right]
// Tests that programmatic display rearrangement works without restart

import Cocoa

let maxDisplays: UInt32 = 10
var displays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
var displayCount: UInt32 = 0
CGGetActiveDisplayList(maxDisplays, &displays, &displayCount)

let builtinID = displays[0..<Int(displayCount)].first { CGDisplayIsBuiltin($0) != 0 }
let externalID = displays[0..<Int(displayCount)].first { CGDisplayIsBuiltin($0) == 0 }

guard let builtin = builtinID, let external = externalID else {
    print("Built-in과 External 디스플레이가 모두 필요합니다.")
    print("현재 감지된 디스플레이:")
    for i in 0..<Int(displayCount) {
        let id = displays[i]
        let bounds = CGDisplayBounds(id)
        let isBuiltin = CGDisplayIsBuiltin(id) != 0
        print("  \(id): \(Int(bounds.width))x\(Int(bounds.height)) \(isBuiltin ? "[Built-in]" : "[External]")")
    }
    exit(1)
}

let builtinBounds = CGDisplayBounds(builtin)
let externalBounds = CGDisplayBounds(external)

print("Built-in: \(Int(builtinBounds.width))x\(Int(builtinBounds.height)) at (\(Int(builtinBounds.origin.x)), \(Int(builtinBounds.origin.y)))")
print("External: \(Int(externalBounds.width))x\(Int(externalBounds.height)) at (\(Int(externalBounds.origin.x)), \(Int(externalBounds.origin.y)))")

let position = CommandLine.arguments.count > 1 ? CommandLine.arguments[1].lowercased() : "right"

var newOriginX: Int32
var newOriginY: Int32

switch position {
case "top":
    // Center external above built-in
    let centerOffset = (builtinBounds.width - externalBounds.width) / 2
    newOriginX = Int32(builtinBounds.origin.x + centerOffset)
    newOriginY = Int32(builtinBounds.origin.y - externalBounds.height)
case "left":
    // Place external to the left, vertically centered
    let centerOffset = (builtinBounds.height - externalBounds.height) / 2
    newOriginX = Int32(builtinBounds.origin.x - externalBounds.width)
    newOriginY = Int32(builtinBounds.origin.y + centerOffset)
case "right":
    // Place external to the right, vertically centered
    let centerOffset = (builtinBounds.height - externalBounds.height) / 2
    newOriginX = Int32(builtinBounds.origin.x + builtinBounds.width)
    newOriginY = Int32(builtinBounds.origin.y + centerOffset)
case "bottom":
    let centerOffset = (builtinBounds.width - externalBounds.width) / 2
    newOriginX = Int32(builtinBounds.origin.x + centerOffset)
    newOriginY = Int32(builtinBounds.origin.y + builtinBounds.height)
default:
    print("Usage: swift display_rearrange_test.swift [top|left|right|bottom]")
    exit(1)
}

print("\nMoving external display to '\(position)': origin=(\(newOriginX), \(newOriginY))")

var config: CGDisplayConfigRef?
let beginErr = CGBeginDisplayConfiguration(&config)
guard beginErr == .success, let cfg = config else {
    print("CGBeginDisplayConfiguration failed: \(beginErr)")
    exit(1)
}

CGConfigureDisplayOrigin(cfg, external, newOriginX, newOriginY)

let completeErr = CGCompleteDisplayConfiguration(cfg, .permanently)
if completeErr == .success {
    print("Display rearranged successfully!")

    let newBounds = CGDisplayBounds(external)
    print("New external position: (\(Int(newBounds.origin.x)), \(Int(newBounds.origin.y)))")
} else {
    print("CGCompleteDisplayConfiguration failed: \(completeErr)")
    CGCancelDisplayConfiguration(cfg)
}
