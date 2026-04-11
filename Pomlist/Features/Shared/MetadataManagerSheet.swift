import SwiftUI

private enum MetadataKind: String, CaseIterable, Identifiable {
    case category
    case tag

    var id: String { rawValue }

    var title: String {
        switch self {
        case .category:
            return "分类"
        case .tag:
            return "标签"
        }
    }

    var inputPlaceholder: String {
        switch self {
        case .category:
            return "输入分类名称"
        case .tag:
            return "输入标签名称"
        }
    }
}

struct MetadataManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PomlistStore

    @State private var kind: MetadataKind = .category
    @State private var input = ""
    @State private var editingValue: String?

    private var items: [String] {
        switch kind {
        case .category:
            return store.categories
        case .tag:
            return store.tags
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("类型") {
                    Picker("元信息", selection: $kind) {
                        ForEach(MetadataKind.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(editingValue == nil ? "新增" : "编辑") {
                    TextField(kind.inputPlaceholder, text: $input)

                    Button(editingValue == nil ? "保存" : "更新") {
                        submit()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("已有\(kind.title)") {
                    if items.isEmpty {
                        Text("当前还没有\(kind.title)可管理。")
                            .foregroundStyle(PomlistPalette.secondaryInk)
                    } else {
                        ForEach(items, id: \.self) { item in
                            Button {
                                editingValue = item
                                input = item
                            } label: {
                                Text(item)
                                    .foregroundStyle(PomlistPalette.ink)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    delete(item)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("管理元信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if editingValue != nil {
                        Button("取消编辑") {
                            editingValue = nil
                            input = ""
                        }
                    }
                }
            }
            .onChange(of: kind) { _, _ in
                editingValue = nil
                input = ""
            }
        }
    }

    private func submit() {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        switch kind {
        case .category:
            if let editingValue {
                store.renameCategory(from: editingValue, to: normalized)
            } else {
                store.addCategory(normalized)
            }
        case .tag:
            if let editingValue {
                store.renameTag(from: editingValue, to: normalized)
            } else {
                store.addTag(normalized)
            }
        }

        editingValue = nil
        input = ""
    }

    private func delete(_ value: String) {
        switch kind {
        case .category:
            store.deleteCategory(value)
        case .tag:
            store.deleteTag(value)
        }
        if editingValue == value {
            editingValue = nil
            input = ""
        }
    }
}
