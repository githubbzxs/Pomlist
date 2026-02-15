import SwiftUI

struct PLPanelCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(14)
        .plLiquidGlassCard(cornerRadius: 16, borderOpacity: 0.22, highlightOpacity: 0.14, shadowOpacity: 0.16)
    }
}
