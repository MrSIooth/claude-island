//
//  MascotView.swift
//  ClaudeIsland
//
//  Per-mascot SwiftUI view with state-dependent visual effects.
//  Rendered inside the notch bar. Click handling is via global event monitors.
//

import SwiftUI

struct MascotView: View {
    let session: SessionState
    @ObservedObject var viewModel: MascotViewModel
    let sessionMonitor: ClaudeSessionMonitor

    @State private var shakeOffset: CGFloat = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var pulseOpacity: Double = 1.0
    @State private var fadeOpacity: Double = 1.0

    private let mascotSize: CGFloat = 16

    // MARK: - State-derived properties

    private var crabColor: Color {
        switch session.phase {
        case .processing:
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .waitingForApproval:
            return TerminalColors.amber
        case .waitingForInput:
            return TerminalColors.green
        case .idle:
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .compacting:
            return TerminalColors.cyan
        case .ended:
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        }
    }

    private var animateLegs: Bool {
        session.phase == .processing
    }

    private var glowColor: Color? {
        switch session.phase {
        case .waitingForApproval:
            return TerminalColors.amber
        case .waitingForInput:
            return TerminalColors.green
        default:
            return nil
        }
    }

    private var mascotOpacity: Double {
        switch session.phase {
        case .idle:
            return 0.5
        case .ended:
            return fadeOpacity
        case .compacting:
            return pulseOpacity
        default:
            return 1.0
        }
    }

    // MARK: - Body

    var body: some View {
        ClaudeCrabIcon(size: mascotSize, color: crabColor, animateLegs: animateLegs)
            .opacity(mascotOpacity)
            .shadow(color: glowColor?.opacity(0.6) ?? .clear, radius: 6)
            .offset(x: shakeOffset, y: bounceOffset)
            .onChange(of: session.phase) { oldPhase, newPhase in
                handlePhaseChange(from: oldPhase, to: newPhase)
            }
            .onAppear {
                startAnimationsForCurrentPhase()
            }
    }

    // MARK: - Phase Animations

    private func handlePhaseChange(from oldPhase: SessionPhase, to newPhase: SessionPhase) {
        switch newPhase {
        case .waitingForApproval:
            startShakeAnimation()
            // Bubble auto-show is handled by autoShowBubblesForApproval in MascotCanvasView
            // so it respects the "seen" tracking and doesn't re-open after user dismiss.

        case .waitingForInput:
            startBounceAnimation()

        case .compacting:
            startPulseAnimation()

        case .ended:
            startFadeOutAnimation()

        default:
            resetAnimations()
        }
    }

    private func startAnimationsForCurrentPhase() {
        switch session.phase {
        case .waitingForApproval:
            startShakeAnimation()
        case .waitingForInput:
            startBounceAnimation()
        case .compacting:
            startPulseAnimation()
        case .ended:
            fadeOpacity = 0
        default:
            break
        }
    }

    private func startShakeAnimation() {
        withAnimation(.easeInOut(duration: 0.1).repeatCount(5, autoreverses: true)) {
            shakeOffset = 3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shakeOffset = 0
        }
    }

    private func startBounceAnimation() {
        withAnimation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)) {
            bounceOffset = -4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            bounceOffset = 0
        }
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.5
        }
    }

    private func startFadeOutAnimation() {
        withAnimation(.easeOut(duration: 2.0)) {
            fadeOpacity = 0
        }
    }

    private func resetAnimations() {
        shakeOffset = 0
        bounceOffset = 0
        pulseOpacity = 1.0
    }
}
