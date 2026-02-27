import Foundation

protocol RecentItemsStorage {
    func readRecentItems() -> [LaunchItem]
    func writeRecentItems(_ items: [LaunchItem])
    func markLaunched(_ item: LaunchItem, at date: Date)
    func recentItems(from items: [LaunchItem], limit: Int) -> [LaunchItem]
    func frequentItems(from items: [LaunchItem], limit: Int) -> [LaunchItem]
    func snapshot(for item: LaunchItem) -> LaunchHistorySnapshot?
    func clearHistory()
}

struct LaunchHistorySnapshot: Equatable, Hashable, Codable {
    var lastLaunchedAt: Date
    var launchCount: Int
}

final class InMemoryRecentItemsStorage: RecentItemsStorage {
    private var entriesByIdentifier: [String: LaunchHistoryEntry] = [:]

    func readRecentItems() -> [LaunchItem] {
        sortedEntriesByRecent().map(\.asLaunchItem)
    }

    func writeRecentItems(_ items: [LaunchItem]) {
        entriesByIdentifier = Self.entriesFromRecentItems(items)
    }

    func markLaunched(_ item: LaunchItem, at date: Date = Date()) {
        let key = Self.identifier(for: item)
        if var entry = entriesByIdentifier[key] {
            entry.title = item.title
            entry.bundleIdentifier = item.bundleIdentifier
            entry.bundleURL = nil
            entry.lastLaunchedAt = date
            entry.launchCount += 1
            entriesByIdentifier[key] = entry
            return
        }

        entriesByIdentifier[key] = LaunchHistoryEntry(
            identifier: key,
            title: item.title,
            bundleIdentifier: item.bundleIdentifier,
            bundleURL: nil,
            lastLaunchedAt: date,
            launchCount: 1
        )
    }

    func recentItems(from items: [LaunchItem], limit: Int = 12) -> [LaunchItem] {
        merge(entries: sortedEntriesByRecent(), with: items, limit: limit)
    }

    func frequentItems(from items: [LaunchItem], limit: Int = 12) -> [LaunchItem] {
        merge(entries: sortedEntriesByFrequency(), with: items, limit: limit)
    }

    func snapshot(for item: LaunchItem) -> LaunchHistorySnapshot? {
        guard let entry = entriesByIdentifier[Self.identifier(for: item)] else {
            return nil
        }
        return LaunchHistorySnapshot(lastLaunchedAt: entry.lastLaunchedAt, launchCount: entry.launchCount)
    }

    func clearHistory() {
        entriesByIdentifier.removeAll()
    }

    private func merge(entries: [LaunchHistoryEntry], with items: [LaunchItem], limit: Int) -> [LaunchItem] {
        let positiveLimit = max(0, limit)
        guard positiveLimit > 0 else {
            return []
        }

        var itemMap: [String: LaunchItem] = [:]
        for item in items {
            itemMap[Self.identifier(for: item)] = item
        }
        var result: [LaunchItem] = []
        result.reserveCapacity(min(positiveLimit, entries.count))
        for entry in entries {
            if result.count >= positiveLimit {
                break
            }
            if let matched = itemMap[entry.identifier] {
                result.append(matched)
            } else {
                result.append(entry.asLaunchItem)
            }
        }
        return result
    }

