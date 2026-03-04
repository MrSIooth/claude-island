//
//  NotchHeaderView.swift
//  ClaudeIsland
//
//  Header bar for the dynamic island
//

import Combine
import SwiftUI

/// Time-of-day accessories for the crab
enum CrabAccessory {
    case nightcap    // 22:00–05:59
    case sunglasses  // 10:00–15:59
    case none
}

/// Mood expressions for the crab's eyes
enum CrabMood {
    case normal     // standard square eyes
    case question   // "?" drawn on face (AskUserQuestion)
    case alert      // "!" drawn on face (tool permission)
    case happy      // ★_★ star eyes (task completion)
    case wideEyes   // O_O wide circular eyes (error/interrupt)
    case sleeping   // flat closed lines
    case sweatDrop  // normal eyes + sweat drop (compacting/retrying)
}

struct ClaudeCrabIcon: View {
    let size: CGFloat
    let color: Color
    var animateLegs: Bool = false
    var mood: CrabMood = .normal
    /// Eye shift for facing direction: negative = look left, positive = look right, 0 = center
    var eyeShift: CGFloat = 0
    /// Currently active tool name (shown as held item during processing)
    var currentTool: String? = nil
    /// Time-of-day accessory
    var timeAccessory: CrabAccessory = .none
    /// Show trophy (task completion)
    var showTrophy: Bool = false

    @State private var bookPhase: Int = 0

    /// Pencil sway offset for writing animation (shared between legs and pencil drawing)
    private var pencilSway: CGFloat {
        switch bookPhase {
        case 0, 1: return 0
        case 2, 3: return 4
        case 4: return 6
        case 5, 6: return 2
        case 7: return -2
        default: return 0
        }
    }

    private let animTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    init(size: CGFloat = 16, color: Color = Color(red: 0.85, green: 0.47, blue: 0.34), animateLegs: Bool = false, mood: CrabMood = .normal, eyeShift: CGFloat = 0, currentTool: String? = nil, timeAccessory: CrabAccessory = .none, showTrophy: Bool = false) {
        self.size = size
        self.color = color
        self.animateLegs = animateLegs
        self.mood = mood
        self.eyeShift = eyeShift
        self.currentTool = currentTool
        self.timeAccessory = timeAccessory
        self.showTrophy = showTrophy
    }

    /// Extra internal-coord units above the body for accessories (nightcap extends to y ≈ -23)
    private var topPadding: CGFloat {
        timeAccessory == .nightcap ? 24 : 0
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 52.0
            let pad = topPadding
            let xOffset = (canvasSize.width - 66 * scale) / 2
            let tx = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: xOffset / scale, y: pad)

            func fill(_ r: CGRect, _ c: Color) {
                context.fill(Path { p in p.addRect(r) }.applying(tx), with: .color(c))
            }

            // Antennae
            fill(CGRect(x: 0, y: 13, width: 6, height: 13), color)
            fill(CGRect(x: 60, y: 13, width: 6, height: 13), color)

            // Outer legs (always static)
            fill(CGRect(x: 6, y: 39, width: 6, height: 13), color)
            fill(CGRect(x: 54, y: 39, width: 6, height: 13), color)

            if animateLegs && (currentTool == "Edit" || currentTool == "Write") {
                // Inner legs reach down toward the pencil, following sway
                let legSway = pencilSway
                fill(CGRect(x: 20 + legSway, y: 39, width: 6, height: 10), color) // left arm
                fill(CGRect(x: 28 + legSway, y: 39, width: 6, height: 10), color) // right arm
            } else if animateLegs || showTrophy {
                // Inner legs shortened — crab "arms" holding the item
                fill(CGRect(x: 18, y: 39, width: 6, height: 5), color)
                fill(CGRect(x: 42, y: 39, width: 6, height: 5), color)
            } else {
                // Normal inner legs
                fill(CGRect(x: 18, y: 39, width: 6, height: 13), color)
                fill(CGRect(x: 42, y: 39, width: 6, height: 13), color)
            }

