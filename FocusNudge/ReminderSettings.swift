// ReminderSettings.swift
import SwiftUI
import Combine

class ReminderSettings: ObservableObject {

    // MARK: - Water Reminder Settings
    @Published var isWaterEnabled: Bool {
        didSet { UserDefaults.standard.set(isWaterEnabled, forKey: "isWaterEnabled") }
    }

    /// Exact clock times (minutes since midnight, 0...1439) at which the water reminder fires.
    @Published var waterScheduledMinutes: [Int] {
        didSet { UserDefaults.standard.set(waterScheduledMinutes, forKey: "waterScheduledMinutes") }
    }

    @Published var waterActiveFromMinutes: Int {
        didSet { UserDefaults.standard.set(waterActiveFromMinutes, forKey: "waterActiveFromMinutes") }
    }

    @Published var waterActiveToMinutes: Int {
        didSet { UserDefaults.standard.set(waterActiveToMinutes, forKey: "waterActiveToMinutes") }
    }

    @Published var waterMessage: String {
        didSet { UserDefaults.standard.set(waterMessage, forKey: "waterMessage") }
    }

    // MARK: - Look Away Reminder Settings
    @Published var isLookAwayEnabled: Bool {
        didSet { UserDefaults.standard.set(isLookAwayEnabled, forKey: "isLookAwayEnabled") }
    }

    /// Exact clock times (minutes since midnight, 0...1439) at which the look-away reminder fires.
    @Published var lookAwayScheduledMinutes: [Int] {
        didSet { UserDefaults.standard.set(lookAwayScheduledMinutes, forKey: "lookAwayScheduledMinutes") }
    }

    @Published var lookAwayActiveFromMinutes: Int {
        didSet { UserDefaults.standard.set(lookAwayActiveFromMinutes, forKey: "lookAwayActiveFromMinutes") }
    }

    @Published var lookAwayActiveToMinutes: Int {
        didSet { UserDefaults.standard.set(lookAwayActiveToMinutes, forKey: "lookAwayActiveToMinutes") }
    }

    @Published var lookAwayMessage: String {
        didSet { UserDefaults.standard.set(lookAwayMessage, forKey: "lookAwayMessage") }
    }

    // MARK: - Water Goal & Containers
    @Published var dailyGoalML: Int {
        didSet { UserDefaults.standard.set(dailyGoalML, forKey: "dailyGoalML") }
    }

    @Published var drinkContainers: [DrinkContainer] {
        didSet {
            if let data = try? JSONEncoder().encode(drinkContainers) {
                UserDefaults.standard.set(data, forKey: "drinkContainers")
            }
        }
    }

    // MARK: - Shared Settings
    @Published var backgroundColorHex: String {
        didSet { UserDefaults.standard.set(backgroundColorHex, forKey: "backgroundColorHex") }
    }

    @Published var backgroundOpacity: Double {
        didSet { UserDefaults.standard.set(backgroundOpacity, forKey: "backgroundOpacity") }
    }

    @Published var animationStyle: String {
        didSet { UserDefaults.standard.set(animationStyle, forKey: "animationStyle") }
    }

