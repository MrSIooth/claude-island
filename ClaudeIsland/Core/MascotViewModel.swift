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

    /// Callback for right-click on notch (set by canvas view)
    var onNotchRightClick: ((CGPoint) -> Void)?

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

    private func handleMouseDown() {
        let location = NSEvent.mouseLocation
        if geometry.isPointInNotch(location) {
            onNotchClick?(location)
        }
        // Don't dismiss bubble here — the local monitor also fires for clicks on
        // our own window (including bubble buttons). Dismiss is handled by:
        // 1. NotchPanel.sendEvent → onClickOutsideBubble (clicks in window, outside bubble)
        // 2. globalClickMonitor (clicks on other apps)
    }

    private func handleRightMouseDown() {
        let location = NSEvent.mouseLocation
        if geometry.isPointInNotch(location) {
            onNotchRightClick?(location)
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

    /// The display width needed for the mascot bar, accounting for ear zones on physical notch screens.
    var mascotBarWidth: CGFloat {
        if hasPhysicalNotch {
            // Extend well beyond the physical notch into both ear areas
            let screenWidth = geometry.screenRect.width
            let physicalNotchWidth = geometry.deviceNotchRect.width
            // Use the full menu bar width (ear to ear) — the area between the Apple menu and status icons
            // Each ear is (screenWidth - physicalNotchWidth) / 2, we take most of it
            let earWidth = (screenWidth - physicalNotchWidth) / 2
            return physicalNotchWidth + earWidth * 2 * 0.6
        }
        return geometry.deviceNotchRect.width
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
