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
    /// X offset of this mascot from notch center (used for facing direction)
    var xOffset: CGFloat = 0

    @State private var shakeOffset: CGFloat = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var pulseOpacity: Double = 1.0
    @State private var fadeOpacity: Double = 1.0
    @State private var isSleeping: Bool = false
    @State private var sleepTask: Task<Void, Never>?
    // Entry animation
    @State private var entryOffset: CGFloat = -15
    @State private var entryOpacity: Double = 0
    // Exit wave animation
    @State private var waveOffset: CGFloat = 0
    // Happy particle explosion
    @State private var showParticles: Bool = false
    // Brief wide-eyes flash on interrupt/error
    @State private var isStartled: Bool = false
    // 1-in-10 chance this crab wears sunglasses during the day
    @State private var wearsGlasses: Bool = Int.random(in: 0..<10) == 0
    // Notification badge for stale approvals
    @State private var showNotificationBadge: Bool = false
    @State private var badgePulse: Bool = false
    @State private var approvalTimerTask: Task<Void, Never>?

    private let mascotSize: CGFloat = 16
    private let sleepDelay: TimeInterval = 10
    private let badgeDelay: TimeInterval = 15

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

    private var crabMood: CrabMood {
        if isStartled { return .wideEyes }
        if isSleeping { return .sleeping }
        switch session.phase {
        case .waitingForApproval:
            // "?" face for AskUserQuestion, "!" face for tool permissions
            return session.pendingToolName == "AskUserQuestion" ? .question : .alert
        case .waitingForInput: return .happy
        case .compacting: return .sweatDrop
        case .ended: return .happy
        default: return .normal
        }
    }

    /// Eye shift based on mascot position — look toward center
    private var eyeShift: CGFloat {
        if xOffset < -5 { return 3 }   // left of center → look right
        if xOffset > 5 { return -3 }   // right of center → look left
        return 0                         // near center → look forward
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

    /// Most recently started in-progress tool, or last completed tool
    private var currentToolName: String? {
        let inProgress = session.toolTracker.inProgress.values
        if let latest = inProgress.max(by: { $0.startTime < $1.startTime }) {
            return latest.name
        }
        return session.conversationInfo.lastToolName
    }

    /// Time-of-day accessory based on current hour (sunglasses have 1-in-5 chance)
    private var timeAccessory: CrabAccessory {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 6 { return .nightcap }
        if hour >= 10 && hour < 16 && wearsGlasses { return .sunglasses }
        return .none
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

    static func tooltipText(for session: SessionState) -> String {
        let name = session.projectName
        let status: String
        switch session.phase {
        case .processing:
            let inProgress = session.toolTracker.inProgress.values
            if let latest = inProgress.max(by: { $0.startTime < $1.startTime }) {
                status = "Running \(latest.name)..."
            } else if let last = session.conversationInfo.lastToolName {
                status = "Running \(last)..."
            } else {
                status = "Working..."
            }
        case .waitingForApproval: status = "Needs approval"
        case .waitingForInput: status = "Waiting for input"
        case .idle: status = "Idle"
        case .compacting: status = "Compacting..."
        case .ended: status = "Finished"
        }
        return "\(name) — \(status)"
    }

    private var tooltipText: String {
        let name = session.projectName
        let status: String
        switch session.phase {
        case .processing:
            if let tool = currentToolName {
                status = "Running \(tool)..."
            } else {
                status = "Working..."
            }
        case .waitingForApproval: status = "Needs approval"
        case .waitingForInput: status = "Waiting for input"
        case .idle: status = isSleeping ? "Sleeping" : "Idle"
        case .compacting: status = "Compacting..."
        case .ended: status = "Finished"
        }
        return "\(name) — \(status)"
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // "zzz" floating up when sleeping
            if isSleeping {
                zzzOverlay
                    .offset(x: 8, y: -10)
            }

            // Happy particle explosion
            if showParticles {
                ParticleExplosionView()
            }

            ClaudeCrabIcon(size: mascotSize, color: crabColor, animateLegs: animateLegs, mood: crabMood, eyeShift: eyeShift, currentTool: currentToolName, timeAccessory: timeAccessory)
                .opacity(mascotOpacity)
                .shadow(color: glowColor?.opacity(0.6) ?? .clear, radius: 6)

            // Notification badge for stale approvals
            if showNotificationBadge {
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
                    .shadow(color: .red.opacity(badgePulse ? 0.8 : 0.3), radius: badgePulse ? 4 : 1)
                    .scaleEffect(badgePulse ? 1.2 : 1.0)
                    .offset(x: 8, y: -2)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: badgePulse)
            }
        }
        .offset(x: shakeOffset + waveOffset, y: bounceOffset + entryOffset)
        .opacity(entryOpacity)
        .onChange(of: session.phase) { oldPhase, newPhase in
            handlePhaseChange(from: oldPhase, to: newPhase)
        }
        .onAppear {
            // Entry animation — bounce in from above
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                entryOffset = 0
                entryOpacity = 1
            }
            startAnimationsForCurrentPhase()
            startSleepTimerIfNeeded()
            startBadgeTimerIfNeeded()
        }
        .onDisappear {
            sleepTask?.cancel()
            approvalTimerTask?.cancel()
        }
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
        // Clear badge on any transition away from approval
        if !newPhase.isWaitingForApproval {
            cancelBadgeTimer()
        }

        switch newPhase {
        case .waitingForApproval:
            wakeUp()
            startShakeAnimation()
            startBadgeTimer()

        case .waitingForInput:
            wakeUp()
            startBounceAnimation()
            triggerParticles()

        case .compacting:
            wakeUp()
            startPulseAnimation()

        case .ended:
            wakeUp()
            triggerParticles()
            startWaveThenFade()

        case .processing:
            wakeUp()
            resetAnimations()

        case .idle:
            resetAnimations()
            // Flash wide eyes if interrupted mid-processing
            if oldPhase == .processing {
                triggerStartle()
            }
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

    /// Wave side-to-side then fade out (exit animation)
    private func startWaveThenFade() {
        // Wave: 3 quick oscillations
        withAnimation(.easeInOut(duration: 0.12).repeatCount(5, autoreverses: true)) {
            waveOffset = 4
        }
        // After wave finishes, reset and fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            waveOffset = 0
            withAnimation(.easeOut(duration: 1.4)) {
                fadeOpacity = 0
            }
        }
    }

    private func resetAnimations() {
        shakeOffset = 0
        bounceOffset = 0
        waveOffset = 0
        pulseOpacity = 1.0
    }

    private func triggerStartle() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isStartled = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                isStartled = false
            }
        }
    }

    private func triggerParticles() {
        showParticles = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showParticles = false
        }
    }

    // MARK: - Notification Badge

    /// Start badge timer if currently in approval phase
    private func startBadgeTimerIfNeeded() {
        guard session.phase.isWaitingForApproval else { return }
        // Check how long we've already been waiting
        if let context = session.activePermission {
            let elapsed = Date().timeIntervalSince(context.receivedAt)
            if elapsed >= badgeDelay {
                showBadge()
            } else {
                startBadgeTimer(delay: badgeDelay - elapsed)
            }
        } else {
            startBadgeTimer()
        }
    }

    private func startBadgeTimer(delay: TimeInterval? = nil) {
        approvalTimerTask?.cancel()
        approvalTimerTask = Task {
            try? await Task.sleep(for: .seconds(delay ?? badgeDelay))
            guard !Task.isCancelled, session.phase.isWaitingForApproval else { return }
            showBadge()
        }
    }

    private func showBadge() {
        withAnimation(.easeIn(duration: 0.3)) {
            showNotificationBadge = true
        }
        badgePulse = true
    }

    private func cancelBadgeTimer() {
        approvalTimerTask?.cancel()
        approvalTimerTask = nil
        if showNotificationBadge {
            withAnimation(.easeOut(duration: 0.2)) {
                showNotificationBadge = false
            }
            badgePulse = false
        }
    }
}

