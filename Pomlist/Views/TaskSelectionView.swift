import SwiftUI

struct TaskSelectionView: View {
    @EnvironmentObject private var store: PomlistStore
    @Environment(\.dismiss) private var dismiss

    var mode: Mode
    @State private var selectedIDs: Set<UUID> = []
    @State private var searchText = ""

    enum Mode {
        case start
        case append

        var title: String {
            switch self {
            case .start:
                return "选择本轮任务"
            case .append:
                return "追加任务"
            }
        }

        var actionTitle: String {
            switch self {
            case .start:
                return "开始专注"
            case .append:
                return "追加"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredTasks.isEmpty {
                    ContentUnavailableTaskView(
                        systemImage: "tray",
                        title: "没有可选任务",
                        message: "新增待办后再开始专注。"
                    )
                } else {
                    ForEach(filteredTasks) { task in
                        Button {
                            toggle(task.id)
                        } label: {
                            SelectionTaskRow(task: task, isSelected: selectedIDs.contains(task.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(mode.title)
            .searchable(text: $searchText, prompt: "搜索任务")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("\(mode.actionTitle) · \(selectedIDs.count)") {
                        submit()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }

    private var filteredTasks: [PomTask] {
        var tasks = store.todoTasks
        if mode == .append, let active = store.activeSession {
            let activeTaskIDs = Set(active.tasks.map(\.taskId))
            tasks.removeAll { activeTaskIDs.contains($0.id) }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tasks }
        return tasks.filter { task in
            task.title.localizedCaseInsensitiveContains(query)
                || task.notes.localizedCaseInsensitiveContains(query)
                || task.category.localizedCaseInsensitiveContains(query)
                || task.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func submit() {
        switch mode {
        case .start:
            store.startSession(taskIDs: selectedIDs)
        case .append:
            store.addTasksToActiveSession(taskIDs: selectedIDs)
        }
        dismiss()
    }
}

private struct SelectionTaskRow: View {
    var task: PomTask
    var isSelected: Bool

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                HStack(spacing: 8) {
                    Text(task.category)
                        .foregroundStyle(PomlistStyle.categoryColor(task.category))
                    ForEach(task.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.footnote)
            }
        } icon: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        }
    }
}
