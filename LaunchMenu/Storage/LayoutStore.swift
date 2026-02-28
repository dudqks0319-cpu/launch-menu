import Foundation

struct PersistedLayoutFolder: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var itemIdentifiers: [String]

    init(
        id: UUID = UUID(),
        name: String = "Untitled Folder",
        itemIdentifiers: [String] = []
    ) {
        self.id = id
        self.name = name
        self.itemIdentifiers = itemIdentifiers
    }
}

enum PersistedTopLevelEntry: Hashable, Codable {
    case app(identifier: String)
    case folder(PersistedLayoutFolder)

    var appIdentifier: String? {
        guard case let .app(identifier) = self else {
            return nil
        }
        return identifier
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case identifier
        case folder
    }

    private enum EntryType: String, Codable {
        case app
        case folder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EntryType.self, forKey: .type)

        switch type {
        case .app:
            let identifier = try container.decode(String.self, forKey: .identifier)
            self = .app(identifier: identifier)
        case .folder:
            let folder = try container.decode(PersistedLayoutFolder.self, forKey: .folder)
            self = .folder(folder)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .app(identifier):
            try container.encode(EntryType.app, forKey: .type)
            try container.encode(identifier, forKey: .identifier)
        case let .folder(folder):
            try container.encode(EntryType.folder, forKey: .type)
            try container.encode(folder, forKey: .folder)
        }
    }
}

protocol LayoutStore {
    func loadTopLevelEntries() -> [PersistedTopLevelEntry]
    func saveTopLevelEntries(_ entries: [PersistedTopLevelEntry])

    func loadIdentifierOrder() -> [String]
    func saveIdentifierOrder(_ identifiers: [String])
}

extension LayoutStore {
    func loadIdentifierOrder() -> [String] {
        loadTopLevelEntries().flatMap { entry in
            switch entry {
            case let .app(identifier):
                return [identifier]
            case let .folder(folder):
                return folder.itemIdentifiers
            }
        }
    }

    func saveIdentifierOrder(_ identifiers: [String]) {
        let entries = identifiers.map { identifier in
            PersistedTopLevelEntry.app(identifier: identifier)
        }
        saveTopLevelEntries(entries)
    }
}

final class FileLayoutStore: LayoutStore {
    private struct LayoutDocument: Codable {
        var topLevelEntries: [PersistedTopLevelEntry]
        var updatedAt: Date
    }

    private struct LegacyLayoutDocument: Codable {
        var orderedIdentifiers: [String]
        var updatedAt: Date
    }

    private let fileManager: FileManager
    private let fileURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        fileManager: FileManager = .default,
        applicationName: String = "LaunchMenu",
        fileName: String = "layout.json"
    ) {
        self.fileManager = fileManager

        let appSupportDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(applicationName, isDirectory: true)

        self.fileURL = appSupportDirectory.appendingPathComponent(fileName, isDirectory: false)

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadTopLevelEntries() -> [PersistedTopLevelEntry] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        if let document = try? decoder.decode(LayoutDocument.self, from: data) {
            return document.topLevelEntries
        }

        if let legacyDocument = try? decoder.decode(LegacyLayoutDocument.self, from: data) {
            let converted = legacyDocument.orderedIdentifiers.map { identifier in
                PersistedTopLevelEntry.app(identifier: identifier)
            }
            saveTopLevelEntries(converted)
            return converted
        }

        if let legacyIdentifiers = try? decoder.decode([String].self, from: data) {
            let converted = legacyIdentifiers.map { identifier in
                PersistedTopLevelEntry.app(identifier: identifier)
            }
            saveTopLevelEntries(converted)
            return converted
        }

        return []
    }

    func saveTopLevelEntries(_ entries: [PersistedTopLevelEntry]) {
        let directoryURL = fileURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let document = LayoutDocument(topLevelEntries: entries, updatedAt: Date())
            let data = try encoder.encode(document)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // 파일 저장 실패는 런타임 동작을 중단시키지 않습니다.
        }
    }
}
