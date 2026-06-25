// PreferencesView.swift
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: ReminderSettings
    @ObservedObject var reminderTimer: ReminderTimer
    @State private var pickedColor: Color = .black

    var body: some View {
        Form {
            // ── Message ───────────────────────────────────────────────
            Section("Reminder Message") {
                TextField("Message", text: $settings.message)
                    .textFieldStyle(.roundedBorder)
            }

            // ── Active Hours ──────────────────────────────────────────
            Section("Active Hours") {
                HStack {
                    Text("From")
                    Picker("", selection: $settings.activeFromHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }
                    .frame(width: 100)

                    Text("to")

                    Picker("", selection: $settings.activeToHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }
                    .frame(width: 100)
                }

                Text("Reminders only fire between these hours")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // ── Timing ────────────────────────────────────────────────
            Section("Timing") {
                HStack {
                    Text("Remind every")
                    Slider(value: $settings.intervalMinutes, in: 1...120, step: 1)
                    Text("\(Int(settings.intervalMinutes)) min")
                        .frame(width: 55, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack {
                    Text("Show for")
                    Slider(value: $settings.displayDuration, in: 2...30, step: 1)
                    Text("\(Int(settings.displayDuration)) sec")
                        .frame(width: 55, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            // ── Sound ─────────────────────────────────────────────────
            Section("Sound") {
                Toggle("Play sound with reminder", isOn: $settings.soundEnabled)

                if settings.soundEnabled {
                    HStack {
                        Picker("Sound", selection: $settings.soundName) {
                            ForEach(SoundPlayer.availableSounds, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }

                        Button("▶") {
                            SoundPlayer.play(settings.soundName)
                        }
                        .buttonStyle(.borderless)
                        .help("Preview sound")
                    }
                }
            }

            // ── Appearance ────────────────────────────────────────────
            Section("Appearance") {
                ColorPicker("Background color", selection: $pickedColor)
                    .onChange(of: pickedColor) { newColor in
                        if let hex = newColor.toHex() {
                            settings.backgroundColorHex = hex
                        }
                    }

                HStack {
                    Text("Opacity")
                    Slider(value: $settings.backgroundOpacity, in: 0.1...1.0, step: 0.05)
                    Text("\(Int(settings.backgroundOpacity * 100))%")
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }

                Picker("Animation", selection: $settings.animationStyle) {
                    Text("Fade").tag("fade")
                    Text("Scale").tag("scale")
                    Text("Slide").tag("slide")
                }
                .pickerStyle(.segmented)
            }

            // ── Controls ──────────────────────────────────────────────
            Section {
                HStack {
                    Button(reminderTimer.isRunning ? "Stop Reminders" : "Start Reminders") {
                        reminderTimer.isRunning
                            ? reminderTimer.stop()
                            : reminderTimer.restart(intervalMinutes: settings.intervalMinutes)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(reminderTimer.isRunning ? .red : .accentColor)

                    Spacer()

                    Button("Preview Now") {
                        NotificationCenter.default.post(name: .triggerReminder, object: nil)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 440)
        .onAppear {
            pickedColor = settings.backgroundColor
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}
