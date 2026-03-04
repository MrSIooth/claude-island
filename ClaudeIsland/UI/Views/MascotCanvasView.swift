//
//  MascotCanvasView.swift
//  ClaudeIsland
//
//  Root SwiftUI view: mascots inside the notch, permission bubbles below.
//

import AppKit
import ServiceManagement
import SwiftUI

struct MascotCanvasView: View {
    @ObservedObject var viewModel: MascotViewModel
    @StateObject private var sessionMonitor = ClaudeSessionMonitor()

    @State private var previousWaitingForInputIds: Set<String> = []
    @State private var endedSessionTimers: [String: Date] = [:]
    /// Tracks approval session IDs we've already auto-shown a bubble for.
    /// Prevents re-opening after user dismisses. Cleared when session leaves waitingForApproval.
    @State private var seenApprovalSessionIds: Set<String> = []
    /// 1-in-10 chance the idle crab wears sunglasses during the day
    @State private var idleCrabWearsGlasses: Bool = Int.random(in: 0..<10) == 0

    private var visibleSessions: [SessionState] {
        let now = Date()
        return sessionMonitor.instances.filter { session in
            if session.phase == .ended {
                if let endedAt = endedSessionTimers[session.sessionId] {
                    return now.timeIntervalSince(endedAt) < 2.0
                }
                return false
            }
            return true
        }
    }

    /// The notch dimensions from geometry
    private var notchRect: CGRect {
        viewModel.geometry.deviceNotchRect
    }

    /// Time-of-day accessory for idle crabs (sunglasses have 1-in-5 chance)
    private var idleTimeAccessory: CrabAccessory {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 20 || hour < 8 { return .nightcap }
        if hour >= 8 && hour < 20 && idleCrabWearsGlasses { return .sunglasses }
        return .none
    }

