// AppCoordinator.swift
import Foundation
import Combine

class AppCoordinator: ObservableObject {
    var cancellables = Set<AnyCancellable>()
    
    private let settings: ReminderSettings
    private let reminderTimer: ReminderTimer
    private let overlayManager: OverlayWindowManager

    init(settings: ReminderSettings, reminderTimer: ReminderTimer, overlayManager: OverlayWindowManager) {
        self.settings      = settings
        self.reminderTimer = reminderTimer
        self.overlayManager = overlayManager

        startTimer()
        observeIntervalChanges()
        observePreviewNotification()
    }

    func showOverlay() {
        if settings.soundEnabled {
            SoundPlayer.play(settings.soundName)
        }
        overlayManager.show(settings: settings)
    }

    private func startTimer() {
        reminderTimer.start(intervalMinutes: settings.intervalMinutes) { [weak self] in
            self?.showOverlay()
        }
    }

    private func observeIntervalChanges() {
        settings.$intervalMinutes
            .dropFirst()
            .sink { [weak self] newInterval in
                self?.reminderTimer.restart(intervalMinutes: newInterval)
            }
            .store(in: &cancellables)
    }

    private func observePreviewNotification() {
        NotificationCenter.default.publisher(for: .triggerReminder)
            .sink { [weak self] _ in
                self?.showOverlay()
            }
            .store(in: &cancellables)
    }
}
