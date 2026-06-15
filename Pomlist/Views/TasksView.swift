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
            ZStack {
                PomlistTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        ScreenHeader(title: "任务", subtitle: "\(filteredTasks.count) 个匹配项", systemImage: "checklist")

                        HStack(spacing: 12) {
                            Button {
                                showTaxonomy = true
                            } label: {
                                HStack {
                                    Image(systemName: "tag.fill")
                                    Text("分类标签")
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            Spacer(minLength: 0)
                        }

                        VStack(spacing: 12) {
                            SearchField(text: $searchText, placeholder: "搜索标题、备注、分类或标签")
                            StatusFilterBar(selection: $statusFilter)
                            CategoryFilterBar(categories: ["全部"] + store.categories, selection: $categoryFilter)
                        }

                        if filteredTasks.isEmpty {
                            EmptyStateView(systemImage: "tray", title: "没有匹配任务", message: "调整筛选或新增任务。")
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredTasks) { task in
                                    TaskLibraryRow(task: task) {
                                        editingTask = task
                                    }
                                }
                            }
                        }
                    }
                    .pomlistScreenPadding()
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showNewTask = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.86))
                                .frame(width: 60, height: 60)
                                .background(PomlistTheme.accent, in: Circle())
                                .shadow(color: PomlistTheme.accent.opacity(0.28), radius: 18, y: 8)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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

private struct StatusFilterBar: View {
    @Binding var selection: TaskStatus?

    var body: some View {
        HStack(spacing: 8) {
            FilterChip(title: "全部", isSelected: selection == nil) {
                selection = nil
            }
            ForEach(TaskStatus.allCases) { status in
                FilterChip(title: status.title, isSelected: selection == status) {
                    selection = status
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CategoryFilterBar: View {
    var categories: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    FilterChip(title: category, isSelected: selection == category) {
                        selection = category
                    }
                }
            }
        }
    }
}

private struct FilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black.opacity(0.86) : PomlistTheme.secondaryText)
                .padding(.vertical, 9)
                .padding(.horizontal, 12)
                .background(isSelected ? PomlistTheme.accent : PomlistTheme.panel, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct TaskLibraryRow: View {
    @EnvironmentObject private var store: PomlistStore
    var task: PomTask
    var editAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    store.setTaskStatus(task.id, status: task.status == .completed ? .todo : .completed)
                } label: {
                    Image(systemName: task.status.systemImage)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 7) {
                    Text(task.title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(PomlistTheme.text)
                        .lineLimit(2)
                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(PomlistTheme.secondaryText)
                            .lineLimit(3)
                    }
                    HStack(spacing: 8) {
                        Text(task.category)
                            .foregroundStyle(PomlistTheme.categoryColor(task.category))
                        ForEach(task.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .foregroundStyle(PomlistTheme.secondaryText)
                        }
                    }
                    .font(.system(.caption, design: .rounded, weight: .medium))
                }
                Spacer(minLength: 0)
                Menu {
                    Button("编辑") {
                        editAction()
                    }
                    Button(task.status == .archived ? "恢复" : "归档") {
                        store.setTaskStatus(task.id, status: task.status == .archived ? .todo : .archived)
                    }
                    Button(role: .destructive) {
                        store.deleteTask(task.id)
                    } label: {
                        Text("删除")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(PomlistTheme.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(PomlistTheme.panelStrong, in: Circle())
                }
            }
        }
        .padding(16)
        .background(PomlistTheme.panel, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(PomlistTheme.stroke, lineWidth: 1)
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .todo:
            return PomlistTheme.secondaryText
        case .completed:
            return PomlistTheme.accent
        case .archived:
            return PomlistTheme.amber
        }
    }
}
