//
//  MascotViewModel.swift
//  ClaudeIsland
//
//  State coordinator for floating mascot characters in the notch
//

import AppKit
import Combine
import SwiftUI

@MainActor
class MascotViewModel: ObservableObject {
    // MARK: - Published State

    /// Which mascot's permission bubble is currently visible (nil = none)
    @Published var activeBubbleSessionId: String?

    /// Whether the bubble is expanded to show full details
    @Published var isBubbleExpanded: Bool = false

    /// Hovered mascot tooltip (text + x offset from center)
    @Published var hoverTooltip: (text: String, xOffset: CGFloat)?

    /// Current session count — updated by canvas view, used for dynamic bar width in hit testing
    var sessionCount: Int = 0

    // MARK: - Dependencies

    let geometry: NotchGeometry
    let hasPhysicalNotch: Bool

    // MARK: - Private

    private var bubbleDismissTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let events = EventMonitors.shared

    /// Global-only monitor for dismissing bubble on clicks outside our window
    nonisolated(unsafe) private var globalClickMonitor: Any?

    /// Callback for when global click hits the notch area — passes click screen location
    var onNotchClick: ((CGPoint) -> Void)?

    /// Callback for double-click on a mascot — passes the session
    var onNotchDoubleClick: ((CGPoint) -> Void)?

    /// Callback for right-click on notch (set by canvas view)
    var onNotchRightClick: ((CGPoint) -> Void)?

    /// Callback to resolve a screen location to a tooltip string + mascot x offset
    var onResolveHover: ((CGPoint) -> (text: String, xOffset: CGFloat)?)?

    /// Double-click detection state
    private var lastClickTime: Date?
    private var lastClickLocation: CGPoint?

    /// Pending tooltip (waiting for 2s hover delay)
    private var hoverDelayTask: Task<Void, Never>?
    private var pendingHoverText: String?

    // MARK: - Initialization

    init(geometry: NotchGeometry, hasPhysicalNotch: Bool) {
        self.geometry = geometry
        self.hasPhysicalNotch = hasPhysicalNotch
        setupEventHandlers()
        setupGlobalClickMonitor()
    }

    deinit {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Global Event Handling

    private func setupEventHandlers() {
        // Notch click detection via shared monitors (works with both global+local).
        // Only handles notch area clicks. Does NOT dismiss bubble — that's handled by
        // sendEvent (for in-window clicks) and globalClickMonitor (for other-app clicks).
        events.mouseDown
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMouseDown()
            }
            .store(in: &cancellables)

        // Right-click detection for context menu
        events.rightMouseDown
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleRightMouseDown()
            }
            .store(in: &cancellables)