    var body: some View {
        VStack(spacing: 0) {
            // Notch bar with mascots inside
            notchBar
                .frame(height: max(32, notchRect.height))

            // Hover tooltip
            if let tooltip = viewModel.hoverTooltip, viewModel.activeBubbleSessionId == nil {
                Text(tooltip.text)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(white: 0.15).opacity(0.95))
                    .cornerRadius(6)
                    .offset(x: tooltip.xOffset)
                    .transition(.opacity)
                    .padding(.top, 2)
            }

            // Permission bubble below the notch (if active)
            if let activeSessionId = viewModel.activeBubbleSessionId,
               let session = visibleSessions.first(where: { $0.sessionId == activeSessionId }),
               session.phase.isWaitingForApproval {
                let mascotOffset = mascotXOffsetForSession(activeSessionId)
                let bubbleOffset = bubbleXOffset(for: mascotOffset)
                let pointerOffset = mascotOffset - bubbleOffset
                PermissionBubbleView(
                    session: session,
                    viewModel: viewModel,
                    pointerOffsetX: pointerOffset,
                    onApprove: {
                        sessionMonitor.approvePermission(sessionId: session.sessionId)
                        viewModel.dismissBubble()
                    },
                    onDeny: {
                        sessionMonitor.denyPermission(sessionId: session.sessionId, reason: nil)
                        viewModel.dismissBubble()
                    },
                    onApproveWithSelection: { selectedLabel in
                        sessionMonitor.approvePermission(sessionId: session.sessionId)
                        viewModel.dismissBubble()
                        writeSelectionToTTY(session: session, selection: selectedLabel)
                    }
                )
                .offset(x: bubbleOffset)
                .transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .onAppear {
            sessionMonitor.startMonitoring()
            viewModel.onNotchClick = { [weak viewModel] clickLocation in
                guard let viewModel = viewModel else { return }
                let sessions = sessionMonitor.instances.filter { $0.phase != .ended }
                let clickedSession = sessionForClickLocation(clickLocation, sessions: sessions)

                if let clicked = clickedSession {
                    if viewModel.activeBubbleSessionId == clicked.sessionId {
                        // Clicked the same mascot — toggle off
                        viewModel.dismissBubble()
                    } else {
                        // Clicked a different mascot (or no bubble open) — switch directly
                        withAnimation {
                            viewModel.showBubble(for: clicked.sessionId)
                        }
                    }
                } else if viewModel.activeBubbleSessionId != nil {
                    // Clicked notch area but no specific mascot — dismiss
                    viewModel.dismissBubble()
                } else if let session = sessions.first(where: { $0.phase.isWaitingForApproval }) {
                    // No bubble, no specific mascot — show first waiting
                    withAnimation {
                        viewModel.showBubble(for: session.sessionId)
                    }
                }
            }
            viewModel.onNotchDoubleClick = { clickLocation in
                let sessions = sessionMonitor.instances.filter { $0.phase != .ended }
                if let clicked = sessionForClickLocation(clickLocation, sessions: sessions) {
                    focusTerminal(for: clicked)
                }
            }
            viewModel.onNotchRightClick = { [weak viewModel] screenLocation in
                guard viewModel != nil else { return }
                showContextMenu(at: screenLocation)
            }
            viewModel.onResolveHover = { [weak viewModel] location in
                guard let viewModel = viewModel else { return nil }
                let sessions = sessionMonitor.instances.filter { $0.phase != .ended }
                guard !sessions.isEmpty else { return nil }
                guard let session = sessionForClickLocation(location, sessions: sessions) else { return nil }
                let text = MascotView.tooltipText(for: session)
                guard let index = sessions.firstIndex(where: { $0.sessionId == session.sessionId }) else { return nil }
                let xOffset = viewModel.mascotXOffset(index: index, total: sessions.count)
                return (text: text, xOffset: xOffset)
            }
        }
        .onChange(of: sessionMonitor.instances) { _, instances in
            handleInstancesChange(instances)
        }
    }

    // MARK: - Notch Bar

    @ViewBuilder
    private var notchBar: some View {
        let sessions = visibleSessions
        let barWidth = viewModel.mascotBarWidth(sessionCount: sessions.count)
        let barHeight = max(32, notchRect.height)

        ZStack {
            if sessions.isEmpty {
                if viewModel.hasPhysicalNotch {
                    // On physical notch, show idle crab in the left ear
                    ClaudeCrabIcon(size: 14, timeAccessory: idleTimeAccessory)
                        .offset(x: -(notchRect.width / 2 + 14))
                } else {
                    ClaudeCrabIcon(size: 14, timeAccessory: idleTimeAccessory)
                }
            } else {
                ForEach(Array(sessions.enumerated()), id: \.element.stableId) { index, session in
                    let mascotXOffset = viewModel.mascotXOffset(index: index, total: sessions.count)

                    MascotView(
                        session: session,
                        viewModel: viewModel,
                        sessionMonitor: sessionMonitor,
                        xOffset: mascotXOffset
                    )
                    .offset(x: mascotXOffset)
                }
            }
        }
        .frame(width: barWidth, height: barHeight)
        .background(notchBarBackground)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sessions.count)
    }

