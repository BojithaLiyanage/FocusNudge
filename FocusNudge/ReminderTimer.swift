// ReminderTimer.swift
import Foundation
import Combine

class ReminderTimer: ObservableObject {
    @Published var isRunning = false

    private var timer: AnyCancellable?
    private var onFire: (() -> Void)?

    func start(intervalMinutes: Double, onFire: @escaping () -> Void) {
        self.onFire = onFire
        let interval = intervalMinutes * 60   // convert to seconds
        isRunning = true

        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.onFire?()
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
    }

    // Call this when the user changes the interval in preferences
    func restart(intervalMinutes: Double) {
        stop()
        start(intervalMinutes: intervalMinutes, onFire: onFire ?? {})
    }
}