        // Hover detection for custom tooltips
        events.mouseLocation
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] location in
                self?.handleMouseMove(location)
            }
            .store(in: &cancellables)
    }

    /// Separate global-only monitor for dismissing bubble when user clicks on another app.
    /// Global monitors only fire for events going to OTHER applications, not our window.
    /// This prevents the race condition where the local monitor would dismiss the bubble
    /// before sendEvent could deliver the click to SwiftUI buttons.
    private func setupGlobalClickMonitor() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.activeBubbleSessionId != nil {
                    self.dismissBubble()
                }
            }
        }
    }

    private var currentBarWidth: CGFloat {
        mascotBarWidth(sessionCount: sessionCount)
    }

    private func handleMouseDown() {
        let location = NSEvent.mouseLocation
        if geometry.isPointInNotch(location, barWidth: currentBarWidth) {
            let now = Date()
            // Detect double-click: two clicks within 0.35s and 20px
            if let lastTime = lastClickTime, let lastLoc = lastClickLocation,
               now.timeIntervalSince(lastTime) < 0.35,
               abs(location.x - lastLoc.x) < 20, abs(location.y - lastLoc.y) < 20 {
                lastClickTime = nil
                lastClickLocation = nil
                onNotchDoubleClick?(location)
            } else {
                lastClickTime = now
                lastClickLocation = location
                onNotchClick?(location)
            }
        }
    }

    private func handleRightMouseDown() {
        let location = NSEvent.mouseLocation
        if geometry.isPointInNotch(location, barWidth: currentBarWidth) {
            onNotchRightClick?(location)
        }
    }

    private func handleMouseMove(_ location: CGPoint) {
        if geometry.isPointInNotch(location, barWidth: currentBarWidth),
           let result = onResolveHover?(location) {
            if hoverTooltip != nil {
                // Already showing — update in place
                if hoverTooltip?.text != result.text {
                    hoverTooltip = result
                }
            } else if pendingHoverText != result.text {
                // Start 2s delay for new hover target
                pendingHoverText = result.text
                hoverDelayTask?.cancel()
                hoverDelayTask = Task { [weak self, result] in
                    try? await Task.sleep(for: .seconds(2))
                    guard let self, !Task.isCancelled else { return }
                    self.hoverTooltip = result
                }
            }
        } else {
            // Mouse left notch — cancel pending and hide immediately
            hoverDelayTask?.cancel()
            hoverDelayTask = nil
            pendingHoverText = nil
            if hoverTooltip != nil {
                hoverTooltip = nil
            }
        }
    }

    // MARK: - Mascot Positioning

    /// Compute x-offset from bar center for a mascot at given index.
    /// On physical notch screens, mascots split to left/right ears avoiding the camera housing.
    /// On virtual notch screens, mascots distribute evenly across the bar center.
    func mascotXOffset(index: Int, total: Int) -> CGFloat {
        if hasPhysicalNotch {
            return physicalNotchMascotOffset(index: index, total: total)
        }
        guard total > 1 else { return 0 }
        let spacing: CGFloat = 28
        let center = CGFloat(total - 1) / 2.0
        return (CGFloat(index) - center) * spacing
    }

    /// On physical notch screens, place mascots in the ear areas flanking the camera housing.
    /// The bar is wider than the physical notch — mascots go into the extended ear zones.
    private func physicalNotchMascotOffset(index: Int, total: Int) -> CGFloat {
        let physicalNotchWidth = geometry.deviceNotchRect.width
        // Half the physical notch width + padding — mascots start outside the camera area
        let earInset = physicalNotchWidth / 2 + 14

        if total == 1 {
            // Single mascot: place in the left ear
            return -earInset
        }

        // Split mascots between left and right ears
        let leftCount = (total + 1) / 2  // more go left if odd
        let rightCount = total - leftCount
        let spacing: CGFloat = 24

        if index < leftCount {
            // Left ear: spread leftward from the left edge of the notch
            let posInGroup = CGFloat(leftCount - 1 - index)
            return -earInset - posInGroup * spacing
        } else {
            // Right ear: spread rightward from the right edge of the notch
            let posInGroup = CGFloat(index - leftCount)
            return earInset + posInGroup * spacing
        }
    }

    /// The display width needed for the mascot bar.
    /// On virtual notch screens, grows to fit all mascots.
    /// On physical notch screens, extends into the ear areas.
    func mascotBarWidth(sessionCount: Int) -> CGFloat {
        if hasPhysicalNotch {
            let screenWidth = geometry.screenRect.width
            let physicalNotchWidth = geometry.deviceNotchRect.width
            let earWidth = (screenWidth - physicalNotchWidth) / 2
            let baseWidth = physicalNotchWidth + earWidth * 2 * 0.6
            // Grow if many sessions need more space
            let neededWidth = physicalNotchWidth + CGFloat(sessionCount) * 24 + 40
            return max(baseWidth, neededWidth)
        }
        let baseWidth = geometry.deviceNotchRect.width
        guard sessionCount > 1 else { return baseWidth }
        let spacing: CGFloat = 28
        let neededWidth = CGFloat(sessionCount) * spacing + 40
        return max(baseWidth, neededWidth)
    }

    // MARK: - Bubble Management

    /// Show the permission bubble for a specific session, auto-dismiss after 5 seconds
    func showBubble(for sessionId: String) {
        activeBubbleSessionId = sessionId
        isBubbleExpanded = false
        scheduleBubbleDismiss()
    }

    /// Dismiss the active bubble
    func dismissBubble() {
        bubbleDismissTask?.cancel()
        bubbleDismissTask = nil
        withAnimation(.easeOut(duration: 0.15)) {
            activeBubbleSessionId = nil
            isBubbleExpanded = false
        }
    }

    /// Cancel auto-dismiss (user is interacting)
    func cancelBubbleDismiss() {
        bubbleDismissTask?.cancel()
        bubbleDismissTask = nil
    }

    // MARK: - Private

    private func scheduleBubbleDismiss() {
        bubbleDismissTask?.cancel()
        bubbleDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self = self, !Task.isCancelled else { return }
            self.dismissBubble()
        }
    }
}
