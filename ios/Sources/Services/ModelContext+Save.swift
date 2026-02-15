import SwiftData

extension ModelContext {
    func saveIfNeeded() throws {
        if hasChanges {
            try save()
        }
    }
}
