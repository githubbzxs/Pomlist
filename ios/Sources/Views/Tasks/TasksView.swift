import SwiftUI

struct TasksView: View {
    @ObservedObject var serviceHub: PLServiceHub

    @State private var todos: [PLTodo] = []
    @State private var editor: TaskEditorState?
    @State private var filter: String = "all"
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Picker("筛选", selection: $filter) {
                    Text("全部").tag("all")
                    Text("待办").tag("pending")
                    Text("已完成").tag("completed")
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                ForEach(filteredTodos, id: \.id) { todo in
                    Button {
                        editor = TaskEditorState(todo: todo)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(todo.isCompleted ? .green : .secondary)
                                .onTapGesture {
                                    toggle(todo)
                                }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(todo.title)
                                    .foregroundStyle(.primary)
                                if !todo.notes.isEmpty {
                                    Text(todo.notes)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                HStack(spacing: 6) {
                                    PLTagBadge(text: todo.category, tint: .indigo)
                                    ForEach(todo.tags, id: \.self) { tag in
                                        PLTagBadge(text: tag, tint: .teal)
                                    }
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(todo)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("任务")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editor = TaskEditorState.new
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear(perform: reload)
            .sheet(item: $editor) { state in
                TaskEditorSheet(state: state) { action in
                    handleEditorAction(action)
                }
            }
            .alert("提示", isPresented: .constant(message != nil), presenting: message) { _ in
                Button("知道了") { message = nil }
            } message: { text in
                Text(text)
            }
        }
    }

    private var filteredTodos: [PLTodo] {
        switch filter {
        case "pending":
            return todos.filter { $0.status == "pending" }
        case "completed":
            return todos.filter { $0.status == "completed" }
        default:
            return todos
        }
    }

    private func reload() {
        do {
            todos = try serviceHub.todoService?.fetchTodos(status: nil) ?? []
        } catch {
            message = error.localizedDescription
        }
    }

    private func toggle(_ todo: PLTodo) {
        do {
            try serviceHub.todoService?.toggleTodo(todo, completed: !todo.isCompleted)
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    private func delete(_ todo: PLTodo) {
        do {
            try serviceHub.todoService?.deleteTodo(todo)
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    private func handleEditorAction(_ action: TaskEditorAction) {
        do {
            switch action {
            case .cancel:
                break
            case let .create(input):
                _ = try serviceHub.todoService?.createTodo(
                    title: input.title,
                    notes: input.notes,
                    category: input.category,
                    tags: input.tags,
                    priority: input.priority,
                    dueAt: input.dueAt
                )
            case let .update(todo, input):
                try serviceHub.todoService?.updateTodo(
                    todo,
                    title: input.title,
                    notes: input.notes,
                    category: input.category,
                    tags: input.tags,
                    priority: input.priority,
                    dueAt: input.dueAt
                )
            }
            reload()
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct TaskEditorInput {
    var title: String
    var notes: String
    var category: String
    var tagsCSV: String
    var priority: Int
    var dueAt: Date?

    var tags: [String] {
        tagsCSV
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private enum TaskEditorAction {
    case cancel
    case create(TaskEditorInput)
    case update(PLTodo, TaskEditorInput)
}

private struct TaskEditorState: Identifiable {
    let id = UUID()
    let sourceTodo: PLTodo?

    static var new: TaskEditorState {
        TaskEditorState(sourceTodo: nil)
    }

    init(todo: PLTodo) {
        sourceTodo = todo
    }

    init(sourceTodo: PLTodo?) {
        self.sourceTodo = sourceTodo
    }
}

private struct TaskEditorSheet: View {
    let state: TaskEditorState
    let onFinish: (TaskEditorAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var notes: String
    @State private var category: String
    @State private var tagsCSV: String
    @State private var priority: Int
    @State private var dueAtEnabled: Bool
    @State private var dueAt: Date

    init(state: TaskEditorState, onFinish: @escaping (TaskEditorAction) -> Void) {
        self.state = state
        self.onFinish = onFinish

        let todo = state.sourceTodo
        _title = State(initialValue: todo?.title ?? "")
        _notes = State(initialValue: todo?.notes ?? "")
        _category = State(initialValue: todo?.category ?? "未分类")
        _tagsCSV = State(initialValue: todo?.tags.joined(separator: ",") ?? "")
        _priority = State(initialValue: todo?.priority ?? 2)
        _dueAtEnabled = State(initialValue: todo?.dueAt != nil)
        _dueAt = State(initialValue: todo?.dueAt ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    TextField("具体内容", text: $notes, axis: .vertical)
                        .lineLimit(3 ... 6)
                    TextField("分类", text: $category)
                    TextField("标签（逗号分隔）", text: $tagsCSV)
                }

                Section("优先级") {
                    Picker("优先级", selection: $priority) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("3").tag(3)
                    }
                    .pickerStyle(.segmented)
                }

                Section("截止时间") {
                    Toggle("启用截止时间", isOn: $dueAtEnabled.animation())
                    if dueAtEnabled {
                        DatePicker("截止时间", selection: $dueAt, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle(state.sourceTodo == nil ? "新建任务" : "编辑任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onFinish(.cancel)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let input = TaskEditorInput(
                            title: title,
                            notes: notes,
                            category: category,
                            tagsCSV: tagsCSV,
                            priority: priority,
                            dueAt: dueAtEnabled ? dueAt : nil
                        )

                        if let todo = state.sourceTodo {
                            onFinish(.update(todo, input))
                        } else {
                            onFinish(.create(input))
                        }

                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
