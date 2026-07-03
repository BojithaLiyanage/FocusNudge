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

        setupTimer()
        observeSettingsChanges()
        observePreviewNotification()
    }

    func showOverlay(for type: ReminderType) {
        // Skip showing overlay if outside active window, unless it's a manual preview (but here we check it anyway for safety, we could bypass for preview if needed, but let's keep it simple)
        // Wait, for manual preview we might want it regardless. Let's let the caller or notification decide, but right now preview just triggers this directly.
        // I will check it in the timer callback instead if needed, but previously `isWithinActiveWindow` was checked somewhere else? Wait, it wasn't checked before! The previous implementation didn't actually check `isWithinActiveWindow` when firing! 
        // I should check it here so the reminder doesn't show at night.
        
        // Actually, preview shouldn't be blocked. Let's just pass a flag or check.
        // For now, let's keep it simple and just show it. We'll add the active window check here but bypass if it's a preview.
        
        if settings.soundEnabled {
            SoundPlayer.play(settings.soundName)
        }
        overlayManager.show(settings: settings, type: type)
    }

    private func setupTimer() {
        reminderTimer.setOnFire { [weak self] type in
            guard let self = self else { return }
            if self.settings.isWithinActiveWindow {
                self.showOverlay(for: type)
            }
        }
        
        if settings.isWaterEnabled {
            reminderTimer.startWater(intervalMinutes: settings.waterIntervalMinutes)
        }
        
        if settings.isLookAwayEnabled {
            reminderTimer.startLookAway(intervalMinutes: settings.lookAwayIntervalMinutes)
        }
    }

    private func observeSettingsChanges() {
        settings.$waterIntervalMinutes
            .dropFirst()
            .sink { [weak self] newInterval in
                if self?.settings.isWaterEnabled == true {
                    self?.reminderTimer.restartWater(intervalMinutes: newInterval)
                }
            }
            .store(in: &cancellables)
            
        settings.$lookAwayIntervalMinutes
            .dropFirst()
            .sink { [weak self] newInterval in
                if self?.settings.isLookAwayEnabled == true {
                    self?.reminderTimer.restartLookAway(intervalMinutes: newInterval)
                }
            }
            .store(in: &cancellables)
            
        settings.$isWaterEnabled
            .dropFirst()
            .sink { [weak self] isEnabled in
                guard let self = self else { return }
                if isEnabled {
                    self.reminderTimer.startWater(intervalMinutes: self.settings.waterIntervalMinutes)
                } else {
                    self.reminderTimer.stopWater()
                }
            }
            .store(in: &cancellables)
            
        settings.$isLookAwayEnabled
            .dropFirst()
            .sink { [weak self] isEnabled in
                guard let self = self else { return }
                if isEnabled {
                    self.reminderTimer.startLookAway(intervalMinutes: self.settings.lookAwayIntervalMinutes)
                } else {
                    self.reminderTimer.stopLookAway()
                }
            }
            .store(in: &cancellables)
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
