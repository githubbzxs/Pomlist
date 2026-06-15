import SwiftUI

enum PomlistTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.035, green: 0.045, blue: 0.060),
            Color(red: 0.060, green: 0.075, blue: 0.095),
            Color(red: 0.040, green: 0.055, blue: 0.070)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panel = Color.white.opacity(0.075)
    static let panelStrong = Color.white.opacity(0.115)
    static let stroke = Color.white.opacity(0.13)
    static let text = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.62)
    static let mutedText = Color.white.opacity(0.42)
    static let accent = Color(red: 0.57, green: 0.96, blue: 0.78)
    static let amber = Color(red: 1.00, green: 0.72, blue: 0.33)
    static let rose = Color(red: 1.00, green: 0.43, blue: 0.56)
    static let blue = Color(red: 0.40, green: 0.69, blue: 1.00)

    static func categoryColor(_ category: String) -> Color {
        let palette: [Color] = [accent, amber, blue, rose, Color(red: 0.78, green: 0.64, blue: 1.0)]
        let seed = category.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }
        let index = seed % palette.count
        return palette[index]
    }
}

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 24
    var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(opacity), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PomlistTheme.stroke, lineWidth: 1)
            }
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 24, opacity: Double = 1) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, opacity: opacity))
    }

    func pomlistScreenPadding() -> some View {
        padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.88))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(PomlistTheme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(PomlistTheme.text)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(PomlistTheme.panelStrong, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(PomlistTheme.stroke, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct ScreenHeader: View {
    var title: String
    var subtitle: String
    var systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PomlistTheme.accent)
                .frame(width: 42, height: 42)
                .background(PomlistTheme.panelStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PomlistTheme.text)
                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(PomlistTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }
}

struct MetricPill: View {
    var title: String
    var value: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(PomlistTheme.secondaryText)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(PomlistTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
    }
}

struct EmptyStateView: View {
    var systemImage: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PomlistTheme.secondaryText)
                .frame(width: 64, height: 64)
                .background(PomlistTheme.panel, in: Circle())
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(PomlistTheme.text)
            Text(message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(PomlistTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .glassPanel(cornerRadius: 24, opacity: 0.75)
    }
}

enum PomlistFormatters {
    static let dayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日 HH:mm"
        return formatter
    }()

    static let shortDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(max(1, minutes))m"
    }

    static func clock(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        let hours = safe / 3600
        let minutes = (safe % 3600) / 60
        let secs = safe % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
