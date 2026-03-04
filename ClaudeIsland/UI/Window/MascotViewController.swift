//
//  MascotViewController.swift
//  ClaudeIsland
//
//  Hosts MascotCanvasView in a PassThroughHostingView.
//  Hit-test only covers the bubble area (notch area is handled by global event monitors).
//

import AppKit
import SwiftUI

class MascotViewController: NSViewController {
    private let viewModel: MascotViewModel
    private var hostingView: PassThroughHostingView<MascotCanvasView>!

    init(viewModel: MascotViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        hostingView = PassThroughHostingView(rootView: MascotCanvasView(viewModel: viewModel))

        // Hit-test: only accept clicks in the bubble area (centered below the notch).
        // The notch itself uses global event monitors, so no hit-test needed there.
        // This rect is only active when ignoresMouseEvents = false (bubble visible).
        hostingView.hitTestRect = { [weak self] in
            guard let self = self else { return .zero }
            let geometry = self.viewModel.geometry
            let windowHeight = geometry.windowHeight
            let screenWidth = geometry.screenRect.width
            let notchWidth = geometry.deviceNotchRect.width

            // Bubble is centered below the notch, ~250px wide, up to 300px tall
            let bubbleWidth: CGFloat = max(notchWidth, 410)
            let bubbleHeight: CGFloat = 280
            let centerX = screenWidth / 2

            // In window coords: origin bottom-left, Y up.
            // The notch is at the top of the window. Bubble is below the notch.
            // Notch bottom in window coords = windowHeight - notchHeight
            let notchHeight = geometry.deviceNotchRect.height
            let topOfBubble = windowHeight - notchHeight

            return CGRect(
                x: centerX - bubbleWidth / 2,
                y: topOfBubble - bubbleHeight,
                width: bubbleWidth,
                height: bubbleHeight + notchHeight // include notch area too
            )
        }

        self.view = hostingView
    }
}
