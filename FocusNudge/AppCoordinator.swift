// AppCoordinator.swift
import Foundation
import Combine

class AppCoordinator: ObservableObject {
    var cancellables = Set<AnyCancellable>()

    private let settings: ReminderSettings
    private let reminderTimer: ReminderTimer
    private let overlayManager: OverlayWindowManager

    /// Tracks the last "day-minute" key each type fired for, so a single scheduled
    /// minute doesn't re-trigger on every clock tick within that minute.
    private var lastFiredKey: [ReminderType: String] = [:]

    init(settings: ReminderSettings, reminderTimer: ReminderTimer, overlayManager: OverlayWindowManager) {
        self.settings      = settings
        self.reminderTimer = reminderTimer
        self.overlayManager = overlayManager

        setupClock()
        observePreviewNotification()
    }

    func showOverlay(for type: ReminderType) {
        if settings.soundEnabled {
            SoundPlayer.play(settings.soundName)
        }
        overlayManager.show(settings: settings, type: type)
    }

    private func setupClock() {
        reminderTimer.setOnTick { [weak self] in
            self?.evaluateTick()
        }
        reminderTimer.start()
    }

    private func evaluateTick() {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        guard let year = comps.year, let month = comps.month, let day = comps.day,
              let hour = comps.hour, let minute = comps.minute else { return }

        let totalMinutes = hour * 60 + minute
        let dayKey = "\(year)-\(month)-\(day)"

        for type: ReminderType in [.water, .lookAway] {
            guard isEnabled(type),
                  !settings.isPaused,
                  settings.isWithinActiveWindow(for: type),
                  settings.scheduledMinutes(for: type).contains(totalMinutes) else { continue }

            let key = "\(dayKey)-\(totalMinutes)"
            guard lastFiredKey[type] != key else { continue }
            lastFiredKey[type] = key
            showOverlay(for: type)
        }
    }

    private func isEnabled(_ type: ReminderType) -> Bool {
        type == .water ? settings.isWaterEnabled : settings.isLookAwayEnabled
    }

    private func observePreviewNotification() {
        NotificationCenter.default.publisher(for: .triggerWaterReminder)
            .sink { [weak self] _ in
                self?.showOverlay(for: .water)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .triggerLookAwayReminder)
            .sink { [weak self] _ in
                self?.showOverlay(for: .lookAway)
            }
            .store(in: &cancellables)
    }
}
