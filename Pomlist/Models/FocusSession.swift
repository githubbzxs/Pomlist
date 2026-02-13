import Foundation
import SwiftData

@Model
final class FocusSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var elapsedSeconds: Int
    var stateValue: String
    var totalTaskCount: Int
    var completedTaskCount: Int

    @Relationship(deleteRule: .cascade, inverse: \SessionTaskRef.session)
    var taskRefs: [SessionTaskRef]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        elapsedSeconds: Int = 0,
        state: SessionState = .active,
        totalTaskCount: Int,
        completedTaskCount: Int = 0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.elapsedSeconds = elapsedSeconds
        self.stateValue = state.rawValue
        self.totalTaskCount = totalTaskCount
        self.completedTaskCount = completedTaskCount
        self.taskRefs = []
    }

    var state: SessionState {
        get { SessionState(rawValue: stateValue) ?? .active }
        set { stateValue = newValue.rawValue }
    }

    var completionRate: Double {
        guard totalTaskCount > 0 else { return 0 }
        return Double(completedTaskCount) / Double(totalTaskCount)
    }
}

