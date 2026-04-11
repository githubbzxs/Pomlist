import SwiftUI

struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PomlistStore

    let editingTodo: TodoItem?

    @State private var draft = TaskDraft()

    init(editingTodo: TodoItem? = nil) {
        self.editingTodo = editingTodo
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务") {
                    TextField("标题", text: $draft.title)
                    TextField("分类", text: $draft.category)
                    TextField("标签，多个用英文逗号分隔", text: $draft.tagsText)
                    TextField("具体内容", text: $draft.notes, axis: .vertical)
                        .lineLimit(4...8)
                }

                if !store.categories.isEmpty || !store.tags.isEmpty {
                    Section("已有元信息") {
                        if !store.categories.isEmpty {
                            LabeledContent("分类建议", value: store.categories.joined(separator: " · "))
                                .font(.caption)
                        }
                        if !store.tags.isEmpty {
                            LabeledContent("标签建议", value: store.tags.joined(separator: " · "))
                                .font(.caption)
                        }
                    }
                }

                if editingTodo != nil {
                    Section {
                        Button("删除任务", role: .destructive) {
                            if let editingTodo {
                                store.deleteTodo(id: editingTodo.id)
                            }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(editingTodo == nil ? "新建任务" : "编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.upsertTodo(draft, editing: editingTodo)
                        dismiss()
                    }
                }
            }
            .onAppear {
                draft = store.draft(for: editingTodo)
            }
        }
    }
}
