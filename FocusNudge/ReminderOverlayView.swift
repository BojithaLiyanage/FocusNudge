// ReminderOverlayView.swift
import SwiftUI

struct ReminderOverlayView: View {
    @ObservedObject var settings: ReminderSettings
    var type: ReminderType

    @EnvironmentObject var waterManager: WaterIntakeManager
    
    // Controls the appear/disappear animation trigger
    @State private var isVisible = false

    // Callback to dismiss the overlay
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────
            settings.backgroundColor
                .opacity(settings.backgroundOpacity)
                .ignoresSafeArea()

            // ── Content ─────────────────────────────────────────────
            VStack(spacing: 24) {
                HStack(spacing: 16) {
                    Image(systemName: type == .water ? "drop.fill" : "eye.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                    
                    Text(type == .water ? settings.waterMessage : settings.lookAwayMessage)
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)

                if type == .water {
                    HStack(spacing: 16) {
                        Button("Dismiss") {
                            waterManager.addIntake(amountML: 0)
                            dismiss()
                        }
                        .buttonStyle(DismissButtonStyle(isPrimary: false))
                        .keyboardShortcut(.escape, modifiers: [])

                        Button("+ 100 ml") {
                            waterManager.addIntake(amountML: 100)
                            dismiss()
                        }
                        .buttonStyle(DismissButtonStyle(isPrimary: true))
                        
                        Button("+ 200 ml") {
                            waterManager.addIntake(amountML: 200)
                            dismiss()
                        }
                        .buttonStyle(DismissButtonStyle(isPrimary: true))
                        
                        Button("+ 500 ml") {
                            waterManager.addIntake(amountML: 500)
                            dismiss()
                        }
                        .buttonStyle(DismissButtonStyle(isPrimary: true))
                        
                        Button("+ 1000 ml") {
                            waterManager.addIntake(amountML: 1000)
                            dismiss()
                        }
                        .buttonStyle(DismissButtonStyle(isPrimary: true))
                    }
                } else {
                    Button("Dismiss") {
                        dismiss()
                    }
                    .buttonStyle(DismissButtonStyle(isPrimary: true))
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
        }
        // ── Entry animation ──────────────────────────────────────────
        .modifier(AppearanceModifier(style: settings.animationStyle, isVisible: isVisible))
        .onAppear {
            withAnimation(animation(for: settings.animationStyle)) {
                isVisible = true
            }
            // Auto-dismiss after displayDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.displayDuration) {
                dismiss()
            }
        }
    }

    private func dismiss() {
        withAnimation(animation(for: settings.animationStyle)) {
            isVisible = false
        }
        // Small delay so the exit animation plays before window closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismiss()
        }
    }

    private func animation(for style: String) -> Animation {
        switch style {
        case "scale": return .spring(response: 0.4, dampingFraction: 0.7)
        case "slide": return .easeInOut(duration: 0.4)
        default:      return .easeInOut(duration: 0.35)   // "fade"
        }
    }
}

// ── Animation modifier ────────────────────────────────────────────────────────
struct AppearanceModifier: ViewModifier {
    let style: String
    let isVisible: Bool

    func body(content: Content) -> some View {
        switch style {
        case "scale":
            content
                .scaleEffect(isVisible ? 1 : 0.8)
                .opacity(isVisible ? 1 : 0)
        case "slide":
            content
                .offset(y: isVisible ? 0 : -40)
                .opacity(isVisible ? 1 : 0)
        default:   // "fade"
            content
                .opacity(isVisible ? 1 : 0)
        }
    }
}

// ── Dismiss button style ──────────────────────────────────────────────────────
struct DismissButtonStyle: ButtonStyle {
    var isPrimary: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isPrimary ? Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1.0) : Color.white.opacity(configuration.isPressed ? 0.25 : 0.15))
                    .overlay(Capsule().stroke(isPrimary ? Color.accentColor : Color.white.opacity(0.3), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