    @Published var displayDuration: Double {
        didSet { UserDefaults.standard.set(displayDuration, forKey: "displayDuration") }
    }

    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }

    @Published var soundName: String {
        didSet { UserDefaults.standard.set(soundName, forKey: "soundName") }
    }

    /// When set and in the future, all reminders are silenced (e.g. while screen sharing on a call).
    @Published var pausedUntil: Date? {
        didSet {
            if let pausedUntil {
                UserDefaults.standard.set(pausedUntil, forKey: "pausedUntil")
            } else {
                UserDefaults.standard.removeObject(forKey: "pausedUntil")
            }
        }
    }

    init() {
        // Water
        self.isWaterEnabled = UserDefaults.standard.object(forKey: "isWaterEnabled") as? Bool ?? true
        self.waterMessage = UserDefaults.standard.string(forKey: "waterMessage") ?? "💧 Time to hydrate!"

        // Look Away
        self.isLookAwayEnabled = UserDefaults.standard.object(forKey: "isLookAwayEnabled") as? Bool ?? true
        self.lookAwayMessage = UserDefaults.standard.string(forKey: "lookAwayMessage") ?? "Time to look away for 20 seconds!"

        self.pausedUntil = UserDefaults.standard.object(forKey: "pausedUntil") as? Date

        // Water goal & containers
        self.dailyGoalML = UserDefaults.standard.object(forKey: "dailyGoalML") as? Int ?? Theme.defaultDailyGoalML
        if let data = UserDefaults.standard.data(forKey: "drinkContainers"),
           let decoded = try? JSONDecoder().decode([DrinkContainer].self, from: data) {
            self.drinkContainers = decoded
        } else {
            self.drinkContainers = DrinkContainer.defaults
        }

        // Shared
        self.backgroundColorHex = UserDefaults.standard.string(forKey: "backgroundColorHex") ?? "#000000"
        self.backgroundOpacity = UserDefaults.standard.object(forKey: "backgroundOpacity") as? Double ?? 0.5
        self.animationStyle = UserDefaults.standard.string(forKey: "animationStyle") ?? "fade"
        self.displayDuration = UserDefaults.standard.object(forKey: "displayDuration") as? Double ?? 5
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.soundName = UserDefaults.standard.string(forKey: "soundName") ?? "Ping"

        // Schedules + per-type active windows: migrate from legacy interval/shared-hours settings
        // on first launch after this change, otherwise fall back to sensible defaults.
        let legacyFromHour = UserDefaults.standard.object(forKey: "activeFromHour") as? Int ?? 9
        let legacyToHour = UserDefaults.standard.object(forKey: "activeToHour") as? Int ?? 22
        let legacyFromMinutes = legacyFromHour * 60
        let legacyToMinutes = legacyToHour * 60

        if UserDefaults.standard.object(forKey: "waterScheduledMinutes") == nil {
            let legacyWaterInterval = (UserDefaults.standard.object(forKey: "waterIntervalMinutes") as? Double)
                ?? (UserDefaults.standard.object(forKey: "intervalMinutes") as? Double)
            let interval = legacyWaterInterval ?? 45
            self.waterScheduledMinutes = ReminderSettings.stepSchedule(from: legacyFromMinutes, to: legacyToMinutes, everyMinutes: Int(interval))
            self.waterActiveFromMinutes = legacyFromMinutes
            self.waterActiveToMinutes = legacyToMinutes
        } else {
            self.waterScheduledMinutes = UserDefaults.standard.array(forKey: "waterScheduledMinutes") as? [Int] ?? []
            self.waterActiveFromMinutes = UserDefaults.standard.object(forKey: "waterActiveFromMinutes") as? Int ?? legacyFromMinutes
            self.waterActiveToMinutes = UserDefaults.standard.object(forKey: "waterActiveToMinutes") as? Int ?? legacyToMinutes
        }

        if UserDefaults.standard.object(forKey: "lookAwayScheduledMinutes") == nil {
            let legacyLookAwayInterval = (UserDefaults.standard.object(forKey: "lookAwayIntervalMinutes") as? Double)
                ?? (UserDefaults.standard.object(forKey: "intervalMinutes") as? Double)
            let interval = legacyLookAwayInterval ?? 20
            self.lookAwayScheduledMinutes = ReminderSettings.stepSchedule(from: legacyFromMinutes, to: legacyToMinutes, everyMinutes: Int(interval))
            self.lookAwayActiveFromMinutes = legacyFromMinutes
            self.lookAwayActiveToMinutes = legacyToMinutes
        } else {
            self.lookAwayScheduledMinutes = UserDefaults.standard.array(forKey: "lookAwayScheduledMinutes") as? [Int] ?? []
            self.lookAwayActiveFromMinutes = UserDefaults.standard.object(forKey: "lookAwayActiveFromMinutes") as? Int ?? legacyFromMinutes
            self.lookAwayActiveToMinutes = UserDefaults.standard.object(forKey: "lookAwayActiveToMinutes") as? Int ?? legacyToMinutes
        }
    }

    var backgroundColor: Color {
        Color(hex: backgroundColorHex) ?? .black
    }

    // MARK: - Scheduling

    /// Steps through [from, to) (wrapping past midnight if `to <= from`) every `everyMinutes`,
    /// producing a sorted list of minutes-since-midnight.
    private static func stepSchedule(from: Int, to: Int, everyMinutes: Int) -> [Int] {
        let step = max(1, everyMinutes)
        let span = to > from ? (to - from) : (1440 - from + to)
        guard span > 0 else { return [] }

        var result: [Int] = []
        var elapsed = 0
        while elapsed < span {
            result.append((from + elapsed) % 1440)
            elapsed += step
        }
        return result.sorted()
    }

    func scheduledMinutes(for type: ReminderType) -> [Int] {
        type == .water ? waterScheduledMinutes : lookAwayScheduledMinutes
    }

    func addScheduledTime(_ minutes: Int, for type: ReminderType) {
        switch type {
        case .water:
            guard !waterScheduledMinutes.contains(minutes) else { return }
            waterScheduledMinutes = (waterScheduledMinutes + [minutes]).sorted()
        case .lookAway:
            guard !lookAwayScheduledMinutes.contains(minutes) else { return }
            lookAwayScheduledMinutes = (lookAwayScheduledMinutes + [minutes]).sorted()
        }
    }

    func removeScheduledTime(_ minutes: Int, for type: ReminderType) {
        switch type {
        case .water:
            waterScheduledMinutes.removeAll { $0 == minutes }
        case .lookAway:
            lookAwayScheduledMinutes.removeAll { $0 == minutes }
        }
    }

    // MARK: - Drink Containers

    func addContainer(name: String, amountML: Int, icon: String) {
        drinkContainers.append(DrinkContainer(name: name, amountML: amountML, icon: icon))
    }

    func updateContainer(_ container: DrinkContainer) {
        guard let index = drinkContainers.firstIndex(where: { $0.id == container.id }) else { return }
        drinkContainers[index] = container
    }

    func deleteContainer(_ id: UUID) {
        drinkContainers.removeAll { $0.id == id }
    }

    func moveContainer(fromOffsets: IndexSet, toOffset: Int) {
        drinkContainers.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    /// Replaces the type's schedule with times stepped across its active window at `everyMinutes`.
    func quickFill(everyMinutes: Int, for type: ReminderType) {
        let from = type == .water ? waterActiveFromMinutes : lookAwayActiveFromMinutes
        let to = type == .water ? waterActiveToMinutes : lookAwayActiveToMinutes
        let generated = ReminderSettings.stepSchedule(from: from, to: to, everyMinutes: everyMinutes)
        switch type {
        case .water: waterScheduledMinutes = generated
        case .lookAway: lookAwayScheduledMinutes = generated
        }
    }

    // MARK: - Active Window

    func isWithinActiveWindow(for type: ReminderType) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let currentMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)

        let from = type == .water ? waterActiveFromMinutes : lookAwayActiveFromMinutes
        let to = type == .water ? waterActiveToMinutes : lookAwayActiveToMinutes

        if from == to {
            return true // zero-width window is treated as "always active", not "never"
        } else if from < to {
            return currentMinutes >= from && currentMinutes < to
        } else {
            // Handles overnight ranges e.g. 22:00 → 02:00
            return currentMinutes >= from || currentMinutes < to
        }
    }

    // MARK: - Pause

    var isPaused: Bool {
        guard let pausedUntil else { return false }
        return Date() < pausedUntil
    }

    func pause(minutes: Double) {
        pausedUntil = Date().addingTimeInterval(minutes * 60)
    }

    func pauseUntilTomorrow() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        pausedUntil = calendar.date(byAdding: .day, value: 1, to: startOfToday)
    }

    func resume() {
        pausedUntil = nil
    }
}
