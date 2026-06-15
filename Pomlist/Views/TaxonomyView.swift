import SwiftUI

struct TaxonomyView: View {
    @EnvironmentObject private var store: PomlistStore
    @Environment(\.dismiss) private var dismiss

    @State private var newCategory = ""
    @State private var newTag = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PomlistTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        TaxonomySection(
                            title: "分类",
                            placeholder: "新增分类",
                            value: $newCategory,
                            items: store.categories,
                            protectedItems: ["默认"],
                            tint: PomlistTheme.accent,
                            addAction: {
                                store.addCategory(newCategory)
                                newCategory = ""
                            },
                            deleteAction: { category in
                                store.deleteCategory(category)
                            }
                        )

                        TaxonomySection(
                            title: "标签",
                            placeholder: "新增标签",
                            value: $newTag,
                            items: store.tags,
                            protectedItems: [],
                            tint: PomlistTheme.blue,
                            addAction: {
                                store.addTag(newTag)
                                newTag = ""
                            },
                            deleteAction: { tag in
                                store.deleteTag(tag)
                            }
                        )
                    }
                    .pomlistScreenPadding()
                }
            }
            .navigationTitle("分类标签")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TaxonomySection: View {
    var title: String
    var placeholder: String
    @Binding var value: String
    var items: [String]
    var protectedItems: Set<String>
    var tint: Color
    var addAction: () -> Void
    var deleteAction: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PomlistTheme.text)

            HStack(spacing: 10) {
                TextField(placeholder, text: $value)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.headline, design: .rounded, weight: .medium))
                    .foregroundStyle(PomlistTheme.text)
                    .padding(13)
                    .background(PomlistTheme.panelStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Button {
                    addAction()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }

            LazyVStack(spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack {
                        Text(item)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(PomlistTheme.text)
                        Spacer()
                        if !protectedItems.contains(item) {
                            Button {
                                deleteAction(item)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(PomlistTheme.rose)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(13)
                    .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(18)
        .glassPanel(cornerRadius: 23, opacity: 0.78)
    }
}
