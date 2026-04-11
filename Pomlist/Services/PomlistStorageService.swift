import Foundation

final class PomlistStorageService {
    private let fileManager: FileManager
    private let databaseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let bundleID = Bundle.main.bundleIdentifier ?? "me.0xpsyche.Pomlist"

        self.databaseURL = appSupportURL
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("pomlist-db.json", isDirectory: false)

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> AppDatabase {
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            let initial = AppDatabase()
            try save(initial)
            return initial
        }

        let data = try Data(contentsOf: databaseURL)
        return try decoder.decode(AppDatabase.self, from: data)
    }

    func save(_ database: AppDatabase) throws {
        let folderURL = databaseURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let data = try encoder.encode(database)
        try data.write(to: databaseURL, options: .atomic)
    }
}
