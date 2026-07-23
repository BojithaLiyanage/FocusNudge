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
            PreferencesView(settings: settings)
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

    private var todayML: Int { waterManager.intakeForDay() }
    private var progress: Double { Double(todayML) / Double(max(settings.dailyGoalML, 1)) }

    var body: some View {
        VStack(spacing: 16) {
            // ── Header ────────────────────────────────────────────────
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(LinearGradient(colors: Theme.gradient(for: .water), startPoint: .top, endPoint: .bottom))
                        .frame(width: 26, height: 26)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("FocusNudge")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.quaternary.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .help("Quit FocusNudge")
            }

            // ── Water card ───────────────────────────────────────────
            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    WaterWaveView(progress: progress, size: 60, showsPercentLabel: true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Intake")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(todayML) ml")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("Goal \(settings.dailyGoalML) ml")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }

                WrapGrid(items: settings.drinkContainers, columns: 3) { container in
                    Button {
                        waterManager.addIntake(amountML: container.amountML)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: container.icon)
                                .font(.system(size: 11))
                            Text("+\(container.amountML)")
                        }
                    }
                    .buttonStyle(PillButtonStyle(tint: Theme.aquaDeep, prominent: container.amountML >= 1000))
                }
            }
            .cardStyle()

            // ── Reminders ────────────────────────────────────────────
            VStack(spacing: 2) {
                ReminderToggleRow(icon: "drop.fill", tint: Theme.aquaDeep, title: "Water Reminder", isOn: $settings.isWaterEnabled)
                Divider().padding(.leading, 34)
                ReminderToggleRow(icon: "eye.fill", tint: Theme.violetDeep, title: "Look Away Reminder", isOn: $settings.isLookAwayEnabled)
            }
            .cardStyle()

            // ── Pause ────────────────────────────────────────────────
            PauseControlView(settings: settings)
                .cardStyle()

            // ── Preferences ──────────────────────────────────────────
            Button {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.title == "FocusNudge Preferences" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Label("Preferences…", systemImage: "gearshape.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle(tint: Color.blue, prominent: true))
        }
        .padding(16)
        .frame(width: 360)
    }
}

private struct ReminderToggleRow: View {
    let icon: String
    let tint: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(tint)
            }
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 4)
    }
}

private struct PauseControlView: View {
    @ObservedObject var settings: ReminderSettings

    var body: some View {
        if settings.isPaused {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                }
                Text("Paused until \(pausedUntilLabel)")
                    .font(.system(size: 13))
                Spacer()
                Button("Resume") { settings.resume() }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.vertical, 4)
        } else {
            Menu {
                Button("15 minutes") { settings.pause(minutes: 15) }
                Button("1 hour") { settings.pause(minutes: 60) }
                Button("Until tomorrow") { settings.pauseUntilTomorrow() }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 24, height: 24)
                        Image(systemName: "pause.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    Text("Pause Reminders")
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .menuStyle(.borderlessButton)
            .padding(.vertical, 4)
        }
    }

    private var pausedUntilLabel: String {
        guard let pausedUntil = settings.pausedUntil else { return "" }
        let formatter = DateFormatter()
        formatter.locale = .appTime
        if Calendar.current.isDateInToday(pausedUntil) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MMM d, HH:mm"
        }
        return formatter.string(from: pausedUntil)
    }
}