    private func sortedEntriesByRecent() -> [LaunchHistoryEntry] {
        entriesByIdentifier.values.sorted { lhs, rhs in
            if lhs.lastLaunchedAt != rhs.lastLaunchedAt {
                return lhs.lastLaunchedAt > rhs.lastLaunchedAt
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private func sortedEntriesByFrequency() -> [LaunchHistoryEntry] {
        entriesByIdentifier.values.sorted { lhs, rhs in
            if lhs.launchCount != rhs.launchCount {
                return lhs.launchCount > rhs.launchCount
            }
            if lhs.lastLaunchedAt != rhs.lastLaunchedAt {
                return lhs.lastLaunchedAt > rhs.lastLaunchedAt
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    fileprivate static func identifier(for item: LaunchItem) -> String {
        item.stableIdentifier
    }

    fileprivate static func entriesFromRecentItems(_ items: [LaunchItem]) -> [String: LaunchHistoryEntry] {
        let now = Date()
        var entries: [String: LaunchHistoryEntry] = [:]
        for (offset, item) in items.enumerated() {
            let key = identifier(for: item)
            let launchedAt = now.addingTimeInterval(-Double(offset))
            let entry = LaunchHistoryEntry(
                identifier: key,
                title: item.title,
                bundleIdentifier: item.bundleIdentifier,
                bundleURL: nil,
                lastLaunchedAt: launchedAt,
                launchCount: 1
            )
            entries[key] = entry
        }
        return entries
    }
}

final class UserDefaultsRecentItemsStorage: RecentItemsStorage {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "launchmenu.recentHistory.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func readRecentItems() -> [LaunchItem] {
        loadEntries()
            .values
            .sorted(by: Self.recentSort)
            .map(\.asLaunchItem)
    }

    func writeRecentItems(_ items: [LaunchItem]) {
        let entries = InMemoryRecentItemsStorage.entriesFromRecentItems(items)
        saveEntries(entries)
    }

    func markLaunched(_ item: LaunchItem, at date: Date = Date()) {
        var entries = loadEntries()
        let key = InMemoryRecentItemsStorage.identifier(for: item)
        if var entry = entries[key] {
            entry.title = item.title
            entry.bundleIdentifier = item.bundleIdentifier
            entry.bundleURL = nil
            entry.lastLaunchedAt = date
            entry.launchCount += 1
            entries[key] = entry
        } else {
            entries[key] = LaunchHistoryEntry(
                identifier: key,
                title: item.title,
                bundleIdentifier: item.bundleIdentifier,
                bundleURL: nil,
                lastLaunchedAt: date,
                launchCount: 1
            )
        }
        saveEntries(entries)
    }

    func recentItems(from items: [LaunchItem], limit: Int = 12) -> [LaunchItem] {
        merge(
            entries: loadEntries().values.sorted(by: Self.recentSort),
            with: items,
            limit: limit
        )
    }

    func frequentItems(from items: [LaunchItem], limit: Int = 12) -> [LaunchItem] {
        merge(
            entries: loadEntries().values.sorted(by: Self.frequencySort),
            with: items,
            limit: limit
        )
    }

    func snapshot(for item: LaunchItem) -> LaunchHistorySnapshot? {
        let key = InMemoryRecentItemsStorage.identifier(for: item)
        guard let entry = loadEntries()[key] else {
            return nil
        }
        return LaunchHistorySnapshot(lastLaunchedAt: entry.lastLaunchedAt, launchCount: entry.launchCount)
    }

    func clearHistory() {
        userDefaults.removeObject(forKey: storageKey)
    }

    private func merge(entries: [LaunchHistoryEntry], with items: [LaunchItem], limit: Int) -> [LaunchItem] {
        let positiveLimit = max(0, limit)
        guard positiveLimit > 0 else {
            return []
        }

        var itemMap: [String: LaunchItem] = [:]
        for item in items {
            itemMap[InMemoryRecentItemsStorage.identifier(for: item)] = item
        }
        var result: [LaunchItem] = []
        result.reserveCapacity(min(positiveLimit, entries.count))
        for entry in entries {
            if result.count >= positiveLimit {
                break
            }
            if let matched = itemMap[entry.identifier] {
                result.append(matched)
            } else {
                result.append(entry.asLaunchItem)
            }
        }
        return result
    }

    private func loadEntries() -> [String: LaunchHistoryEntry] {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: storageKey) else {
            return [:]
        }
        do {
            return try decoder.decode([String: LaunchHistoryEntry].self, from: data)
        } catch {
            return [:]
        }
    }

    private func saveEntries(_ entries: [String: LaunchHistoryEntry]) {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? encoder.encode(entries) else {
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func recentSort(lhs: LaunchHistoryEntry, rhs: LaunchHistoryEntry) -> Bool {
        if lhs.lastLaunchedAt != rhs.lastLaunchedAt {
            return lhs.lastLaunchedAt > rhs.lastLaunchedAt
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private static func frequencySort(lhs: LaunchHistoryEntry, rhs: LaunchHistoryEntry) -> Bool {
        if lhs.launchCount != rhs.launchCount {
            return lhs.launchCount > rhs.launchCount
        }
        if lhs.lastLaunchedAt != rhs.lastLaunchedAt {
            return lhs.lastLaunchedAt > rhs.lastLaunchedAt
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}

private struct LaunchHistoryEntry: Codable, Hashable {
    let identifier: String
    var title: String
    var bundleIdentifier: String?
    var bundleURL: URL?
    var lastLaunchedAt: Date
    var launchCount: Int

    var asLaunchItem: LaunchItem {
        LaunchItem(
            title: title,
            bundleIdentifier: bundleIdentifier,
            bundleURL: nil
        )
    }
}
