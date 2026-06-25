// SoundPlayer.swift
import AppKit

class SoundPlayer {
    static func play(_ name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }

    // All built-in macOS alert sounds
    static let availableSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk",
        "Glass", "Hero", "Morse", "Ping", "Pop",
        "Purr", "Sosumi", "Submarine", "Tink"
    ]
}