    @ViewBuilder
    private var notchBarBackground: some View {
        if viewModel.hasPhysicalNotch {
            // On physical notch screens, only draw black behind the physical notch area (center).
            // The ear areas where mascots sit are transparent so the menu bar shows through.
            Color.clear
        } else {
            // On external displays, draw the full virtual notch background
            Color.black
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 14,
                        bottomTrailingRadius: 14,
                        topTrailingRadius: 0
                    )
                )
        }
    }

    // MARK: - Instance Change Handling

    private func handleInstancesChange(_ instances: [SessionState]) {
        viewModel.sessionCount = visibleSessions.count
        trackEndedSessions(instances)
        handleWaitingForInputSound(instances)
        autoShowBubblesForApproval(instances)
    }

    private func trackEndedSessions(_ instances: [SessionState]) {
        let now = Date()
        for session in instances where session.phase == .ended {
            if endedSessionTimers[session.sessionId] == nil {
                endedSessionTimers[session.sessionId] = now
            }
        }
        let staleIds = endedSessionTimers.keys.filter { id in
            guard let endedAt = endedSessionTimers[id] else { return true }
            return now.timeIntervalSince(endedAt) > 3.0
        }
        for id in staleIds {
            endedSessionTimers.removeValue(forKey: id)
        }
    }

    private func handleWaitingForInputSound(_ instances: [SessionState]) {
        let waitingForInputSessions = instances.filter { $0.phase == .waitingForInput }
        let currentIds = Set(waitingForInputSessions.map { $0.stableId })
        let newWaitingIds = currentIds.subtracting(previousWaitingForInputIds)

        if !newWaitingIds.isEmpty && AppSettings.soundEnabled {
            NSSound(named: "Blow")?.play()
        }
        previousWaitingForInputIds = currentIds
    }

    private func autoShowBubblesForApproval(_ instances: [SessionState]) {
        let currentApprovalIds = Set(
            instances.filter { $0.phase.isWaitingForApproval }.map { $0.sessionId }
        )

        // Remove sessions that are no longer waiting — so future approvals can auto-show
        seenApprovalSessionIds = seenApprovalSessionIds.intersection(currentApprovalIds)

        // Only auto-show for NEW approval sessions we haven't shown yet
        let newApprovalIds = currentApprovalIds.subtracting(seenApprovalSessionIds)
        guard !newApprovalIds.isEmpty else { return }

        // Mark all new ones as seen regardless of whether we show them
        seenApprovalSessionIds.formUnion(newApprovalIds)

        // Play notification sound for new approval requests
        if AppSettings.soundEnabled {
            NSSound(named: "Pop")?.play()
        }

        // Show the first new one if no bubble is active
        if viewModel.activeBubbleSessionId == nil, let newId = newApprovalIds.first {
            withAnimation {
                viewModel.showBubble(for: newId)
            }
        }
    }

    // MARK: - Mascot Offset Lookup

    /// Get the x-offset of the mascot for a given session ID (relative to notch center)
    private func mascotXOffsetForSession(_ sessionId: String) -> CGFloat {
        let sessions = visibleSessions
        guard let index = sessions.firstIndex(where: { $0.sessionId == sessionId }) else { return 0 }
        return viewModel.mascotXOffset(index: index, total: sessions.count)
    }

    /// Compute bubble x-offset that follows the mascot but stays on screen.
    /// The bubble is 350px wide and centered on screen by default, so we clamp
    /// the offset so neither edge goes past the screen bounds.
    private func bubbleXOffset(for mascotOffset: CGFloat) -> CGFloat {
        let bubbleWidth: CGFloat = 380
        let screenWidth = viewModel.geometry.screenRect.width
        // Max offset before bubble edge hits screen edge (with some padding)
        let maxOffset = (screenWidth - bubbleWidth) / 2 - 16
        return min(max(mascotOffset, -maxOffset), maxOffset)
    }

    // MARK: - Mascot Click Detection

    /// Determine which session's mascot was clicked based on screen location
    private func sessionForClickLocation(_ screenLocation: CGPoint, sessions: [SessionState]) -> SessionState? {
        guard !sessions.isEmpty else { return nil }

        let barWidth = viewModel.mascotBarWidth(sessionCount: sessions.count)
        let notchCenterX = viewModel.geometry.screenRect.midX
        let mascotHitWidth: CGFloat = 28 // generous hit area per mascot

        // For a single session, the mascot is centered
        if sessions.count == 1 {
            return sessions[0]
        }

        // For multiple sessions, check each mascot's position
        let clickX = screenLocation.x
        var bestMatch: (session: SessionState, distance: CGFloat)?

        for (index, session) in sessions.enumerated() {
            let xOffset = viewModel.mascotXOffset(index: index, total: sessions.count)
            let mascotCenterX = notchCenterX + xOffset

            let distance = abs(clickX - mascotCenterX)
            if distance <= mascotHitWidth {
                if bestMatch == nil || distance < bestMatch!.distance {
                    bestMatch = (session, distance)
                }
            }
        }

        return bestMatch?.session
    }

    // MARK: - TTY Selection Writing

    /// Write the selected option to the session's TTY after approving AskUserQuestion
    private func writeSelectionToTTY(session: SessionState, selection: String) {
        guard let tty = session.tty else { return }

        let ttyPath = tty.hasPrefix("/dev/") ? tty : "/dev/\(tty)"

        // Small delay to let Claude Code process the approval and show the question
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) {
            guard let fileHandle = FileHandle(forWritingAtPath: ttyPath) else { return }
            // Write the option label + Enter to the TTY
            if let data = "\(selection)\n".data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        }
    }

    // MARK: - Focus Terminal (Double-Click)

    /// Bring the terminal window for this session to the foreground
    private func focusTerminal(for session: SessionState) {
        guard let pid = session.pid else { return }

        // Walk up the process tree to find the terminal app (parent of Claude process)
        var parentPid = Int32(pid)
        for _ in 0..<5 {
            var info = proc_bsdinfo()
            let size = MemoryLayout<proc_bsdinfo>.size
            let result = proc_pidinfo(parentPid, PROC_PIDTBSDINFO, 0, &info, Int32(size))
            guard result > 0 else { break }
            let ppid = Int32(info.pbi_ppid)
            if ppid <= 1 { break }
            // Check if the parent is a GUI app we can activate
            if let app = NSRunningApplication(processIdentifier: ppid), app.activationPolicy == .regular {
                app.activate()
                return
            }
            parentPid = ppid
        }

        // Fallback: try to activate the immediate parent
        let ppid = getParentPid(of: Int32(pid))
        if ppid > 1, let app = NSRunningApplication(processIdentifier: ppid) {
            app.activate()
        }
    }

    private func getParentPid(of pid: Int32) -> Int32 {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size))
        return result > 0 ? Int32(info.pbi_ppid) : 0
    }

    // MARK: - Context Menu (Right-Click)

    private func showContextMenu(at screenLocation: CGPoint) {
        let menu = NSMenu()

        // Sound toggle
        let soundItem = NSMenuItem(title: "Sound", action: #selector(ContextMenuTarget.toggleSound), keyEquivalent: "")
        soundItem.target = ContextMenuTarget.shared
        if AppSettings.soundEnabled {
            soundItem.state = .on
        }
        menu.addItem(soundItem)

        // Screen submenu
        let screenMenu = NSMenu()
        let autoItem = NSMenuItem(title: "Automatic", action: #selector(ContextMenuTarget.autoScreenSelected), keyEquivalent: "")
        autoItem.target = ContextMenuTarget.shared
        if ScreenSelector.shared.selectionMode == .automatic {
            autoItem.state = .on
        }
        screenMenu.addItem(autoItem)
        for screen in ScreenSelector.shared.availableScreens {
            let item = NSMenuItem(title: screen.localizedName, action: #selector(ContextMenuTarget.screenSelected(_:)), keyEquivalent: "")
            item.target = ContextMenuTarget.shared
            item.representedObject = screen
            if ScreenSelector.shared.isSelected(screen) && ScreenSelector.shared.selectionMode == .specificScreen {
                item.state = .on
            }
            screenMenu.addItem(item)
        }
        let screenItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        screenItem.submenu = screenMenu
        menu.addItem(screenItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(ContextMenuTarget.toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = ContextMenuTarget.shared
        if SMAppService.mainApp.status == .enabled {
            loginItem.state = .on
        }
        menu.addItem(loginItem)

        // Hooks
        let hooksItem = NSMenuItem(title: "Hooks", action: #selector(ContextMenuTarget.toggleHooks), keyEquivalent: "")
        hooksItem.target = ContextMenuTarget.shared
        if HookInstaller.isInstalled() {
            hooksItem.state = .on
        }
        menu.addItem(hooksItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(ContextMenuTarget.quit), keyEquivalent: "q")
        quitItem.target = ContextMenuTarget.shared
        menu.addItem(quitItem)

        // Show at a position near the notch
        menu.popUp(positioning: nil, at: NSPoint(x: screenLocation.x, y: screenLocation.y), in: nil)
    }
}

// MARK: - NSMenu Action Target

import ServiceManagement

private class ContextMenuTarget: NSObject {
    static let shared = ContextMenuTarget()

    @objc func toggleSound() {
        AppSettings.soundEnabled.toggle()
    }

    @objc func autoScreenSelected() {
        ScreenSelector.shared.selectAutomatic()
        triggerWindowRecreation()
    }

    @objc func screenSelected(_ sender: NSMenuItem) {
        guard let screen = sender.representedObject as? NSScreen else { return }
        ScreenSelector.shared.selectScreen(screen)
        triggerWindowRecreation()
    }

    private func triggerWindowRecreation() {
        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }

    @objc func toggleHooks() {
        if HookInstaller.isInstalled() {
            HookInstaller.uninstall()
        } else {
            HookInstaller.installIfNeeded()
        }
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
