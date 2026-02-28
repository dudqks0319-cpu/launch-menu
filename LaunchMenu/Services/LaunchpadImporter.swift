import Foundation
import SQLite3

protocol LaunchpadImporting {
    func importTopLevelEntries() throws -> [PersistedTopLevelEntry]
}

enum LaunchpadImportError: LocalizedError {
    case darwinUserDirectoryUnavailable
    case databaseNotFound(String)
    case databaseOpenFailed(Int32)
    case unsupportedSchema
    case noImportableEntries

    var errorDescription: String? {
        switch self {
        case .darwinUserDirectoryUnavailable:
            return L10n.t("error.launchpad.darwin.user.dir")
        case let .databaseNotFound(path):
            return L10n.f("error.launchpad.db.not.found", path)
        case let .databaseOpenFailed(code):
            return L10n.f("error.launchpad.db.open.failed", code)
        case .unsupportedSchema:
            return L10n.t("error.launchpad.schema.unsupported")
        case .noImportableEntries:
            return L10n.t("error.launchpad.no.entries")
        }
    }
}

final class LaunchpadImporter: LaunchpadImporting {
    private struct AppRecord {
        var itemID: Int64
        var bundleIdentifier: String?
        var title: String?
    }

    private struct ItemRecord {
        var itemID: Int64
        var parentID: Int64?
        var ordering: Int64
    }

    func importTopLevelEntries() throws -> [PersistedTopLevelEntry] {
        let databaseURL = try launchpadDatabaseURL()

        var db: OpaquePointer?
        let openCode = sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY, nil)
        guard openCode == SQLITE_OK, let db else {
            throw LaunchpadImportError.databaseOpenFailed(openCode)
        }
        defer {
            sqlite3_close(db)
        }

        let apps = try fetchApps(db: db)
        let groups = try fetchGroups(db: db)
        let items = try fetchItems(db: db)

