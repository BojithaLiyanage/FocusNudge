// ReminderSettings.swift
import SwiftUI
import Combine

class ReminderSettings: ObservableObject {

    // Interval in minutes between reminders
    @Published var intervalMinutes: Double {
        didSet { UserDefaults.standard.set(intervalMinutes, forKey: "intervalMinutes") }
    }

    // Message shown in the overlay
    @Published var message: String {
        didSet { UserDefaults.standard.set(message, forKey: "message") }
    }

    // Background color stored as hex string
    @Published var backgroundColorHex: String {
        didSet { UserDefaults.standard.set(backgroundColorHex, forKey: "backgroundColorHex") }
    }

    // Opacity: 0.0 – 1.0
    @Published var backgroundOpacity: Double {
        didSet { UserDefaults.standard.set(backgroundOpacity, forKey: "backgroundOpacity") }
    }

    // Animation style: "fade", "scale", "slide"
    @Published var animationStyle: String {
        didSet { UserDefaults.standard.set(animationStyle, forKey: "animationStyle") }
    }

    // Duration the overlay stays visible (seconds)
    @Published var displayDuration: Double {
        didSet { UserDefaults.standard.set(displayDuration, forKey: "displayDuration") }
    }
    
    // Add to ReminderSettings class
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
        self.intervalMinutes  = UserDefaults.standard.object(forKey: "intervalMinutes")  as? Double ?? 30
        self.message          = UserDefaults.standard.string(forKey: "message")          ?? "💧 Time to hydrate!"
        self.backgroundColorHex = UserDefaults.standard.string(forKey: "backgroundColorHex") ?? "#000000"
        self.backgroundOpacity  = UserDefaults.standard.object(forKey: "backgroundOpacity")  as? Double ?? 0.5
        self.animationStyle   = UserDefaults.standard.string(forKey: "animationStyle")   ?? "fade"
        self.displayDuration  = UserDefaults.standard.object(forKey: "displayDuration")  as? Double ?? 5
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.soundName    = UserDefaults.standard.string(forKey: "soundName") ?? "Ping"
        self.activeFromHour = UserDefaults.standard.object(forKey: "activeFromHour") as? Int ?? 9
        self.activeToHour   = UserDefaults.standard.object(forKey: "activeToHour")   as? Int ?? 22

    }

    // Convenience: convert hex string → SwiftUI Color
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
