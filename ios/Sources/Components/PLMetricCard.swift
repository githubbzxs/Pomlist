import SwiftUI

struct PLMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .contentTransition(.numericText())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plLiquidGlassCard(cornerRadius: 12, borderOpacity: 0.2, highlightOpacity: 0.1, shadowOpacity: 0.12)
    }
}
