import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var store: PomlistStore

    @State private var editorPresented = false
    @State private var editingTodo: TodoItem?
    @State private var metadataPresented = false

    var body: some View {
        NavigationStack {
            List {
                if pendingTodos.isEmpty && completedTodos.isEmpty {
                    Section {
                        EmptyStateCard(
                            systemImage: "square.and.pencil",
                            title: "任务库还是空的",
                            message: "先添加几个任务，再去 Today 开始任务钟。"
                        )
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }

                if !pendingTodos.isEmpty {
                    Section("待办") {
                        ForEach(pendingTodos) { todo in
                            taskRow(todo)
                        }
                    }
                }

                if !completedTodos.isEmpty {
                    Section("已完成") {
                        ForEach(completedTodos) { todo in
                            taskRow(todo)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PomlistBackground())
            .navigationTitle("Task")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        metadataPresented = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingTodo = nil
                        editorPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $editorPresented) {
                TaskEditorSheet(editingTodo: editingTodo)
            }
            .sheet(isPresented: $metadataPresented) {
                MetadataManagerSheet()
            }
        }
    }

    private var pendingTodos: [TodoItem] {
        store.todos.filter { $0.status == .pending }
    }

    private var completedTodos: [TodoItem] {
        store.todos.filter { $0.status == .completed }
    }

    private func taskRow(_ todo: TodoItem) -> some View {
        Button {
            editingTodo = todo
            editorPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(todo.isCompleted ? PomlistPalette.success : PomlistPalette.secondaryInk)
                        .font(.title3)

                    Text(todo.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(PomlistPalette.ink)

                    Spacer(minLength: 0)
                }

                TaskTagList(category: todo.category, tags: todo.tags)

                if !todo.notes.isEmpty {
                    Text(todo.notes)
                        .font(.subheadline)
                        .foregroundStyle(PomlistPalette.secondaryInk)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                store.toggleTodoCompletion(id: todo.id)
            } label: {
                Label(todo.isCompleted ? "恢复" : "完成", systemImage: todo.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(todo.isCompleted ? .orange : .green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                store.deleteTodo(id: todo.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}
