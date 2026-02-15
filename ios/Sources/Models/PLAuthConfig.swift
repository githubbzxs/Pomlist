import Foundation
import SwiftData

@Model
final class PLAuthConfig {
    @Attribute(.unique) var id: String
    var passcodeHash: String
    var biometricsEnabled: Bool
    var failedAttempts: Int
    var lastUnlockedAt: Date?
    var updatedAt: Date
    var lastMigrationFingerprint: String

    init(
        id: String = "owner-auth",
        passcodeHash: String,
        biometricsEnabled: Bool = true,
        failedAttempts: Int = 0,
        lastUnlockedAt: Date? = nil,
        updatedAt: Date = .now,
        lastMigrationFingerprint: String = ""
    ) {
        self.id = id
        self.passcodeHash = passcodeHash
        self.biometricsEnabled = biometricsEnabled
        self.failedAttempts = failedAttempts
        self.lastUnlockedAt = lastUnlockedAt
        self.updatedAt = updatedAt
        self.lastMigrationFingerprint = lastMigrationFingerprint
    }

    func touch() {
        updatedAt = .now
    }
}
