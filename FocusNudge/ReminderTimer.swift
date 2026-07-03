// ReminderTimer.swift
import Foundation
import Combine

enum ReminderType {
    case water
    case lookAway
}

class ReminderTimer: ObservableObject {
    @Published var isWaterRunning = false
    @Published var isLookAwayRunning = false

    private var waterTimer: AnyCancellable?
    private var lookAwayTimer: AnyCancellable?
    
    private var onFire: ((ReminderType) -> Void)?

    func setOnFire(_ onFire: @escaping (ReminderType) -> Void) {
        self.onFire = onFire
    }

    // MARK: - Water Timer
    
    func startWater(intervalMinutes: Double) {
        let interval = intervalMinutes * 60
        isWaterRunning = true
        waterTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.onFire?(.water)
            }
    }

    func stopWater() {
        waterTimer?.cancel()
        waterTimer = nil
        isWaterRunning = false
    }

    func restartWater(intervalMinutes: Double) {
        stopWater()
        startWater(intervalMinutes: intervalMinutes)
    }

    // MARK: - Look Away Timer
    
    func startLookAway(intervalMinutes: Double) {
        let interval = intervalMinutes * 60
        isLookAwayRunning = true
        lookAwayTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.onFire?(.lookAway)
            }
    }

    func stopLookAway() {
        lookAwayTimer?.cancel()
        lookAwayTimer = nil
        isLookAwayRunning = false
    }

    func restartLookAway(intervalMinutes: Double) {
        stopLookAway()
        startLookAway(intervalMinutes: intervalMinutes)
    }
    
    func stopAll() {
        stopWater()
        stopLookAway()
    }
}
