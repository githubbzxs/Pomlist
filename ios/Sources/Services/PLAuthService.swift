import CryptoKit
import Foundation
import SwiftData

@MainActor
final class PLAuthService: ObservableObject, AuthUnlocking {
    @Published private(set) var isUnlocked: Bool = false
    private let context: ModelContext
    private let defaultPasscode = "0xbp"

    init(context: ModelContext) {
        self.context = context
    }

    func ensureConfigExists() throws {
        let descriptor = FetchDescriptor<PLAuthConfig>()
        let existing = try context.fetch(descriptor)
        guard existing.isEmpty else { return }

        let config = PLAuthConfig(passcodeHash: hash(defaultPasscode))
        context.insert(config)
        try context.saveIfNeeded()
    }

    func unlock(passcode: String) throws -> Bool {
        guard passcode.count == 4 else {
            throw PLServiceError.invalidPasscodeFormat
        }

        let config = try requireConfig()
        if config.passcodeHash == hash(passcode) {
            config.failedAttempts = 0
            config.lastUnlockedAt = .now
            config.touch()
            try context.saveIfNeeded()
            isUnlocked = true
            return true
        }

        config.failedAttempts += 1
        config.touch()
        try context.saveIfNeeded()
        isUnlocked = false
        return false
    }

    func updatePasscode(oldPasscode: String, newPasscode: String) throws {
        guard oldPasscode.count == 4, newPasscode.count == 4 else {
            throw PLServiceError.invalidPasscodeFormat
        }
        guard oldPasscode != newPasscode else {
            throw PLServiceError.passcodeUnchanged
        }

        let config = try requireConfig()
        guard config.passcodeHash == hash(oldPasscode) else {
            throw PLServiceError.passcodeMismatch
        }

        config.passcodeHash = hash(newPasscode)
        config.touch()
        try context.saveIfNeeded()
    }

    func lock() {
        isUnlocked = false
    }

    private func requireConfig() throws -> PLAuthConfig {
        var descriptor = FetchDescriptor<PLAuthConfig>()
        descriptor.fetchLimit = 1
        guard let config = try context.fetch(descriptor).first else {
            throw PLServiceError.missingAuthConfig
        }
        return config
    }

    private func hash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
