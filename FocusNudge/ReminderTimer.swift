// ReminderTimer.swift
import Foundation
import Combine

enum ReminderType {
    case water
    case lookAway
}

/// A lightweight clock that ticks periodically so callers can re-check a schedule.
/// Ticks are frequent enough (< 60s) to guarantee every wall-clock minute is observed at least once.
class ReminderTimer: ObservableObject {
    private var cancellable: AnyCancellable?
    private var onTick: (() -> Void)?

    func setOnTick(_ onTick: @escaping () -> Void) {
        self.onTick = onTick
    }

    func start(intervalSeconds: TimeInterval = 15) {
        stop()
        cancellable = Timer.publish(every: intervalSeconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.onTick?()
            }
        onTick?()
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
