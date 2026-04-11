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
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.62))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                }
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
                    .background(Capsule().fill(PomlistPalette.accent.opacity(0.12)))

                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PomlistPalette.secondaryInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.65)))
                }
            }
        }
    }
}
