// OverlayWindowManager.swift
import AppKit
import SwiftUI

class OverlayWindowManager {
    private var overlayWindow: NSWindow?

    func show(settings: ReminderSettings) {
        guard overlayWindow == nil else { return }  // prevent stacking

        // Use the main screen's full frame
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame  = screen.frame

        let window = NSWindow(
            contentRect: frame,
            styleMask:   [.borderless],
            backing:     .buffered,
            defer:       false
        )

        window.level              = .screenSaver   // above everything, including fullscreen apps
        window.backgroundColor    = .clear
        window.isOpaque           = false
        window.hasShadow          = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false

        let overlayView = ReminderOverlayView(settings: settings) {
            self.dismiss()
        }

        window.contentView = NSHostingView(rootView: overlayView)
        window.makeKeyAndOrderFront(nil)
        overlayWindow = window
    }

    func dismiss() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }
}
