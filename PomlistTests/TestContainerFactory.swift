import SwiftData
@testable import Pomlist

enum TestContainerFactory {
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            TodoItem.self,
            FocusSession.self,
            SessionTaskRef.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
