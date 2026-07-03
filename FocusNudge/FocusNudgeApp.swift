// FocusNudgeApp.swift
import SwiftUI

@main
struct FocusNudgeApp: App {
    @StateObject private var settings      = ReminderSettings()
    @StateObject private var reminderTimer = ReminderTimer()
    @StateObject private var waterManager  = WaterIntakeManager()
    private let overlayManager             = OverlayWindowManager()

    // Coordinator is a plain let — initialized once via lazy trick
    @StateObject private var coordinator: AppCoordinator

    init() {
        let settings      = ReminderSettings()
        let reminderTimer = ReminderTimer()
        let waterManager  = WaterIntakeManager()
        let overlayManager = OverlayWindowManager()
        
        overlayManager.waterManager = waterManager

        _settings      = StateObject(wrappedValue: settings)
        _reminderTimer = StateObject(wrappedValue: reminderTimer)
        _waterManager  = StateObject(wrappedValue: waterManager)
        
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
                .environmentObject(waterManager)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("FocusNudge", systemImage: "drop.fill") {
            MenuBarPopupView(settings: settings, waterManager: waterManager)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarPopupView: View {
    @ObservedObject var settings: ReminderSettings
    @ObservedObject var waterManager: WaterIntakeManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("FocusNudge")
                    .font(.headline)
                Spacer()
                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "power")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Quit FocusNudge")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Total: \(waterManager.intakeForDay()) ml")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                HStack(spacing: 8) {
                    Button("+ 100 ml") { waterManager.addIntake(amountML: 100) }
                        .buttonStyle(.bordered)
                    Button("+ 200 ml") { waterManager.addIntake(amountML: 200) }
                        .buttonStyle(.bordered)
                    Button("+ 500 ml") { waterManager.addIntake(amountML: 500) }
                        .buttonStyle(.bordered)
                }
                Button("+ 1000 ml") { waterManager.addIntake(amountML: 1000) }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Water Reminder", isOn: $settings.isWaterEnabled)
                Toggle("Look Away Reminder", isOn: $settings.isLookAwayEnabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            Button("Preferences...") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.title == "FocusNudge Preferences" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(width: 400)
    }
}
