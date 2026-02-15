import Foundation
import SwiftData

@Model
final class PLFocusSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var plannedMinutes: Int
    var elapsedSeconds: Int
    var isCancelled: Bool
    var completedTaskCount: Int
    @Relationship(deleteRule: .cascade, inverse: \PLSessionTaskRef.session)
    var taskRefs: [PLSessionTaskRef]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        plannedMinutes: Int = 25,
        elapsedSeconds: Int = 0,
        isCancelled: Bool = false,
        completedTaskCount: Int = 0,
        taskRefs: [PLSessionTaskRef] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedMinutes = plannedMinutes
        self.elapsedSeconds = elapsedSeconds
        self.isCancelled = isCancelled
        self.completedTaskCount = completedTaskCount
        self.taskRefs = taskRefs
    }

    var isActive: Bool {
        endedAt == nil && !isCancelled
    }
}
