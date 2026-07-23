// Theme.swift
import SwiftUI

enum Theme {
    static let cardCorner: CGFloat = 20
    static let defaultDailyGoalML = 2000

    // Water palette (the app's original system blue)
    static let aquaLight = Color.blue
    static let aquaDeep  = Color.blue
    static let seafoam   = Color.blue

    // Look-away palette
    static let violet     = Color(hex: "#9C8CFF") ?? .purple
    static let violetDeep = Color(hex: "#5B4FCF") ?? .indigo

    static func accent(for type: ReminderType) -> Color {
        type == .water ? aquaDeep : violetDeep
    }

    static func gradient(for type: ReminderType) -> [Color] {
        type == .water ? [aquaLight, aquaDeep] : [violet, violetDeep]
    }
}

// MARK: - 24-hour time helpers
extension Locale {
    /// Current locale, but hour cycle forced to 24-hour — use for all time display/entry.
    static var appTime: Locale {
        var components = Locale.Components(locale: .current)
        components.hourCycle = .zeroToTwentyThree
        return Locale(components: components)
    }
}

enum TimeFormat {
    /// Minutes-since-midnight → "HH:mm", via plain integer arithmetic (no locale exposure).
    static func hhmm(fromMinutes m: Int) -> String {
        String(format: "%02d:%02d", m / 60, m % 60)
    }
}

// MARK: - Card container (frosted aqua glass)
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.aquaLight.opacity(0.12), Theme.aquaDeep.opacity(0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .strokeBorder(Theme.aquaDeep.opacity(0.14), lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardBackground()) }
}

// MARK: - Bubble button (quick-add, quick actions)
struct PillButtonStyle: ButtonStyle {
    var tint: Color = Theme.aquaDeep
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .foregroundColor(prominent ? .white : tint)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        prominent
                        ? AnyShapeStyle(LinearGradient(colors: [tint.opacity(configuration.isPressed ? 0.75 : 0.95), tint.opacity(configuration.isPressed ? 0.55 : 0.7)], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(tint.opacity(configuration.isPressed ? 0.24 : 0.12))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tint.opacity(prominent ? 0 : 0.25), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Animated wave shape (used to render a "filling water" effect)
struct WaveShape: Shape {
    var progress: Double // 0...1, water level from the bottom
    var phase: Double     // animation offset, radians
    var amplitude: CGFloat = 6

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, phase) }
        set { progress = newValue.first; phase = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        let waterLevel = rect.height * (1 - clamped)
        let width = rect.width
        let step = max(width / 60, 1)

        var path = Path()
        path.move(to: CGPoint(x: 0, y: waterLevel))
        var x: CGFloat = 0
        while x <= width {
            let relative = x / max(width, 1)
            let y = waterLevel + sin(relative * 2 * .pi * 1.5 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        path.addLine(to: CGPoint(x: width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

/// A circular "water blob" that fills with an animated wave to represent progress toward a goal.
struct WaterWaveView: View {
    var progress: Double // 0...1
    var size: CGFloat = 64
    var showsPercentLabel: Bool = false
    var colors: [Color] = [Theme.aquaLight, Theme.aquaDeep]

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: 6) / 6 * 2 * .pi

            ZStack {
                Circle().fill(colors.last!.opacity(0.08))

                WaveShape(progress: progress, phase: phase, amplitude: size * 0.035)
                    .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))

                WaveShape(progress: progress, phase: phase + .pi / 2, amplitude: size * 0.02)
                    .fill(colors.first!.opacity(0.35))

                if showsPercentLabel {
                    Text("\(Int(min(max(progress, 0), 1) * 100))%")
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .foregroundColor(progress > 0.55 ? .white : colors.last)
                }
            }
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(colors.last!.opacity(0.28), lineWidth: max(1.5, size * 0.03))
            )
        }
        .frame(width: size, height: size)
    }
}

/// A fixed-column wrapping grid built from plain VStack/HStack.
///
/// `LazyVGrid` collapses to zero height inside self-sizing containers (a
/// `MenuBarExtra(.window)` popover, or a `Window` using `.windowResizability(.contentSize)`)
/// because they measure content before a lazy container has anything to report. This
/// eagerly lays out every row instead, so it always reports a real height.
struct WrapGrid<Item: Hashable, Content: View>: View {
    let items: [Item]
    let columns: Int
    var spacing: CGFloat = 8
    @ViewBuilder let content: (Item) -> Content

    private var rows: [[Item]] {
        guard columns > 0, !items.isEmpty else { return [] }
        return stride(from: 0, to: items.count, by: columns).map {
            Array(items[$0..<Swift.min($0 + columns, items.count)])
        }
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                    if row.count < columns {
                        ForEach(0..<(columns - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Section header used inside custom (non-Form) layouts
struct SectionHeader: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
        }
    }
}
