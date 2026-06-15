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
            ZStack {
                PomlistTheme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    SearchField(text: $searchText, placeholder: "搜索任务")
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTasks) { task in
                                SelectionTaskRow(task: task, isSelected: selectedIDs.contains(task.id)) {
                                    toggle(task.id)
                                }
                            }
                        }
                        .padding(.bottom, 90)
                    }
                }
                .pomlistScreenPadding()

                VStack {
                    Spacer()
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Image(systemName: mode == .start ? "play.fill" : "plus")
                            Text("\(mode.actionTitle) · \(selectedIDs.count)")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedIDs.isEmpty)
                    .opacity(selectedIDs.isEmpty ? 0.48 : 1)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
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
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isSelected ? PomlistTheme.accent : PomlistTheme.secondaryText)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 7) {
                    Text(task.title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(PomlistTheme.text)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text(task.category)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(PomlistTheme.categoryColor(task.category))
                        ForEach(task.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(PomlistTheme.secondaryText)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(isSelected ? PomlistTheme.accent.opacity(0.11) : PomlistTheme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? PomlistTheme.accent.opacity(0.42) : PomlistTheme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PomlistTheme.secondaryText)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(PomlistTheme.text)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PomlistTheme.secondaryText)
                }
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(PomlistTheme.panelStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
