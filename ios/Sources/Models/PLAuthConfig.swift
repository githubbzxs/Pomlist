import Foundation
import SwiftData

@Model
final class PLAuthConfig {
    @Attribute(.unique) var id: UUID
    var passcodeHash: String
    var failedAttempts: Int
    var lastUnlockedAt: Date?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        passcodeHash: String,
        failedAttempts: Int = 0,
        lastUnlockedAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.passcodeHash = passcodeHash
        self.failedAttempts = failedAttempts
        self.lastUnlockedAt = lastUnlockedAt
        self.updatedAt = updatedAt
    }

    func touch() {
        updatedAt = .now
    }
}
