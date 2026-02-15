import SwiftData
import SwiftUI

struct TasksView: View {
    let todoService: PLTodoService

    @Query(
        sort: [
            SortDescriptor(\PLTodo.isDone),
            SortDescriptor(\PLTodo.updatedAt, order: .reverse)
        ]
    )
    private var todos: [PLTodo]

    @State private var titleInput: String = ""
    @State private var detailInput: String = ""
    @State private var categoryInput: String = ""
    @State private var tagsInput: String = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PLPanelCard(title: "新增任务") {
                        VStack(spacing: 10) {
                            TextField("标题", text: $titleInput)
                                .textFieldStyle(.roundedBorder)
                            TextField("具体内容（可选）", text: $detailInput, axis: .vertical)
                                .lineLimit(2 ... 4)
                                .textFieldStyle(.roundedBorder)
                            TextField("分类（可选）", text: $categoryInput)
                                .textFieldStyle(.roundedBorder)
                            TextField("标签，逗号分隔（可选）", text: $tagsInput)
                                .textFieldStyle(.roundedBorder)

                            Button("添加任务") {
                                createTodo()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(titleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    PLPanelCard(title: "任务列表") {
                        if todos.isEmpty {
                            Text("暂无任务。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(todos) { todo in
                                    todoRow(todo)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Tasks")
            .alert("提示", isPresented: .constant(message != nil), presenting: message) { _ in
                Button("我知道了") { message = nil }
            } message: { text in
                Text(text)
            }
        }
    }

    private func todoRow(_ todo: PLTodo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    toggle(todo)
                } label: {
                    Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(todo.isDone ? .green : .secondary)
                }
                .buttonStyle(.plain)

                Text(todo.title)
                    .font(.body)
                    .strikethrough(todo.isDone, color: .secondary)
                    .foregroundStyle(todo.isDone ? .secondary : .primary)

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    delete(todo)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            if !todo.detail.isEmpty {
                Text(todo.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                if !todo.category.isEmpty {
                    PLTagBadge(text: todo.category, tint: .indigo)
                }
                ForEach(todo.tags, id: \.self) { tag in
                    PLTagBadge(text: tag, tint: .teal)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }

    private func createTodo() {
        do {
            _ = try todoService.createTodo(
                title: titleInput,
                detail: detailInput,
                category: categoryInput,
                tags: tagsInput
                    .split(separator: ",")
                    .map(String.init)
            )
            titleInput = ""
            detailInput = ""
            categoryInput = ""
            tagsInput = ""
        } catch {
            message = error.localizedDescription
        }
    }

    private func toggle(_ todo: PLTodo) {
        do {
            try todoService.toggleTodo(todo)
        } catch {
            message = error.localizedDescription
        }
    }

    private func delete(_ todo: PLTodo) {
        do {
            try todoService.deleteTodo(todo)
        } catch {
            message = error.localizedDescription
        }
    }
}
