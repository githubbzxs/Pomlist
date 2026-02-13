import Foundation

enum RootTab: Hashable {
    case today
    case todo
    case focus
    case analytics
}

final class AppState: ObservableObject {
    @Published var selectedTab: RootTab = .today
    @Published var activeSessionID: UUID?
    @Published var sessionErrorMessage: String?
}