            // Main body
            fill(CGRect(x: 6, y: 0, width: 54, height: 39), color)

            // Held item (processing state only) — dispatch on tool name
            if animateLegs {
                drawHeldItem(fill: fill, tool: currentTool)
            }

            // Trophy (task completion)
            if showTrophy {
                drawTrophy(fill: fill)
            }

            // Nightcap — drawn after body, before eyes
            if timeAccessory == .nightcap {
                drawNightcap(fill: fill)
            }

            // Eyes — mood-dependent shapes, shifted for facing direction
            let s = eyeShift
            let fc: Color = .black  // face glyph color
            switch mood {
            case .normal:
                fill(CGRect(x: 12 + s, y: 13, width: 6, height: 6.5), fc)
                fill(CGRect(x: 48 + s, y: 13, width: 6, height: 6.5), fc)
            case .question:
                // "?" drawn centered on face — pixel art question mark
                // Top curve of ?
                fill(CGRect(x: 24, y: 5, width: 18, height: 4), fc)
                fill(CGRect(x: 21, y: 9, width: 6, height: 4), fc)
                fill(CGRect(x: 39, y: 9, width: 6, height: 4), fc)
                // Right descender
                fill(CGRect(x: 36, y: 13, width: 6, height: 4), fc)
                // Middle stem
                fill(CGRect(x: 30, y: 17, width: 6, height: 6), fc)
                // Dot
                fill(CGRect(x: 30, y: 27, width: 6, height: 5), fc)
            case .alert:
                // "!" drawn centered on face — pixel art exclamation mark
                // Tall stem
                fill(CGRect(x: 30, y: 5, width: 6, height: 18), fc)
                // Dot
                fill(CGRect(x: 30, y: 27, width: 6, height: 5), fc)
            case .happy:
                // ★_★ star eyes — pixel art 4-pointed stars
                // Left star: center + 4 points
                fill(CGRect(x: 14 + s, y: 14, width: 4, height: 4), fc)   // center
                fill(CGRect(x: 15 + s, y: 11, width: 2, height: 3), fc)   // top
                fill(CGRect(x: 15 + s, y: 18, width: 2, height: 3), fc)   // bottom
                fill(CGRect(x: 11 + s, y: 15, width: 3, height: 2), fc)   // left
                fill(CGRect(x: 18 + s, y: 15, width: 3, height: 2), fc)   // right
                // Right star: center + 4 points
                fill(CGRect(x: 47 + s, y: 14, width: 4, height: 4), fc)   // center
                fill(CGRect(x: 48 + s, y: 11, width: 2, height: 3), fc)   // top
                fill(CGRect(x: 48 + s, y: 18, width: 2, height: 3), fc)   // bottom
                fill(CGRect(x: 44 + s, y: 15, width: 3, height: 2), fc)   // left
                fill(CGRect(x: 51 + s, y: 15, width: 3, height: 2), fc)   // right
            case .wideEyes:
                // O_O — wide circular eyes (larger than normal)
                // Left eye — hollow square (outline)
                fill(CGRect(x: 10 + s, y: 10, width: 12, height: 3), fc)  // top
                fill(CGRect(x: 10 + s, y: 19, width: 12, height: 3), fc)  // bottom
                fill(CGRect(x: 10 + s, y: 13, width: 3, height: 6), fc)   // left
                fill(CGRect(x: 19 + s, y: 13, width: 3, height: 6), fc)   // right
                // Right eye — hollow square (outline)
                fill(CGRect(x: 44 + s, y: 10, width: 12, height: 3), fc)  // top
                fill(CGRect(x: 44 + s, y: 19, width: 12, height: 3), fc)  // bottom
                fill(CGRect(x: 44 + s, y: 13, width: 3, height: 6), fc)   // left
                fill(CGRect(x: 53 + s, y: 13, width: 3, height: 6), fc)   // right
            case .sleeping:
                // Flat closed lines, lower
                fill(CGRect(x: 12 + s, y: 16, width: 8, height: 2), fc)
                fill(CGRect(x: 46 + s, y: 16, width: 8, height: 2), fc)
            case .sweatDrop:
                // Normal eyes + sweat drop on right side
                fill(CGRect(x: 12 + s, y: 13, width: 6, height: 6.5), fc)
                fill(CGRect(x: 48 + s, y: 13, width: 6, height: 6.5), fc)
                // Sweat drop — small teardrop shape on upper-right of body
                let dropColor = Color(red: 0.4, green: 0.7, blue: 1.0)
                fill(CGRect(x: 56, y: 4, width: 4, height: 3), dropColor)
                fill(CGRect(x: 55, y: 7, width: 6, height: 6), dropColor)
                fill(CGRect(x: 56, y: 13, width: 4, height: 3), dropColor)
            }

