import Foundation
import SwiftData

@MainActor
final class PLServiceHub: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var isUnlocked = false
    @Published var unlockError: String?
    @Published var migrationReport: PLMigrationReport?

    private(set) var todoService: PLTodoService?
    private(set) var sessionService: PLSessionService?
    private(set) var analyticsService: PLAnalyticsService?
    private(set) var authService: PLAuthService?
    private(set) var migrationService: PLMigrationService?

    func configure(with context: ModelContext) {
        guard !isReady else { return }

        let todoService = PLTodoService(context: context)
        let sessionService = PLSessionService(context: context)
        let analyticsService = PLAnalyticsService(context: context)
        let authService = PLAuthService(context: context)
        let migrationService = PLMigrationService(context: context)

        self.todoService = todoService
        self.sessionService = sessionService
        self.analyticsService = analyticsService
        self.authService = authService
        self.migrationService = migrationService

        do {
            try authService.ensureConfigExists()
            unlockError = nil
        } catch {
            unlockError = error.localizedDescription
        }

        isReady = true
        isUnlocked = false
    }

    var isBiometricAvailable: Bool {
        authService?.isBiometricAvailable ?? false
    }

    func unlock(passcode: String) {
        guard let authService else { return }
        do {
            isUnlocked = try authService.unlock(passcode: passcode)
            unlockError = nil
        } catch {
            unlockError = error.localizedDescription
            isUnlocked = false
        }
    }

    func attemptBiometricUnlockIfEnabled() async {
        guard let authService else { return }
        guard authService.isBiometricAvailable else { return }
        _ = try? await attemptBiometricUnlock()
    }

    @discardableResult
    func attemptBiometricUnlock() async throws -> Bool {
        guard let authService else { return false }
        do {
            let success = try await authService.unlockWithBiometrics()
            isUnlocked = success
            if success {
                unlockError = nil
            }
            return success
        } catch {
            unlockError = error.localizedDescription
            isUnlocked = false
            throw error
        }
    }

    func lock() {
        authService?.lock()
        isUnlocked = false
        unlockError = nil
    }

    func changePasscode(oldPasscode: String, newPasscode: String) throws {
        guard let authService else { return }
        try authService.updatePasscode(oldPasscode: oldPasscode, newPasscode: newPasscode)
    }

    func importMigration(from url: URL) throws {
        guard let migrationService else { return }
        let report = try migrationService.importMigrationFile(from: url)
        migrationReport = report
    }
}
