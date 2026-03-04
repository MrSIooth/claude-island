//
//  NotchGeometry.swift
//  ClaudeIsland
//
//  Geometry calculations for the notch
//

import CoreGraphics
import Foundation

/// Pure geometry calculations for the notch
struct NotchGeometry: Sendable {
    let deviceNotchRect: CGRect
    let screenRect: CGRect
    let windowHeight: CGFloat
    let hasPhysicalNotch: Bool

    init(deviceNotchRect: CGRect, screenRect: CGRect, windowHeight: CGFloat, hasPhysicalNotch: Bool = false) {
        self.deviceNotchRect = deviceNotchRect
        self.screenRect = screenRect
        self.windowHeight = windowHeight
        self.hasPhysicalNotch = hasPhysicalNotch
    }

    /// The notch rect in screen coordinates (for hit testing with global mouse position)
    var notchScreenRect: CGRect {
        CGRect(
            x: screenRect.midX - deviceNotchRect.width / 2,
            y: screenRect.maxY - deviceNotchRect.height,
            width: deviceNotchRect.width,
            height: deviceNotchRect.height
        )
    }

    /// The mascot bar rect in screen coordinates for a given bar width.
    func mascotBarScreenRect(barWidth: CGFloat) -> CGRect {
        CGRect(
            x: screenRect.midX - barWidth / 2,
            y: screenRect.maxY - deviceNotchRect.height,
            width: barWidth,
            height: deviceNotchRect.height
        )
    }

    /// The opened panel rect in screen coordinates for a given size
    func openedScreenRect(for size: CGSize) -> CGRect {
        // Match the actual rendered panel size (tuned to match visual output)
        let width = size.width - 6
        let height = size.height - 30
        return CGRect(
            x: screenRect.midX - width / 2,
            y: screenRect.maxY - height,
            width: width,
            height: height
        )
    }

    /// Check if a point is in the notch/mascot bar area (with padding for easier interaction)
    func isPointInNotch(_ point: CGPoint, barWidth: CGFloat) -> Bool {
        mascotBarScreenRect(barWidth: barWidth).insetBy(dx: -10, dy: -5).contains(point)
    }

    /// Check if a point is in the opened panel area
    func isPointInOpenedPanel(_ point: CGPoint, size: CGSize) -> Bool {
        openedScreenRect(for: size).contains(point)
    }

    /// Check if a point is outside the opened panel (for closing)
    func isPointOutsidePanel(_ point: CGPoint, size: CGSize) -> Bool {
        !openedScreenRect(for: size).contains(point)
    }
}
