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
    @State private var isSleeping: Bool = false
    @State private var sleepTask: Task<Void, Never>?
    @State private var zzzPhase: Int = 0

    private let mascotSize: CGFloat = 16
    private let sleepDelay: TimeInterval = 10

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
        ZStack(alignment: .top) {
            // "?" bubble above mascot when waiting for approval
            if session.phase.isWaitingForApproval {
                questionBubble
                    .offset(y: -14)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }

            // "zzz" floating up when sleeping
            if isSleeping {
                zzzOverlay
                    .offset(x: 8, y: -10)
            }

            ClaudeCrabIcon(size: mascotSize, color: crabColor, animateLegs: animateLegs, sleeping: isSleeping)
                .opacity(mascotOpacity)
                .shadow(color: glowColor?.opacity(0.6) ?? .clear, radius: 6)
        }
        .offset(x: shakeOffset, y: bounceOffset)
        .onChange(of: session.phase) { oldPhase, newPhase in
            handlePhaseChange(from: oldPhase, to: newPhase)
        }
        .onAppear {
            startAnimationsForCurrentPhase()
            startSleepTimerIfNeeded()
        }
        .onDisappear {
            sleepTask?.cancel()
        }
    }

    // MARK: - Question Bubble

    private var questionBubble: some View {
        Text("?")
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundColor(.black)
            .frame(width: 12, height: 12)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(TerminalColors.amber)
            )
    }

    // MARK: - Zzz Overlay

    private var zzzOverlay: some View {
        TimelineView(.animation(minimumInterval: 0.6)) { timeline in
            let phase = Int(timeline.date.timeIntervalSinceReferenceDate / 0.6) % 3
            ZStack {
                Text("z")
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .offset(x: -2, y: phase >= 1 ? -2 : 0)
                    .opacity(phase >= 1 ? 1 : 0)
                Text("z")
                    .font(.system(size: 5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .offset(x: 2, y: phase >= 2 ? -7 : -5)
                    .opacity(phase >= 2 ? 1 : 0)
                Text("z")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .offset(x: 0, y: 2)
            }
            .animation(.easeInOut(duration: 0.5), value: phase)
        }
    }

    // MARK: - Sleep Timer

    private func startSleepTimerIfNeeded() {
        if session.phase == .idle {
            scheduleSleep()
        }
    }

    private func scheduleSleep() {
        sleepTask?.cancel()
        sleepTask = Task {
            try? await Task.sleep(for: .seconds(sleepDelay))
            guard !Task.isCancelled, session.phase == .idle else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                isSleeping = true
            }
        }
    }

    private func wakeUp() {
        sleepTask?.cancel()
        sleepTask = nil
        if isSleeping {
            withAnimation(.easeInOut(duration: 0.3)) {
                isSleeping = false
            }
        }
    }

    // MARK: - Phase Animations

    private func handlePhaseChange(from oldPhase: SessionPhase, to newPhase: SessionPhase) {
        switch newPhase {
        case .waitingForApproval:
            wakeUp()
            startShakeAnimation()

        case .waitingForInput:
            wakeUp()
            startBounceAnimation()

        case .compacting:
            wakeUp()
            startPulseAnimation()

        case .ended:
            wakeUp()
            startFadeOutAnimation()

        case .processing:
            wakeUp()
            resetAnimations()

        case .idle:
            resetAnimations()
            scheduleSleep()
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
