// OverlayWindowManager.swift
import AppKit
import SwiftUI

class OverlayWindowManager {
    private var overlayWindow: NSWindow?
    var waterManager: WaterIntakeManager? // We'll set this from AppCoordinator or FocusNudgeApp

    func show(settings: ReminderSettings, type: ReminderType) {
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

        let overlayView = ReminderOverlayView(settings: settings, type: type) {
            self.dismiss()
        }
        
        var hostingView: NSView
        if let waterManager = waterManager {
            hostingView = NSHostingView(rootView: overlayView.environmentObject(waterManager))
        } else {
            hostingView = NSHostingView(rootView: overlayView)
        }

        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        overlayWindow = window
    }

    func dismiss() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }
}
