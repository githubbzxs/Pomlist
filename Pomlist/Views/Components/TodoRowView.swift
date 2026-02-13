import SwiftUI

struct TodoRowView: View {
    let todo: TodoItem
    let isSelectedForSession: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(todo.title)
                    .font(.headline)
                    .foregroundStyle(todo.status == .completed ? .secondary : .primary)
                    .strikethrough(todo.status == .completed)

                HStack(spacing: 8) {
                    Text("优先级 \(todo.priority.title)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())

                    if let subject = todo.subject {
                        Text(subject)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())
                    }
                }

                if let dueAt = todo.dueAt {
                    Text("截止 \(DateTextFormatter.dayTime(dueAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        if todo.status == .completed {
            return "checkmark.circle.fill"
        }
        return isSelectedForSession ? "circle.inset.filled" : "circle"
    }

    private var iconColor: Color {
        if todo.status == .completed {
            return .green
        }
        return isSelectedForSession ? .blue : .secondary
    }
}

