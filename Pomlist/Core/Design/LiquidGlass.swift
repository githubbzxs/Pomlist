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

extension View {
    @ViewBuilder
    func pomlistGlassSurface<S: Shape>(
        tint: Color,
        in shape: S,
        elevated: Bool = true
    ) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint), in: shape)
                .shadow(
                    color: Color.black.opacity(elevated ? 0.08 : 0),
                    radius: elevated ? 18 : 0,
                    y: elevated ? 12 : 0
                )
        } else {
            self
                .background {
                    shape
                        .fill(.ultraThinMaterial)
                        .overlay {
                            shape.fill(tint.opacity(0.08))
                        }
                        .overlay {
                            shape.stroke(PomlistPalette.stroke, lineWidth: 1)
                        }
                }
                .overlay {
                    shape.stroke(Color.white.opacity(0.28), lineWidth: 0.8)
                }
                .shadow(
                    color: Color.black.opacity(elevated ? 0.08 : 0),
                    radius: elevated ? 18 : 0,
                    y: elevated ? 12 : 0
                )
        }
    }

    @ViewBuilder
    func pomlistInteractiveGlassSurface<S: Shape>(
        tint: Color,
        in shape: S
    ) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint).interactive(), in: shape)
        } else {
            self
        }
    }
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
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: spacing) {
                    VStack(spacing: spacing) {
                        content
                    }
                }
            } else {
                VStack(spacing: spacing) {
                    content
                }
            }
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
            .pomlistGlassSurface(
                tint: tint,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
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
        .pomlistGlassSurface(tint: tint.opacity(0.55), in: Capsule(style: .continuous), elevated: false)
    }
}

struct PrimaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let tint = PomlistPalette.accent.opacity(configuration.isPressed ? 0.76 : 0.92)

        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(PomlistPalette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if #unavailable(iOS 26.0) {
                    shape
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
                        .overlay {
                            shape.stroke(Color.white.opacity(0.18), lineWidth: 1)
                        }
                }
            }
            .pomlistInteractiveGlassSurface(tint: tint, in: shape)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.88), value: configuration.isPressed)
    }
}
