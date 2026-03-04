//
//  EventMonitors.swift
//  ClaudeIsland
//
//  Singleton that aggregates all event monitors
//

import AppKit
import Combine

class EventMonitors {
    static let shared = EventMonitors()

    let mouseLocation = CurrentValueSubject<CGPoint, Never>(.zero)
    let mouseDown = PassthroughSubject<NSEvent, Never>()
    let rightMouseDown = PassthroughSubject<NSEvent, Never>()

    private var mouseMoveMonitor: EventMonitor?
    private var mouseDownMonitor: EventMonitor?
    private var rightMouseDownMonitor: EventMonitor?
    private var mouseDraggedMonitor: EventMonitor?

    private init() {
        setupMonitors()
    }

    private func setupMonitors() {
        mouseMoveMonitor = EventMonitor(mask: .mouseMoved) { [weak self] _ in
            self?.mouseLocation.send(NSEvent.mouseLocation)
        }
        mouseMoveMonitor?.start()

        mouseDownMonitor = EventMonitor(mask: .leftMouseDown) { [weak self] event in
            self?.mouseDown.send(event)
        }
        mouseDownMonitor?.start()

        rightMouseDownMonitor = EventMonitor(mask: .rightMouseDown) { [weak self] event in
            self?.rightMouseDown.send(event)
        }
        rightMouseDownMonitor?.start()

        mouseDraggedMonitor = EventMonitor(mask: .leftMouseDragged) { [weak self] _ in
            self?.mouseLocation.send(NSEvent.mouseLocation)
        }
        mouseDraggedMonitor?.start()
    }

    deinit {
        mouseMoveMonitor?.stop()
        mouseDownMonitor?.stop()
        rightMouseDownMonitor?.stop()
        mouseDraggedMonitor?.stop()
    }
}
