//
//  NotchHeaderView.swift
//  ClaudeIsland
//
//  Header bar for the dynamic island
//

import Combine
import SwiftUI

struct ClaudeCrabIcon: View {
    let size: CGFloat
    let color: Color
    var animateLegs: Bool = false
    var sleeping: Bool = false

    @State private var bookPhase: Int = 0

    private let animTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    init(size: CGFloat = 16, color: Color = Color(red: 0.85, green: 0.47, blue: 0.34), animateLegs: Bool = false, sleeping: Bool = false) {
        self.size = size
        self.color = color
        self.animateLegs = animateLegs
        self.sleeping = sleeping
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 52.0
            let xOffset = (canvasSize.width - 66 * scale) / 2
            let tx = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: xOffset / scale, y: 0)

            func fill(_ r: CGRect, _ c: Color) {
                context.fill(Path { p in p.addRect(r) }.applying(tx), with: .color(c))
            }

            // Antennae
            fill(CGRect(x: 0, y: 13, width: 6, height: 13), color)
            fill(CGRect(x: 60, y: 13, width: 6, height: 13), color)

            // Outer legs (always static)
            fill(CGRect(x: 6, y: 39, width: 6, height: 13), color)
            fill(CGRect(x: 54, y: 39, width: 6, height: 13), color)

            if animateLegs {
                // Inner legs shortened — crab "arms" holding the book
                fill(CGRect(x: 18, y: 39, width: 6, height: 5), color)
                fill(CGRect(x: 42, y: 39, width: 6, height: 5), color)
            } else {
                // Normal inner legs
                fill(CGRect(x: 18, y: 39, width: 6, height: 13), color)
                fill(CGRect(x: 42, y: 39, width: 6, height: 13), color)
            }

            // Main body
            fill(CGRect(x: 6, y: 0, width: 54, height: 39), color)

            // Book (processing state only)
            if animateLegs {
                let pageColor = Color(white: 0.82)
                let spineColor = Color(red: 0.35, green: 0.22, blue: 0.12)
                let flipColor = Color(white: 0.95)
                let bookY: CGFloat = 34
                let bookH: CGFloat = 18

                // Left page
                fill(CGRect(x: 16, y: bookY, width: 16, height: bookH), pageColor)
                // Right page
                fill(CGRect(x: 36, y: bookY, width: 16, height: bookH), pageColor)
                // Spine
                fill(CGRect(x: 32, y: bookY - 2, width: 4, height: bookH + 4), spineColor)

                // Turning page — arcs from right over the spine to the left
                switch bookPhase {
                case 0, 1: break // rest
                case 2: fill(CGRect(x: 37, y: bookY - 4, width: 14, height: bookH), flipColor)
                case 3: fill(CGRect(x: 35, y: bookY - 7, width: 8,  height: bookH), flipColor)
                case 4: fill(CGRect(x: 32, y: bookY - 9, width: 4,  height: bookH), flipColor)
                case 5: fill(CGRect(x: 25, y: bookY - 7, width: 8,  height: bookH), flipColor)
                case 6: fill(CGRect(x: 17, y: bookY - 4, width: 14, height: bookH), flipColor)
                case 7: break // rest
                default: break
                }
            }

            // Eyes — flat lines when sleeping, squares when awake
            if sleeping {
                fill(CGRect(x: 12, y: 16, width: 8, height: 2), .black)
                fill(CGRect(x: 46, y: 16, width: 8, height: 2), .black)
            } else {
                fill(CGRect(x: 12, y: 13, width: 6, height: 6.5), .black)
                fill(CGRect(x: 48, y: 13, width: 6, height: 6.5), .black)
            }
        }
        .frame(width: size * (66.0 / 52.0), height: size)
        .onReceive(animTimer) { _ in
            if animateLegs {
                bookPhase = (bookPhase + 1) % 8
            }
        }
    }
}

// Pixel art permission indicator icon
struct PermissionIndicatorIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 14, color: Color = Color(red: 0.11, green: 0.12, blue: 0.13)) {
        self.size = size
        self.color = color
    }

    // Visible pixel positions from the SVG (at 30x30 scale)
    private let pixels: [(CGFloat, CGFloat)] = [
        (7, 7), (7, 11),           // Left column
        (11, 3),                    // Top left
        (15, 3), (15, 19), (15, 27), // Center column
        (19, 3), (19, 15),          // Right of center
        (23, 7), (23, 11)           // Right column
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let pixelSize: CGFloat = 4 * scale

            for (x, y) in pixels {
                let rect = CGRect(
                    x: x * scale - pixelSize / 2,
                    y: y * scale - pixelSize / 2,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

// Pixel art "ready for input" indicator icon (checkmark/done shape)
struct ReadyForInputIndicatorIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 14, color: Color = TerminalColors.green) {
        self.size = size
        self.color = color
    }

    // Checkmark shape pixel positions (at 30x30 scale)
    private let pixels: [(CGFloat, CGFloat)] = [
        (5, 15),                    // Start of checkmark
        (9, 19),                    // Down stroke
        (13, 23),                   // Bottom of checkmark
        (17, 19),                   // Up stroke begins
        (21, 15),                   // Up stroke
        (25, 11),                   // Up stroke
        (29, 7)                     // End of checkmark
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let pixelSize: CGFloat = 4 * scale

            for (x, y) in pixels {
                let rect = CGRect(
                    x: x * scale - pixelSize / 2,
                    y: y * scale - pixelSize / 2,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

