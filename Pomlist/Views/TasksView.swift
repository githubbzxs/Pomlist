import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var store: PomlistStore
    @State private var statusFilter: TaskStatus? = .todo
    @State private var categoryFilter: String = "全部"
    @State private var searchText = ""
    @State private var editingTask: PomTask?
    @State private var showNewTask = false
    @State private var showTaxonomy = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("状态", selection: $statusFilter) {
                        Text("全部").tag(nil as TaskStatus?)
                        ForEach(TaskStatus.allCases) { status in
                            Text(status.title).tag(status as TaskStatus?)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("分类", selection: $categoryFilter) {
                        ForEach(["全部"] + store.categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }

                Section {
                    if filteredTasks.isEmpty {
                        ContentUnavailableTaskView(
                            systemImage: "tray",
                            title: "没有匹配任务",
                            message: "调整筛选或新增任务。"
                        )
                    } else {
                        ForEach(filteredTasks) { task in
                            TaskLibraryRow(task: task) {
                                editingTask = task
                            }
                        }
                    }
                } header: {
                    Text("\(filteredTasks.count) 个匹配项")
                }
            }
            .navigationTitle("任务")
            .searchable(text: $searchText, prompt: "搜索任务")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showTaxonomy = true
                    } label: {
                        Image(systemName: "tag")
                    }
                    .accessibilityLabel("分类标签")

                    Button {
                        showNewTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新增任务")
                }
            }
        }
        .sheet(item: $editingTask) { task in
            TaskEditorView(task: task)
                .environmentObject(store)
        }
        .sheet(isPresented: $showNewTask) {
            TaskEditorView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showTaxonomy) {
            TaxonomyView()
                .environmentObject(store)
        }
    }

    private var filteredTasks: [PomTask] {
        store.data.tasks
            .filter { task in
                if let statusFilter, task.status != statusFilter {
                    return false
                }
                if categoryFilter != "全部", task.category != categoryFilter {
                    return false
                }
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return true }
                return task.title.localizedCaseInsensitiveContains(query)
                    || task.notes.localizedCaseInsensitiveContains(query)
                    || task.category.localizedCaseInsensitiveContains(query)
                    || task.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
}

private struct TaskLibraryRow: View {
    @EnvironmentObject private var store: PomlistStore
    var task: PomTask
    var editAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.setTaskStatus(task.id, status: task.status == .completed ? .todo : .completed)
            } label: {
                Image(systemName: task.status.systemImage)
                    .foregroundStyle(statusColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.status == .completed ? "标为待办" : "标为完成")

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .strikethrough(task.status == .completed)
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                HStack(spacing: 8) {
                    Text(task.category)
                        .foregroundStyle(PomlistStyle.categoryColor(task.category))
                    ForEach(task.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.footnote)
            }

            Spacer(minLength: 0)

            Menu {
                Button("编辑") {
                    editAction()
                }
                Button(task.status == .archived ? "恢复" : "归档") {
                    store.setTaskStatus(task.id, status: task.status == .archived ? .todo : .archived)
                }
                Button("删除", role: .destructive) {
                    store.deleteTask(task.id)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .todo:
            return .secondary
        case .completed:
            return .accentColor
        case .archived:
            return .orange
        }
    }
}
