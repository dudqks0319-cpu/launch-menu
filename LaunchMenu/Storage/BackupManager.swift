import AppKit
import Foundation
import UniformTypeIdentifiers

struct LaunchMenuBackupPayload: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var exportedAt: Date
    var layout: [PersistedTopLevelEntry]
    var settings: LaunchSettings

    init(
        schemaVersion: Int = LaunchMenuBackupPayload.currentSchemaVersion,
        exportedAt: Date = Date(),
        layout: [PersistedTopLevelEntry],
        settings: LaunchSettings
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.layout = layout
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case exportedAt
        case layout
        case settings
        case topLevelEntries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? LaunchMenuBackupPayload.currentSchemaVersion
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        layout = try container.decodeIfPresent([PersistedTopLevelEntry].self, forKey: .layout)
            ?? container.decodeIfPresent([PersistedTopLevelEntry].self, forKey: .topLevelEntries)
            ?? []
        settings = try container.decode(LaunchSettings.self, forKey: .settings)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(exportedAt, forKey: .exportedAt)
        try container.encode(layout, forKey: .layout)
        try container.encode(settings, forKey: .settings)
    }
}

@MainActor
protocol BackupManaging {
    @discardableResult
    func exportBackup(
        layout: [PersistedTopLevelEntry],
        settings: LaunchSettings
    ) throws -> URL

    func importBackup() throws -> LaunchMenuBackupPayload
}

enum BackupManagerError: LocalizedError, Equatable {
    case cancelled
    case unsupportedSchemaVersion(Int)
    case invalidPayload(String)
    case failedToReadFile
    case failedToWriteFile

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return L10n.t("error.backup.cancelled")
        case let .unsupportedSchemaVersion(version):
            return L10n.f("error.backup.unsupported.schema", version)
        case let .invalidPayload(message):
            return L10n.f("error.backup.invalid.payload", message)
        case .failedToReadFile:
            return L10n.t("error.backup.read.failed")
        case .failedToWriteFile:
            return L10n.t("error.backup.write.failed")
        }
    }
}

@MainActor
final class BackupManager: BackupManaging {
    static let backupFileExtension = "launchmenu-backup"
    private static let maxBackupFileSizeBytes = 5 * 1024 * 1024

    private static var backupContentType: UTType {
        UTType(filenameExtension: backupFileExtension, conformingTo: .json)
            ?? UTType(filenameExtension: backupFileExtension)
            ?? .json
    }

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    @discardableResult
    func exportBackup(
        layout: [PersistedTopLevelEntry],
        settings: LaunchSettings
    ) throws -> URL {
        let payload = LaunchMenuBackupPayload(layout: layout, settings: settings)
        try validate(payload)

        let panel = NSSavePanel()
        panel.title = L10n.t("backup.save.title")
        panel.message = L10n.t("backup.save.message")
        panel.prompt = L10n.t("common.save")
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [Self.backupContentType]
        panel.nameFieldStringValue = defaultBackupFileName()

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            throw BackupManagerError.cancelled
        }

        let destinationURL = normalizedBackupURL(for: selectedURL)
        do {
            let data = try encoder.encode(payload)
            try data.write(to: destinationURL, options: [.atomic])
            return destinationURL
        } catch {
            throw BackupManagerError.failedToWriteFile
        }
    }

    func importBackup() throws -> LaunchMenuBackupPayload {
        let panel = NSOpenPanel()
        panel.title = L10n.t("backup.restore.title")
        panel.message = L10n.t("backup.restore.message")
        panel.prompt = L10n.t("common.restore")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [Self.backupContentType]

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            throw BackupManagerError.cancelled
        }

        guard selectedURL.pathExtension.lowercased() == Self.backupFileExtension else {
            throw BackupManagerError.invalidPayload(L10n.f("error.backup.invalid.extension", Self.backupFileExtension))
        }

        let resourceValues: URLResourceValues
        do {
            resourceValues = try selectedURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        } catch {
            throw BackupManagerError.failedToReadFile
        }
        guard resourceValues.isRegularFile == true else {
            throw BackupManagerError.invalidPayload(L10n.t("error.backup.invalid.file"))
        }
        let fileSize = resourceValues.fileSize ?? 0
        guard fileSize > 0 else {
            throw BackupManagerError.invalidPayload(L10n.t("error.backup.invalid.file"))
        }
        guard fileSize <= Self.maxBackupFileSizeBytes else {
            throw BackupManagerError.invalidPayload(
                L10n.f("error.backup.file.too.large", Self.maxBackupFileSizeBytes / (1024 * 1024))
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: selectedURL, options: [.mappedIfSafe])
        } catch {
            throw BackupManagerError.failedToReadFile
        }

        let payload: LaunchMenuBackupPayload
        do {
            payload = try decoder.decode(LaunchMenuBackupPayload.self, from: data)
        } catch {
            throw BackupManagerError.invalidPayload(L10n.t("error.backup.invalid.json"))
        }

        try validate(payload)
        return payload
    }

    private func defaultBackupFileName() -> String {
        let timestamp = Self.filenameFormatter.string(from: Date())
        return "LaunchMenu-Backup-\(timestamp).\(Self.backupFileExtension)"
    }

    private func normalizedBackupURL(for url: URL) -> URL {
        guard url.pathExtension.lowercased() != Self.backupFileExtension else {
            return url
        }
        return url.appendingPathExtension(Self.backupFileExtension)
    }

    private func validate(_ payload: LaunchMenuBackupPayload) throws {
        guard payload.schemaVersion == LaunchMenuBackupPayload.currentSchemaVersion else {
            throw BackupManagerError.unsupportedSchemaVersion(payload.schemaVersion)
        }

        var seenIdentifiers: Set<String> = []
        for entry in payload.layout {
            switch entry {
            case let .app(identifier):
                try validateIdentifier(identifier, seenIdentifiers: &seenIdentifiers)
            case let .folder(folder):
                guard folder.itemIdentifiers.isEmpty == false else {
                    throw BackupManagerError.invalidPayload(L10n.t("error.backup.empty.folder.entry"))
                }
                for identifier in folder.itemIdentifiers {
                    try validateIdentifier(identifier, seenIdentifiers: &seenIdentifiers)
                }
            }
        }
    }

    private func validateIdentifier(
        _ rawIdentifier: String,
        seenIdentifiers: inout Set<String>
    ) throws {
        let identifier = rawIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard identifier.isEmpty == false else {
            throw BackupManagerError.invalidPayload(L10n.t("error.backup.empty.app.identifier"))
        }
        guard seenIdentifiers.insert(identifier).inserted else {
            throw BackupManagerError.invalidPayload(L10n.t("error.backup.duplicate.app.identifier"))
        }
    }
}