            // Sunglasses — drawn after eyes to cover them (skip for ? and ! faces)
            if timeAccessory == .sunglasses && mood != .question && mood != .alert {
                drawSunglasses(fill: fill, eyeShift: s)
            }
        }
        .frame(width: size * (66.0 / 52.0), height: (52.0 + topPadding) * size / 52.0)
        .onReceive(animTimer) { _ in
            if animateLegs {
                bookPhase = (bookPhase + 1) % 8
            }
        }
    }

    // MARK: - Held Item Drawing

    /// Draw the item the crab holds based on active tool
    private func drawHeldItem(fill: (CGRect, Color) -> Void, tool: String?) {
        switch tool {
        case "Edit", "Write":
            drawPencil(fill: fill)
        case "WebFetch", "WebSearch":
            drawGlobe(fill: fill)
        default:
            drawBook(fill: fill)
        }
    }

    private func drawBook(fill: (CGRect, Color) -> Void) {
        let pageColor = Color(white: 0.82)
        let spineColor = Color(red: 0.35, green: 0.22, blue: 0.12)
        let flipColor = Color(white: 0.95)
        let bookY: CGFloat = 34
        let bookH: CGFloat = 18

        fill(CGRect(x: 16, y: bookY, width: 16, height: bookH), pageColor)
        fill(CGRect(x: 36, y: bookY, width: 16, height: bookH), pageColor)
        fill(CGRect(x: 32, y: bookY - 2, width: 4, height: bookH + 4), spineColor)

        switch bookPhase {
        case 0, 1: break
        case 2: fill(CGRect(x: 37, y: bookY - 4, width: 14, height: bookH), flipColor)
        case 3: fill(CGRect(x: 35, y: bookY - 7, width: 8,  height: bookH), flipColor)
        case 4: fill(CGRect(x: 32, y: bookY - 9, width: 4,  height: bookH), flipColor)
        case 5: fill(CGRect(x: 25, y: bookY - 7, width: 8,  height: bookH), flipColor)
        case 6: fill(CGRect(x: 17, y: bookY - 4, width: 14, height: bookH), flipColor)
        case 7: break
        default: break
        }
    }

    private func drawPencil(fill: (CGRect, Color) -> Void) {
        let shaft = Color(red: 1.0, green: 0.85, blue: 0.2)  // yellow
        let tip = Color(red: 0.2, green: 0.2, blue: 0.2)      // dark gray
        let eraser = Color(red: 0.95, green: 0.55, blue: 0.65) // pink
        let band = Color(red: 0.7, green: 0.7, blue: 0.7)     // metal band
        let ink = Color(red: 0.3, green: 0.3, blue: 0.8)       // writing marks
        let sway = pencilSway

        // Pencil — larger, angled ~45°, animated with sway
        fill(CGRect(x: 14 + sway, y: 52, width: 8, height: 6), tip)     // tip
        fill(CGRect(x: 17 + sway, y: 44, width: 8, height: 8), shaft)   // lower shaft
        fill(CGRect(x: 22 + sway, y: 36, width: 8, height: 8), shaft)   // mid shaft
        fill(CGRect(x: 27 + sway, y: 30, width: 8, height: 6), shaft)   // upper shaft
        fill(CGRect(x: 32 + sway, y: 27, width: 8, height: 5), band)    // metal band
        fill(CGRect(x: 36 + sway, y: 22, width: 8, height: 5), eraser)  // eraser

        // Writing marks below the tip — scribble trail
        let markPhase = bookPhase % 4
        if markPhase >= 1 { fill(CGRect(x: 10, y: 58, width: 12, height: 3), ink) }
        if markPhase >= 2 { fill(CGRect(x: 24, y: 61, width: 14, height: 3), ink) }
        if markPhase >= 3 { fill(CGRect(x: 14, y: 64, width: 16, height: 3), ink) }
    }

    private func drawGlobe(fill: (CGRect, Color) -> Void) {
        let line = Color(red: 0.4, green: 0.65, blue: 1.0)

        // Circle outline (approximated with pixel blocks)
        fill(CGRect(x: 28, y: 34, width: 12, height: 3), line)  // top
        fill(CGRect(x: 28, y: 51, width: 12, height: 3), line)  // bottom
        fill(CGRect(x: 22, y: 37, width: 3, height: 14), line)  // left
        fill(CGRect(x: 43, y: 37, width: 3, height: 14), line)  // right
        // Horizontal equator
        fill(CGRect(x: 22, y: 42, width: 24, height: 3), line)
        // Vertical meridian
        fill(CGRect(x: 32, y: 34, width: 3, height: 20), line)
    }

    private func drawTrophy(fill: (CGRect, Color) -> Void) {
        let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
        let darkGold = Color(red: 0.85, green: 0.65, blue: 0.0)
        let shine = Color(red: 1.0, green: 0.95, blue: 0.5)

        // Cup — wider at top, tapers down
        fill(CGRect(x: 20, y: 34, width: 26, height: 4), gold)       // rim
        fill(CGRect(x: 22, y: 38, width: 22, height: 5), gold)       // upper cup
        fill(CGRect(x: 26, y: 43, width: 14, height: 3), gold)       // taper

        // Handles
        fill(CGRect(x: 14, y: 36, width: 6, height: 3), darkGold)    // left top
        fill(CGRect(x: 12, y: 39, width: 3, height: 4), darkGold)    // left side
        fill(CGRect(x: 14, y: 43, width: 6, height: 3), darkGold)    // left bottom
        fill(CGRect(x: 46, y: 36, width: 6, height: 3), darkGold)    // right top
        fill(CGRect(x: 51, y: 39, width: 3, height: 4), darkGold)    // right side
        fill(CGRect(x: 46, y: 43, width: 6, height: 3), darkGold)    // right bottom

        // Stem
        fill(CGRect(x: 30, y: 46, width: 6, height: 3), darkGold)

        // Base
        fill(CGRect(x: 24, y: 49, width: 18, height: 3), darkGold)

        // Shine highlight on cup
        fill(CGRect(x: 23, y: 35, width: 3, height: 6), shine)
    }

    // MARK: - Accessory Drawing

    private func drawNightcap(fill: (CGRect, Color) -> Void) {
        let white = Color.white
        let stripe = Color(red: 0.35, green: 0.5, blue: 1.0)        // blue stripe

        // Brim across the full head (sits above the body, no overlap)
        fill(CGRect(x: 6, y: -3, width: 54, height: 3), white)
        // Cap body — gradual taper, drifts to the right
        fill(CGRect(x: 16, y: -6, width: 42, height: 3), stripe)
        fill(CGRect(x: 21, y: -9, width: 36, height: 3), white)
        fill(CGRect(x: 26, y: -12, width: 30, height: 3), stripe)
        fill(CGRect(x: 31, y: -15, width: 24, height: 3), white)
        fill(CGRect(x: 36, y: -18, width: 18, height: 3), stripe)
        fill(CGRect(x: 41, y: -21, width: 12, height: 3), white)
        // Pompom at drooping tip
        fill(CGRect(x: 48, y: -24, width: 5, height: 5), white)
    }

    private func drawSunglasses(fill: (CGRect, Color) -> Void, eyeShift s: CGFloat) {
        let lens = Color(red: 0.08, green: 0.08, blue: 0.12)  // very dark lens
        let frame = Color(white: 0.4)                           // gray frame

        // Left lens
        fill(CGRect(x: 8 + s, y: 11, width: 16, height: 10), lens)
        // Right lens
        fill(CGRect(x: 42 + s, y: 11, width: 16, height: 10), lens)
        // Bridge connecting lenses
        fill(CGRect(x: 24 + s, y: 13, width: 18, height: 4), frame)
        // Frame top edge
        fill(CGRect(x: 8 + s, y: 10, width: 16, height: 2), frame)
        fill(CGRect(x: 42 + s, y: 10, width: 16, height: 2), frame)
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

// MARK: - Preview

#Preview("Crab Moods") {
    let moods: [(CrabMood, String, Color)] = [
        (.normal, "Normal", Color(red: 0.85, green: 0.47, blue: 0.34)),
        (.question, "Question", TerminalColors.amber),
        (.alert, "Alert", TerminalColors.amber),
        (.happy, "Stars", Color(red: 0.85, green: 0.47, blue: 0.34)),
        (.wideEyes, "Wide Eyes", Color.red.opacity(0.7)),
        (.sleeping, "Sleeping", Color(red: 0.85, green: 0.47, blue: 0.34)),
        (.sweatDrop, "Sweat", TerminalColors.cyan),
    ]

    VStack(spacing: 24) {
        HStack(spacing: 32) {
            ForEach(Array(moods.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 8) {
                    ClaudeCrabIcon(size: 48, color: item.2, mood: item.0)
                    Text(item.1).font(.caption).foregroundColor(.white)
                }
            }
        }
        Divider()
        HStack(spacing: 20) {
            ForEach(Array(moods.enumerated()), id: \.offset) { _, item in
                ClaudeCrabIcon(size: 16, color: item.2, mood: item.0)
            }
        }
        Divider()
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                ClaudeCrabIcon(size: 48, color: .orange, eyeShift: -3)
                Text("Look Left").font(.caption).foregroundColor(.white)
            }
            VStack(spacing: 4) {
                ClaudeCrabIcon(size: 48, color: .orange, eyeShift: 0)
                Text("Center").font(.caption).foregroundColor(.white)
            }
            VStack(spacing: 4) {
                ClaudeCrabIcon(size: 48, color: .orange, eyeShift: 3)
                Text("Look Right").font(.caption).foregroundColor(.white)
            }
        }
        Divider()
        // Tool icons while processing
        HStack(spacing: 24) {
            let tools: [(String?, String)] = [
                (nil, "Book"),
                ("Edit", "Pencil"),
                ("WebFetch", "Globe"),
            ]
            ForEach(Array(tools.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    ClaudeCrabIcon(size: 48, color: Color(red: 0.85, green: 0.47, blue: 0.34), animateLegs: true, currentTool: item.0)
                    Text(item.1).font(.caption).foregroundColor(.white)
                }
            }
            VStack(spacing: 4) {
                ClaudeCrabIcon(size: 48, color: Color(red: 0.85, green: 0.47, blue: 0.34), mood: .happy, showTrophy: true)
                Text("Trophy").font(.caption).foregroundColor(.white)
            }
        }
        Divider()
        // Time accessories
        HStack(spacing: 32) {
            VStack(spacing: 4) {
                ClaudeCrabIcon(size: 48, color: Color(red: 0.85, green: 0.47, blue: 0.34), timeAccessory: .nightcap)
                Text("Nightcap").font(.caption).foregroundColor(.white)
            }
            VStack(spacing: 4) {
                ClaudeCrabIcon(size: 48, color: Color(red: 0.85, green: 0.47, blue: 0.34), timeAccessory: .sunglasses)
                Text("Sunglasses").font(.caption).foregroundColor(.white)
            }
        }
    }
    .padding(40)
    .background(Color.black)
}

