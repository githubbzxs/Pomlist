import SwiftData
import SwiftUI

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    @Query(sort: [SortDescriptor(\TodoItem.createdAt, order: .reverse)])
    private var todos: [TodoItem]

    @State private var selectedTodoIDs: Set<UUID> = []
    @State private var editingTodo: TodoItem?
    @State private var showingEditor = false
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("待办任务") {
                    if pendingTodos.isEmpty {
                        Text("还没有待办任务，先创建一个吧。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pendingTodos, id: \.id) { todo in
                            TodoRowView(todo: todo, isSelectedForSession: selectedTodoIDs.contains(todo.id))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleSelection(for: todo)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("完成") {
                                        mark(todo: todo, completed: true)
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .leading) {
                                    Button("编辑") {
                                        openEditor(for: todo)
                                    }
                                    .tint(.blue)
                                }
                                .contextMenu {
                                    Button("编辑任务") {
                                        openEditor(for: todo)
                                    }
                                    Button("删除任务", role: .destructive) {
                                        delete(todo: todo)
                                    }
                                }
                        }
                    }
                }

                Section("已完成") {
                    if completedTodos.isEmpty {
                        Text("完成的任务会显示在这里。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(completedTodos, id: \.id) { todo in
                            TodoRowView(todo: todo, isSelectedForSession: false)
                                .swipeActions {
                                    Button("恢复") {
                                        mark(todo: todo, completed: false)
                                    }
                                    .tint(.orange)
                                }
                                .contextMenu {
                                    Button("删除任务", role: .destructive) {
                                        delete(todo: todo)
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("To-Do")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingTodo = nil
                        showingEditor = true
                    } label: {
                        Label("新建任务", systemImage: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selectedTodoIDs.isEmpty {
                    Button {
                        startSession()
                    } label: {
                        Text("开始任务钟（\(selectedTodoIDs.count) 项）")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)
                    .disabled(appState.activeSessionID != nil)
                }
            }
            .sheet(isPresented: $showingEditor) {
                TodoEditorSheet(item: editingTodo) { }
            }
            .alert(
                "操作失败",
                isPresented: Binding(
                    get: { localError != nil },
                    set: { isPresented in
                        if !isPresented {
                            localError = nil
                        }
                    }
                )
            ) {
                Button("知道了", role: .cancel) {
                    localError = nil
                }
            } message: {
                Text(localError ?? "")
            }
        }
    }

    private var pendingTodos: [TodoItem] {
        todos
            .filter { $0.status == .pending }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority.rawValue > rhs.priority.rawValue
                }
                switch (lhs.dueAt, rhs.dueAt) {
                case let (l?, r?):
                    return l < r
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.createdAt < rhs.createdAt
                }
            }
    }

    private var completedTodos: [TodoItem] {
        todos
            .filter { $0.status == .completed }
            .sorted { lhs, rhs in
                (lhs.completedAt ?? lhs.updatedAt) > (rhs.completedAt ?? rhs.updatedAt)
            }
    }

    private func toggleSelection(for todo: TodoItem) {
        guard todo.status == .pending else { return }
        if selectedTodoIDs.contains(todo.id) {
            selectedTodoIDs.remove(todo.id)
        } else {
            selectedTodoIDs.insert(todo.id)
        }
    }

    private func mark(todo: TodoItem, completed: Bool) {
        do {
            try TodoService.setCompleted(todo, isCompleted: completed, context: modelContext)
            if completed {
                selectedTodoIDs.remove(todo.id)
            }
        } catch {
            localError = error.localizedDescription
        }
    }

    private func openEditor(for todo: TodoItem) {
        editingTodo = todo
        showingEditor = true
    }

    private func delete(todo: TodoItem) {
        selectedTodoIDs.remove(todo.id)
        modelContext.delete(todo)
        do {
            try modelContext.save()
        } catch {
            localError = error.localizedDescription
        }
    }

    private func startSession() {
        do {
            let session = try SessionService.startSession(todoIDs: Array(selectedTodoIDs), context: modelContext)
            appState.activeSessionID = session.id
            appState.selectedTab = .focus
            selectedTodoIDs.removeAll()
        } catch {
            localError = error.localizedDescription
        }
    }
}