// MARK: - Particle Explosion

/// Tiny pixel sparkles that burst outward from the mascot center
struct ParticleExplosionView: View {
    @State private var animate = false

    private let particles: [(angle: Double, distance: CGFloat, size: CGFloat, color: Color)] = {
        var result: [(Double, CGFloat, CGFloat, Color)] = []
        let colors: [Color] = [
            TerminalColors.green,
            TerminalColors.green.opacity(0.7),
            .white,
            .white.opacity(0.8),
            TerminalColors.amber,
        ]
        for i in 0..<8 {
            let angle = Double(i) * 45.0 + Double.random(in: -15...15)
            let dist = CGFloat.random(in: 10...18)
            let sz = CGFloat.random(in: 1.5...3)
            result.append((angle, dist, sz, colors[i % colors.count]))
        }
        return result
    }()

    var body: some View {
        ZStack {
            ForEach(0..<particles.count, id: \.self) { i in
                let p = particles[i]
                let rad = p.angle * .pi / 180
                let dx = animate ? cos(rad) * p.distance : 0
                let dy = animate ? sin(rad) * p.distance : 0

                Rectangle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .offset(x: dx, y: dy)
                    .opacity(animate ? 0 : 1)
                    .scaleEffect(animate ? 0.3 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animate = true
            }
        }
    }
}
