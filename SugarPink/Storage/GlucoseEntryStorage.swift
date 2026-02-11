import Foundation

extension Notification.Name {
    static let glucoseEntriesDidUpdate = Notification.Name("sugarpink.glucoseEntriesDidUpdate")
}

struct GlucoseEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var date: Date
    var value: Int
    var mealTime: String

    init(id: UUID = UUID(), date: Date, value: Int, mealTime: String) {
        self.id = id
        self.date = date
        self.value = value
        self.mealTime = mealTime
    }
}

enum GlucoseEntryStorage {
    private static let fileName = "glucose_entries.json"
    private static let fileManager = FileManager.default

    private static var fileURL: URL {
        let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    static func load() -> [GlucoseEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([GlucoseEntry].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.date > $1.date }
    }

    static func save(_ entries: [GlucoseEntry]) {
        let data = (try? JSONEncoder().encode(entries)) ?? Data()
        try? data.write(to: fileURL)
    }

    static func append(_ entry: GlucoseEntry) {
        var list = load()
        list.insert(entry, at: 0)
        save(list)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .glucoseEntriesDidUpdate, object: nil)
        }
    }

    static func remove(id: UUID) {
        var list = load()
        list.removeAll { $0.id == id }
        save(list)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .glucoseEntriesDidUpdate, object: nil)
        }
    }

    static func clearAll() {
        save([])
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .glucoseEntriesDidUpdate, object: nil)
        }
    }
}
