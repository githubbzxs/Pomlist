import SwiftUI

enum PomlistPalette {
    static let accent = Color(red: 0.149, green: 0.475, blue: 0.949)
    static let accentSoft = Color(red: 0.431, green: 0.678, blue: 0.984)
    static let backgroundTop = Color(red: 0.965, green: 0.979, blue: 1.0)
    static let backgroundBottom = Color(red: 0.911, green: 0.941, blue: 0.992)
    static let ink = Color.black.opacity(0.82)
    static let secondaryInk = Color.black.opacity(0.58)
    static let stroke = Color.white.opacity(0.62)
    static let success = Color(red: 0.188, green: 0.737, blue: 0.361)
    static let warning = Color(red: 0.965, green: 0.624, blue: 0.161)
}

struct PomlistBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PomlistPalette.backgroundTop, PomlistPalette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(PomlistPalette.accent.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 18)
                .offset(x: -120, y: -240)

            Circle()
                .fill(Color.white.opacity(0.65))
                .frame(width: 240, height: 240)
                .blur(radius: 12)
                .offset(x: 160, y: -200)

            Circle()
                .fill(PomlistPalette.accentSoft.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 24)
                .offset(x: 140, y: 260)
        }
    }
}

struct GlassCluster<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(spacing: spacing) {
            content
        }
    }
}

struct GlassCard<Content: View>: View {
    let tint: Color
    let cornerRadius: CGFloat
    let padding: CGFloat
    let content: Content

    init(
        tint: Color = PomlistPalette.accent.opacity(0.08),
        cornerRadius: CGFloat = 30,
        padding: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(0.08))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(PomlistPalette.stroke, lineWidth: 1)
                    }
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 18, y: 12)
    }
}

struct GlassPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(PomlistPalette.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(.white.opacity(0.55))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                }
        }
    }
}

struct PrimaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                PomlistPalette.accent.opacity(configuration.isPressed ? 0.78 : 0.96),
                                PomlistPalette.accentSoft.opacity(configuration.isPressed ? 0.74 : 0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.88), value: configuration.isPressed)
    }
}
