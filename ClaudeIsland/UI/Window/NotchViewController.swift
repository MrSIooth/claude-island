//
//  NotchViewController.swift
//  ClaudeIsland
//
//  Reusable PassThroughHostingView for click-through support
//

import AppKit
import SwiftUI

/// Custom NSHostingView that only accepts mouse events within the panel bounds.
/// Clicks outside the panel pass through to windows behind.
class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    var hitTestRect: () -> CGRect = { .zero }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only accept hits within the panel rect
        guard hitTestRect().contains(point) else {
            return nil  // Pass through to windows behind
        }
        return super.hitTest(point)
    }
}
