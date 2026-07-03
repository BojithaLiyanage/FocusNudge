// ReminderSettings.swift
import SwiftUI
import Combine

class ReminderSettings: ObservableObject {

    // MARK: - Water Reminder Settings
    @Published var isWaterEnabled: Bool {
        didSet { UserDefaults.standard.set(isWaterEnabled, forKey: "isWaterEnabled") }
    }
    
    @Published var waterIntervalMinutes: Double {
        didSet { UserDefaults.standard.set(waterIntervalMinutes, forKey: "waterIntervalMinutes") }
    }
    
    @Published var waterMessage: String {
        didSet { UserDefaults.standard.set(waterMessage, forKey: "waterMessage") }
    }
    
    // MARK: - Look Away Reminder Settings
    @Published var isLookAwayEnabled: Bool {
        didSet { UserDefaults.standard.set(isLookAwayEnabled, forKey: "isLookAwayEnabled") }
    }
    
    @Published var lookAwayIntervalMinutes: Double {
        didSet { UserDefaults.standard.set(lookAwayIntervalMinutes, forKey: "lookAwayIntervalMinutes") }
    }
    
    @Published var lookAwayMessage: String {
        didSet { UserDefaults.standard.set(lookAwayMessage, forKey: "lookAwayMessage") }
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
    
    @Published var activeFromHour: Int {
        didSet { UserDefaults.standard.set(activeFromHour, forKey: "activeFromHour") }
    }
    
    @Published var activeToHour: Int {
        didSet { UserDefaults.standard.set(activeToHour, forKey: "activeToHour") }
    }

    init() {
        // Water
        self.isWaterEnabled = UserDefaults.standard.object(forKey: "isWaterEnabled") as? Bool ?? true
        self.waterIntervalMinutes = UserDefaults.standard.object(forKey: "waterIntervalMinutes") as? Double ?? 45
        self.waterMessage = UserDefaults.standard.string(forKey: "waterMessage") ?? "💧 Time to hydrate!"
        
        // Look Away
        self.isLookAwayEnabled = UserDefaults.standard.object(forKey: "isLookAwayEnabled") as? Bool ?? true
        self.lookAwayIntervalMinutes = UserDefaults.standard.object(forKey: "lookAwayIntervalMinutes") as? Double ?? 20
        self.lookAwayMessage = UserDefaults.standard.string(forKey: "lookAwayMessage") ?? "Time to look away for 20 seconds!"
        
        // Shared
        self.backgroundColorHex = UserDefaults.standard.string(forKey: "backgroundColorHex") ?? "#000000"
        self.backgroundOpacity = UserDefaults.standard.object(forKey: "backgroundOpacity") as? Double ?? 0.5
        self.animationStyle = UserDefaults.standard.string(forKey: "animationStyle") ?? "fade"
        self.displayDuration = UserDefaults.standard.object(forKey: "displayDuration") as? Double ?? 5
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.soundName = UserDefaults.standard.string(forKey: "soundName") ?? "Ping"
        self.activeFromHour = UserDefaults.standard.object(forKey: "activeFromHour") as? Int ?? 9
        self.activeToHour = UserDefaults.standard.object(forKey: "activeToHour") as? Int ?? 22
        
        // Migrate legacy settings if they exist and are missing the new prefixed keys
        if UserDefaults.standard.object(forKey: "waterIntervalMinutes") == nil,
           let legacyInterval = UserDefaults.standard.object(forKey: "intervalMinutes") as? Double {
            self.waterIntervalMinutes = legacyInterval
            self.lookAwayIntervalMinutes = legacyInterval
        }
    }

    var backgroundColor: Color {
        Color(hex: backgroundColorHex) ?? .black
    }
    
    var isWithinActiveWindow: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        if activeFromHour <= activeToHour {
            return hour >= activeFromHour && hour < activeToHour
        } else {
            // Handles overnight ranges e.g. 22:00 → 02:00
            return hour >= activeFromHour || hour < activeToHour
        }
    }
}
