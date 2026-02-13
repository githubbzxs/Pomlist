import SwiftUI
import SwiftData

struct TodoEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: TodoItem?
    let onSaved: () -> Void

    @State private var title: String
    @State private var subject: String
    @State private var notes: String
    @State private var priority: TodoPriority
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var errorMessage: String?

    init(item: TodoItem?, onSaved: @escaping () -> Void) {
        self.item = item
        self.onSaved = onSaved
        _title = State(initialValue: item?.title ?? "")
        _subject = State(initialValue: item?.subject ?? "")
        _notes = State(initialValue: item?.notes ?? "")
        _priority = State(initialValue: item?.priority ?? .medium)
        _hasDueDate = State(initialValue: item?.dueAt != nil)
        _dueDate = State(initialValue: item?.dueAt ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务信息") {
                    TextField("标题", text: $title)
                    TextField("科目（可选）", text: $subject)
                    TextField("备注（可选）", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("优先级") {
                    Picker("优先级", selection: $priority) {
                        ForEach(TodoPriority.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("截止时间") {
                    Toggle("启用截止时间", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("截止时间", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle(item == nil ? "新建任务" : "编辑任务")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        save()
                    }
                }
            }
            .alert(
                "保存失败",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("知道了", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        let draft = TodoDraft(
            title: title,
            subject: subject,
            notes: notes,
            priority: priority,
            dueAt: hasDueDate ? dueDate : nil
        )

        do {
            if let item {
                try TodoService.updateTodo(item, with: draft, context: modelContext)
            } else {
                _ = try TodoService.createTodo(from: draft, context: modelContext)
            }
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

