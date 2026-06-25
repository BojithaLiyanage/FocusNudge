// ReminderOverlayView.swift
import SwiftUI

struct ReminderOverlayView: View {
    @ObservedObject var settings: ReminderSettings

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
                Text(settings.message)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 60)

                Button("Dismiss") {
                    dismiss()
                }
                .buttonStyle(DismissButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.25 : 0.15))
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
