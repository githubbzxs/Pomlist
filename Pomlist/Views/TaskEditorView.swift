import SwiftUI

struct TaskEditorView: View {
    @EnvironmentObject private var store: PomlistStore
    @Environment(\.dismiss) private var dismiss

    var task: PomTask?
    @State private var title: String
    @State private var notes: String
    @State private var category: String
    @State private var tagsText: String

    init(task: PomTask? = nil) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _category = State(initialValue: task?.category ?? "默认")
        _tagsText = State(initialValue: task?.tags.joined(separator: " ") ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务") {
                    TextField("标题", text: $title)
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("归类") {
                    TextField("分类", text: $category)
                    if !store.categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.categories, id: \.self) { item in
                                    Button(item) {
                                        category = item
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    TextField("标签，以空格分隔", text: $tagsText)
                    if !store.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.tags, id: \.self) { tag in
                                    Button("#\(tag)") {
                                        toggleTag(tag)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PomlistTheme.background)
            .navigationTitle(task == nil ? "新增任务" : "编辑任务")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let tags = tagsText
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "，" })
            .map(String.init)
        if let task {
            store.updateTask(task, title: title, notes: notes, category: category, tags: tags)
        } else {
            store.addTask(title: title, notes: notes, category: category, tags: tags)
        }
        dismiss()
    }

    private func toggleTag(_ tag: String) {
        var tags = Set(
            tagsText
                .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "，" })
                .map(String.init)
        )
        if tags.contains(tag) {
            tags.remove(tag)
        } else {
            tags.insert(tag)
        }
        tagsText = tags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.joined(separator: " ")
    }
}
