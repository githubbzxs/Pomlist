import Foundation
import SwiftData

@MainActor
final class PLServiceHub: ObservableObject {
    @Published private(set) var isReady: Bool = false
    @Published private(set) var isUnlocked: Bool = false
    @Published var unlockError: String?

    private(set) var sessionService: PLSessionService?
    private(set) var todoService: PLTodoService?
    private(set) var analyticsService: PLAnalyticsService?
    private(set) var authService: PLAuthService?
    private(set) var migrationService: PLMigrationService?

    func configure(with modelContext: ModelContext) {
        guard !isReady else { return }

        let todo = PLTodoService(context: modelContext)
        let session = PLSessionService(context: modelContext)
        let analytics = PLAnalyticsService(context: modelContext)
        let auth = PLAuthService(context: modelContext)
        let migration = PLMigrationService(context: modelContext)

        todoService = todo
        sessionService = session
        analyticsService = analytics
        authService = auth
        migrationService = migration

        do {
            try auth.ensureConfigExists()
            _ = try session.loadActiveSession()
            unlockError = nil
        } catch {
            unlockError = "初始化失败: \(error.localizedDescription)"
        }
        isUnlocked = auth.isUnlocked
        isReady = true
    }

    func unlock(passcode: String) {
        guard let authService else { return }
        do {
            let ok = try authService.unlock(passcode: passcode)
            if ok {
                unlockError = nil
            } else {
                unlockError = "口令错误，请重试。"
            }
            isUnlocked = authService.isUnlocked
        } catch {
            unlockError = error.localizedDescription
            isUnlocked = false
        }
    }

    func lock() {
        authService?.lock()
        isUnlocked = false
        unlockError = nil
    }
}
