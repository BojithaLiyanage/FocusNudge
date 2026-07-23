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

    private var accentColors: [Color] { Theme.gradient(for: type) }

    private var goalProgress: Double {
        Double(waterManager.intakeForDay()) / Double(max(settings.dailyGoalML, 1))
    }

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────
            settings.backgroundColor
                .opacity(settings.backgroundOpacity)
                .ignoresSafeArea()

            RadialGradient(
                colors: [accentColors.first!.opacity(0.22), Color.clear],
                center: .center, startRadius: 0, endRadius: 460
            )
            .ignoresSafeArea()

            // ── Content ─────────────────────────────────────────────
            VStack(spacing: 28) {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: accentColors.map { $0.opacity(0.35) }, startPoint: .top, endPoint: .bottom))
                            .frame(width: 96, height: 96)
                        Circle()
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 96, height: 96)
                        Image(systemName: type == .water ? "drop.fill" : "eye.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    .shadow(color: accentColors.last!.opacity(0.5), radius: 20, x: 0, y: 8)

                    Text(type == .water ? settings.waterMessage : settings.lookAwayMessage)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)

                    if type == .water {
                        VStack(spacing: 6) {
                            WaterWaveView(progress: goalProgress, size: 56, showsPercentLabel: true, colors: accentColors)
                            Text("\(waterManager.intakeForDay()) / \(settings.dailyGoalML) ml today")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        .padding(.top, 4)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)

                if type == .water {
                    HStack(spacing: 16) {
                        Button("Dismiss") {
                            dismiss()
                        }
                        .buttonStyle(DismissButtonStyle(isPrimary: false, tint: accentColors.last!))
                        .keyboardShortcut(.escape, modifiers: [])

                        ForEach(settings.drinkContainers) { container in
                            Button {
                                waterManager.addIntake(amountML: container.amountML)
                                dismiss()
                            } label: {
                                Label("+ \(container.amountML) ml", systemImage: container.icon)
                            }
                            .buttonStyle(DismissButtonStyle(isPrimary: true, tint: accentColors.last!))
                        }
                    }
                } else {
                    Button("Dismiss") {
                        dismiss()
                    }
                    .buttonStyle(DismissButtonStyle(isPrimary: true, tint: accentColors.last!))
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
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.95))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isPrimary
                          ? AnyShapeStyle(LinearGradient(colors: [tint.opacity(configuration.isPressed ? 0.75 : 1.0), tint.opacity(configuration.isPressed ? 0.55 : 0.75)], startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.white.opacity(configuration.isPressed ? 0.25 : 0.15)))
                    .overlay(Capsule().stroke(isPrimary ? tint.opacity(0.6) : Color.white.opacity(0.3), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
