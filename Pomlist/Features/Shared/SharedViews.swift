import SwiftUI

struct SectionTitle: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(PomlistPalette.accent)

            Text(title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(PomlistPalette.ink)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(PomlistPalette.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetricCell: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(PomlistPalette.secondaryInk)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(PomlistPalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .pomlistGlassSurface(
            tint: tint.opacity(0.45),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            elevated: false
        )
    }
}

struct EmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        GlassCard(tint: Color.white.opacity(0.18)) {
            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(PomlistPalette.accent)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PomlistPalette.ink)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PomlistPalette.secondaryInk)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct TaskTagList: View {
    let category: String
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text(category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PomlistPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .pomlistGlassSurface(
                        tint: PomlistPalette.accent.opacity(0.5),
                        in: Capsule(),
                        elevated: false
                    )

                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PomlistPalette.secondaryInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .pomlistGlassSurface(
                            tint: Color.white.opacity(0.42),
                            in: Capsule(),
                            elevated: false
                        )
                }
            }
        }
    }
}
