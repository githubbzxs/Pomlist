import SwiftUI

struct TaskPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PomlistStore

    let title: String
    let submitTitle: String
    let excludedTodoIDs: Set<String>
    let onSubmit: ([String]) -> Void

    @State private var selection = Set<String>()

    private var availableTodos: [TodoItem] {
        store.todos.filter { $0.status != .archived && !excludedTodoIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List(availableTodos) { todo in
                Button {
                    if selection.contains(todo.id) {
                        selection.remove(todo.id)
                    } else {
                        selection.insert(todo.id)
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: selection.contains(todo.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection.contains(todo.id) ? PomlistPalette.accent : PomlistPalette.secondaryInk)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(todo.title)
                                .foregroundStyle(PomlistPalette.ink)
                            TaskTagList(category: todo.category, tags: todo.tags)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(submitTitle) {
                        onSubmit(Array(selection))
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
            .overlay {
                if availableTodos.isEmpty {
                    EmptyStateCard(
                        systemImage: "square.stack.3d.up.slash",
                        title: "暂无可选任务",
                        message: "先去 Task 页添加任务，再回来开始本轮专注。"
                    )
                    .padding(24)
                }
            }
        }
    }
}
