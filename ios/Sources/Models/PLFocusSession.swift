import Foundation
import SwiftData

@Model
final class PLFocusSession {
    @Attribute(.unique) var id: String
    var state: String
    var startedAt: Date
    var endedAt: Date?
    var elapsedSeconds: Int
    var totalTaskCount: Int
    var completedTaskCount: Int
    var completionRate: Double
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PLSessionTaskRef.session)
    var taskRefs: [PLSessionTaskRef]

    init(
        id: String,
        state: String,
        startedAt: Date,
        endedAt: Date?,
        elapsedSeconds: Int,
        totalTaskCount: Int,
        completedTaskCount: Int,
        completionRate: Double,
        createdAt: Date,
        updatedAt: Date,
        taskRefs: [PLSessionTaskRef] = []
    ) {
        self.id = id
        self.state = state
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.totalTaskCount = max(0, totalTaskCount)
        self.completedTaskCount = max(0, completedTaskCount)
        self.completionRate = min(1, max(0, completionRate))
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.taskRefs = taskRefs
    }

    var isActive: Bool {
        state == "active"
    }
}
