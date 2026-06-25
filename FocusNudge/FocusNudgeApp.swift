// FocusNudgeApp.swift
import SwiftUI

@main
struct FocusNudgeApp: App {
    @StateObject private var settings      = ReminderSettings()
    @StateObject private var reminderTimer = ReminderTimer()
    private let overlayManager             = OverlayWindowManager()

    // Coordinator is a plain let — initialized once via lazy trick
    @StateObject private var coordinator: AppCoordinator

    init() {
        let settings      = ReminderSettings()
        let reminderTimer = ReminderTimer()
        let overlayManager = OverlayWindowManager()

        _settings      = StateObject(wrappedValue: settings)
        _reminderTimer = StateObject(wrappedValue: reminderTimer)
        _coordinator   = StateObject(wrappedValue: AppCoordinator(
            settings:       settings,
            reminderTimer:  reminderTimer,
            overlayManager: overlayManager
        ))

        // Hide the app from the Dock
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        Window("FocusNudge Preferences", id: "preferences") {
            PreferencesView(settings: settings, reminderTimer: reminderTimer)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("FocusNudge", systemImage: "drop.fill") {
            Text("FocusNudge").font(.headline)
            Divider()
            Button(reminderTimer.isRunning ? "Stop" : "Start") {
                reminderTimer.isRunning
                    ? reminderTimer.stop()
                    : reminderTimer.restart(intervalMinutes: settings.intervalMinutes)
            }
            Button("Preview Reminder") { coordinator.showOverlay() }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}
