import SwiftData

extension ModelContext {
    func saveIfChanged() throws {
        if hasChanges {
            try save()
        }
    }
}
