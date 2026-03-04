//
//  NotchWindowController.swift
//  ClaudeIsland
//
//  Controls the mascot window positioning and lifecycle
//

import AppKit
import Combine
import SwiftUI

class NotchWindowController: NSWindowController {
    let viewModel: MascotViewModel
    private let screen: NSScreen
    private var cancellables = Set<AnyCancellable>()

    init(screen: NSScreen) {
        self.screen = screen

        let screenFrame = screen.frame
        let notchSize = screen.notchSize

        // Window covers full width at top, tall enough for notch + bubble dropdown
        let windowHeight: CGFloat = 300
        let windowFrame = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.maxY - windowHeight,
            width: screenFrame.width,
            height: windowHeight
        )

        let deviceNotchRect = CGRect(
            x: (screenFrame.width - notchSize.width) / 2,
            y: 0,
            width: notchSize.width,
            height: notchSize.height
        )

        let geometry = NotchGeometry(
            deviceNotchRect: deviceNotchRect,
            screenRect: screenFrame,
            windowHeight: windowHeight,
            hasPhysicalNotch: screen.hasPhysicalNotch
        )

        self.viewModel = MascotViewModel(
            geometry: geometry,
            hasPhysicalNotch: screen.hasPhysicalNotch
        )

        let notchWindow = NotchPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: notchWindow)

        let hostingController = MascotViewController(viewModel: viewModel)
        notchWindow.contentViewController = hostingController
        notchWindow.setFrame(windowFrame, display: true)

        // Default: ignore mouse events (clicks pass through to apps below)
        notchWindow.ignoresMouseEvents = true

        // When clicks land in the window but miss the bubble, dismiss and pass through
        notchWindow.onClickPassThrough = { [weak self] in
            self?.viewModel.dismissBubble()
        }

        // Toggle mouse event handling based on bubble visibility:
        // - No bubble: ignoresMouseEvents = true (full pass-through)
        // - Bubble visible: ignoresMouseEvents = false (buttons work, sendEvent handles pass-through)
        viewModel.$activeBubbleSessionId
            .receive(on: DispatchQueue.main)
            .sink { [weak notchWindow] sessionId in
                let hasBubble = sessionId != nil
                notchWindow?.ignoresMouseEvents = !hasBubble
            }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