        let entries = buildEntries(apps: apps, groups: groups, items: items)
        if entries.isEmpty {
            throw LaunchpadImportError.noImportableEntries
        }
        return entries
    }

    private func launchpadDatabaseURL() throws -> URL {
        // Note: macOS stores the per-user Launchpad DB under DARWIN_USER_DIR.
        // We call the fixed system binary (/usr/bin/getconf) with fixed args only.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/getconf")
        process.arguments = ["DARWIN_USER_DIR"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            throw LaunchpadImportError.darwinUserDirectoryUnavailable
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LaunchpadImportError.darwinUserDirectoryUnavailable
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let darwinUserDirectory = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let darwinUserDirectory, darwinUserDirectory.isEmpty == false else {
            throw LaunchpadImportError.darwinUserDirectoryUnavailable
        }

        let databasePath = darwinUserDirectory + "com.apple.dock.launchpad/db/db"
        guard FileManager.default.fileExists(atPath: databasePath) else {
            throw LaunchpadImportError.databaseNotFound(databasePath)
        }

        return URL(fileURLWithPath: databasePath)
    }

    private func fetchApps(db: OpaquePointer) throws -> [Int64: AppRecord] {
        let statement = try prepareStatement(
            db: db,
            sqls: [
                "SELECT item_id, bundleid, title FROM apps",
                "SELECT rowid AS item_id, bundleid, title FROM apps",
                "SELECT item_id, bundleidentifier AS bundleid, title FROM apps",
                "SELECT rowid AS item_id, bundleidentifier AS bundleid, title FROM apps"
            ]
        )
        defer { sqlite3_finalize(statement) }

        var results: [Int64: AppRecord] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let itemID = sqlite3_column_int64(statement, 0)
            let bundleIdentifier = sqliteString(statement: statement, index: 1)
            let title = sqliteString(statement: statement, index: 2)
            results[itemID] = AppRecord(itemID: itemID, bundleIdentifier: bundleIdentifier, title: title)
        }

        return results
    }

    private func fetchGroups(db: OpaquePointer) throws -> [Int64: String] {
        let statement = try prepareStatement(
            db: db,
            sqls: [
                "SELECT item_id, title FROM groups",
                "SELECT rowid AS item_id, title FROM groups"
            ]
        )
        defer { sqlite3_finalize(statement) }

        var results: [Int64: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let itemID = sqlite3_column_int64(statement, 0)
            let title = sqliteString(statement: statement, index: 1) ?? L10n.t("folder.default.name")
            results[itemID] = title
        }

        return results
    }

    private func fetchItems(db: OpaquePointer) throws -> [ItemRecord] {
        let statement = try prepareStatement(
            db: db,
            sqls: [
                "SELECT item_id, parent_id, ordering FROM items ORDER BY parent_id, ordering, item_id",
                "SELECT rowid AS item_id, parent_id, ordering FROM items ORDER BY parent_id, ordering, rowid",
                "SELECT item_id, parent_id, 0 AS ordering FROM items ORDER BY parent_id, item_id",
                "SELECT rowid AS item_id, parent_id, 0 AS ordering FROM items ORDER BY parent_id, rowid"
            ]
        )
        defer { sqlite3_finalize(statement) }

        var results: [ItemRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let itemID = sqlite3_column_int64(statement, 0)
            let parentID: Int64?
            if sqlite3_column_type(statement, 1) == SQLITE_NULL {
                parentID = nil
            } else {
                parentID = sqlite3_column_int64(statement, 1)
            }
            let ordering = sqlite3_column_int64(statement, 2)
            results.append(ItemRecord(itemID: itemID, parentID: parentID, ordering: ordering))
        }

        return results
    }

    private func buildEntries(
        apps: [Int64: AppRecord],
        groups: [Int64: String],
        items: [ItemRecord]
    ) -> [PersistedTopLevelEntry] {
        guard apps.isEmpty == false else { return [] }

        let appIDs = Set(apps.keys)
        let groupIDs = Set(groups.keys)

        var childrenByParent: [Int64: [(Int64, Int64)]] = [:]
        for item in items {
            guard let parentID = item.parentID else { continue }
            childrenByParent[parentID, default: []].append((item.ordering, item.itemID))
        }

        for parent in childrenByParent.keys {
            childrenByParent[parent]?.sort { lhs, rhs in
                if lhs.0 != rhs.0 {
                    return lhs.0 < rhs.0
                }
                return lhs.1 < rhs.1
            }
        }

        let rootParent = inferRootParent(
            appIDs: appIDs,
            groupIDs: groupIDs,
            childrenByParent: childrenByParent
        )

        let topLevelIDs: [Int64]
        if let rootParent, let children = childrenByParent[rootParent], children.isEmpty == false {
            topLevelIDs = children.map(\.1)
        } else {
            topLevelIDs = apps.keys.sorted()
        }

        var entries: [PersistedTopLevelEntry] = []
        for itemID in topLevelIDs {
            if let folderTitle = groups[itemID] {
                let childItems = (childrenByParent[itemID] ?? [])
                    .map(\.1)
                    .compactMap { apps[$0] }
                let identifiers = childItems.compactMap(stableIdentifier(for:))

                if identifiers.count >= 2 {
                    entries.append(
                        .folder(
                            PersistedLayoutFolder(
                                id: UUID(),
                                name: normalizedFolderName(folderTitle),
                                itemIdentifiers: identifiers
                            )
                        )
                    )
                } else if let identifier = identifiers.first {
                    entries.append(.app(identifier: identifier))
                }
            } else if let app = apps[itemID], let identifier = stableIdentifier(for: app) {
                entries.append(.app(identifier: identifier))
            }
        }

        if entries.isEmpty {
            let fallback = apps.values
                .sorted { lhs, rhs in
                    (lhs.title ?? "").localizedStandardCompare(rhs.title ?? "") == .orderedAscending
                }
                .compactMap(stableIdentifier(for:))
                .map { PersistedTopLevelEntry.app(identifier: $0) }
            return fallback
        }

        return entries
    }

    private func inferRootParent(
        appIDs: Set<Int64>,
        groupIDs: Set<Int64>,
        childrenByParent: [Int64: [(Int64, Int64)]]
    ) -> Int64? {
        let candidates = childrenByParent.keys.filter { parentID in
            appIDs.contains(parentID) == false && groupIDs.contains(parentID) == false
        }

        return candidates.max { lhs, rhs in
            (childrenByParent[lhs]?.count ?? 0) < (childrenByParent[rhs]?.count ?? 0)
        }
    }

    private func stableIdentifier(for app: AppRecord) -> String? {
        if let bundleIdentifier = app.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), bundleIdentifier.isEmpty == false {
            return "bundle:\(bundleIdentifier.lowercased())"
        }

        if let title = app.title?.trimmingCharacters(in: .whitespacesAndNewlines), title.isEmpty == false {
            return "title:\(title.lowercased())"
        }

        return nil
    }

    private func normalizedFolderName(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.t("folder.default.name") : trimmed
    }

    private func prepareStatement(db: OpaquePointer, sqls: [String]) throws -> OpaquePointer {
        for sql in sqls {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement {
                return statement
            }
            sqlite3_finalize(statement)
        }
        throw LaunchpadImportError.unsupportedSchema
    }

    private func sqliteString(statement: OpaquePointer, index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: cString)
    }
}
