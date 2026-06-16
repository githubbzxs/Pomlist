import SwiftUI

struct TaxonomyView: View {
    @EnvironmentObject private var store: PomlistStore
    @Environment(\.dismiss) private var dismiss

    @State private var newCategory = ""
    @State private var newTag = ""

    var body: some View {
        NavigationStack {
            Form {
                TaxonomySection(
                    title: "分类",
                    placeholder: "新增分类",
                    value: $newCategory,
                    items: store.categories,
                    protectedItems: ["默认"],
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
                    addAction: {
                        store.addTag(newTag)
                        newTag = ""
                    },
                    deleteAction: { tag in
                        store.deleteTag(tag)
                    }
                )
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
    var addAction: () -> Void
    var deleteAction: (String) -> Void

    var body: some View {
        Section(title) {
            HStack {
                TextField(placeholder, text: $value)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    addAction()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("新增")
            }

            ForEach(items, id: \.self) { item in
                HStack {
                    Text(item)
                    Spacer()
                    if !protectedItems.contains(item) {
                        Button(role: .destructive) {
                            deleteAction(item)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("删除 \(item)")
                    }
                }
            }
        }
    }
}
