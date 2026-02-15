import CryptoKit
import Foundation
import LocalAuthentication
import SwiftData

@MainActor
final class PLAuthService: AuthUnlocking {
    private let context: ModelContext
    private(set) var isUnlocked: Bool = false
    private(set) var isBiometricAvailable: Bool = false

    init(context: ModelContext) {
        self.context = context
        self.isBiometricAvailable = Self.supportsBiometricAuth()
    }

    func ensureConfigExists() throws {
        if try authConfig() == nil {
            let config = PLAuthConfig(passcodeHash: hash("0xbp"))
            context.insert(config)
            try context.saveIfChanged()
        }
    }

    func unlock(passcode: String) throws -> Bool {
        guard let config = try authConfig() else {
            try ensureConfigExists()
            return try unlock(passcode: passcode)
        }

        if hash(passcode) == config.passcodeHash {
            config.failedAttempts = 0
            config.lastUnlockedAt = Date()
            config.touch()
            isUnlocked = true
            try context.saveIfChanged()
            return true
        }

        config.failedAttempts += 1
        config.touch()
        try context.saveIfChanged()
        throw PLServiceError.invalidPasscode
    }

    func unlockWithBiometrics() async throws -> Bool {
        guard Self.supportsBiometricAuth() else {
            return false
        }

        let authContext = LAContext()
        authContext.localizedCancelTitle = "改用口令"
        let reason = "解锁 Pomlist"

        return try await withCheckedThrowingContinuation { continuation in
            authContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, error in
                Task { @MainActor in
                    guard let self else {
                        continuation.resume(returning: false)
                        return
                    }

                    if success {
                        if let config = try? self.authConfig() {
                            config.failedAttempts = 0
                            config.lastUnlockedAt = Date()
                            config.touch()
                            try? self.context.saveIfChanged()
                        }
                        self.isUnlocked = true
                        continuation.resume(returning: true)
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    func updatePasscode(oldPasscode: String, newPasscode: String) throws {
        guard newPasscode.count == 4 else {
            throw PLServiceError.invalidPasscode
        }

        guard let config = try authConfig() else {
            throw PLServiceError.invalidPasscode
        }

        guard hash(oldPasscode) == config.passcodeHash else {
            throw PLServiceError.passcodeMismatch
        }

        config.passcodeHash = hash(newPasscode)
        config.touch()
        try context.saveIfChanged()
    }

    func lock() {
        isUnlocked = false
    }

    func currentConfig() throws -> PLAuthConfig? {
        try authConfig()
    }

    private func authConfig() throws -> PLAuthConfig? {
        var descriptor = FetchDescriptor<PLAuthConfig>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func hash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func supportsBiometricAuth() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}
