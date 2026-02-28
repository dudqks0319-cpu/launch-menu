import AppKit
import Foundation

struct AppUninstallPreview {
    let itemStableIdentifier: String
    let appDisplayName: String
    let appBundleURL: URL
    let relatedFileURLs: [URL]

    var relatedFileCount: Int {
        relatedFileURLs.count
    }
}

protocol AppUninstalling {
    func previewUninstall(for item: LaunchItem) throws -> AppUninstallPreview
    func uninstall(using preview: AppUninstallPreview) async throws
}

enum AppUninstallerError: LocalizedError {
    case missingAppPath
    case thirdPartyOnly
    case invalidAppPath
    case unsafePath
    case recycleFailed(String)
    case removeFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAppPath:
            return L10n.t("error.uninstall.missing.path")
        case .thirdPartyOnly:
            return L10n.t("error.uninstall.third.party.only")
        case .invalidAppPath:
            return L10n.t("error.uninstall.invalid.bundle")
        case .unsafePath:
            return L10n.t("error.uninstall.unsafe.path")
        case let .recycleFailed(message):
            return L10n.f("error.uninstall.recycle.failed", message)
        case let .removeFailed(message):
            return L10n.f("error.uninstall.remove.failed", message)
        }
    }
}

final class AppUninstaller: AppUninstalling {
    private let fileManager: FileManager
    private let workspace: NSWorkspace
    private let homeDirectoryPath: String
    private let appRootPaths: [String]
    private let relatedRootPaths: [String]
    private let protectedRootPaths: [String] = ["/System", "/Library"]

    init(
        fileManager: FileManager = .default,
        workspace: NSWorkspace = .shared
    ) {
        self.fileManager = fileManager
        self.workspace = workspace

        let homeDirectory = fileManager.homeDirectoryForCurrentUser.standardizedFileURL.resolvingSymlinksInPath()
        self.homeDirectoryPath = homeDirectory.path

        self.appRootPaths = [
            "/Applications",
            homeDirectory.appendingPathComponent("Applications", isDirectory: true).path
        ]

        let homeLibrary = homeDirectory.appendingPathComponent("Library", isDirectory: true)
        self.relatedRootPaths = [
            homeLibrary.appendingPathComponent("Preferences", isDirectory: true).path,
            homeLibrary.appendingPathComponent("Caches", isDirectory: true).path,
            homeLibrary.appendingPathComponent("Application Support", isDirectory: true).path
        ]
    }

    func previewUninstall(for item: LaunchItem) throws -> AppUninstallPreview {
        guard item.isSystemApp == false else {
            throw AppUninstallerError.thirdPartyOnly
        }

        let bundleIdentifier = item.bundleIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let bundleIdentifier, bundleIdentifier.hasPrefix("com.apple.") {
            throw AppUninstallerError.thirdPartyOnly
        }

        let appURL = try validatedThirdPartyAppBundleURL(for: item)
        let relatedURLs = relatedFileURLs(forBundleIdentifier: bundleIdentifier)

        return AppUninstallPreview(
            itemStableIdentifier: item.stableIdentifier,
            appDisplayName: item.title,
            appBundleURL: appURL,
            relatedFileURLs: relatedURLs
        )
    }

    func uninstall(using preview: AppUninstallPreview) async throws {
        var deletionTargets: [URL] = []
        var seenPaths: Set<String> = []

        let appURL = try validatedAppDeletionURL(preview.appBundleURL)
        appendDeletionTarget(appURL, to: &deletionTargets, seenPaths: &seenPaths)

        for relatedURL in preview.relatedFileURLs {
            let validatedURL = try validatedRelatedDeletionURL(relatedURL)
            appendDeletionTarget(validatedURL, to: &deletionTargets, seenPaths: &seenPaths)
        }

        for target in deletionTargets {
            try await deleteItem(at: target)
        }
    }

    private func appendDeletionTarget(
        _ url: URL,
        to targets: inout [URL],
        seenPaths: inout Set<String>
    ) {
        let key = normalizedPath(url.path).lowercased()
        if seenPaths.insert(key).inserted {
            targets.append(url)
        }
    }

    private func relatedFileURLs(forBundleIdentifier bundleIdentifier: String?) -> [URL] {
        guard let bundleIdentifier, bundleIdentifier.isEmpty == false else { return [] }

        let lowercasedBundleID = bundleIdentifier.lowercased()
        let bundleComponents = lowercasedBundleID.split(separator: ".")
        guard bundleComponents.count >= 3 else { return [] }

        let homeLibrary = URL(fileURLWithPath: homeDirectoryPath, isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
        let preferencesURL = homeLibrary.appendingPathComponent("Preferences", isDirectory: true)
        let byHostPreferencesURL = preferencesURL.appendingPathComponent("ByHost", isDirectory: true)
        let cachesURL = homeLibrary.appendingPathComponent("Caches", isDirectory: true)
        let appSupportURL = homeLibrary.appendingPathComponent("Application Support", isDirectory: true)

        var matches: [URL] = []
        var seen: Set<String> = []

        func addCandidate(_ candidate: URL) {
            guard fileManager.fileExists(atPath: candidate.path) else { return }
            guard let validated = validatedRelatedPreviewURL(candidate) else { return }
            let key = normalizedPath(validated.path).lowercased()
            guard seen.insert(key).inserted else { return }
            matches.append(validated)
        }

        addCandidate(preferencesURL.appendingPathComponent("\(bundleIdentifier).plist"))
        appendMatchingEntries(
            in: byHostPreferencesURL,
            lowercasedBundleID: lowercasedBundleID,
            requirePlistExtension: true,
            allowPrefixMatch: true,
            onMatch: addCandidate
        )
        appendMatchingEntries(
            in: cachesURL,
            lowercasedBundleID: lowercasedBundleID,
            requirePlistExtension: false,
            allowPrefixMatch: false,
            onMatch: addCandidate
        )
        appendMatchingEntries(
            in: appSupportURL,
            lowercasedBundleID: lowercasedBundleID,
            requirePlistExtension: false,
            allowPrefixMatch: false,
            onMatch: addCandidate
        )

        return matches.sorted { lhs, rhs in
            lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    private func appendMatchingEntries(
        in directoryURL: URL,
        lowercasedBundleID: String,
        requirePlistExtension: Bool,
        allowPrefixMatch: Bool,
        onMatch: (URL) -> Void
    ) {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for entry in entries {
            let name = entry.lastPathComponent.lowercased()
            let matchesBundlePrefix: Bool
            if allowPrefixMatch {
                matchesBundlePrefix = name == lowercasedBundleID || name.hasPrefix(lowercasedBundleID + ".")
            } else {
                matchesBundlePrefix = name == lowercasedBundleID
            }
            guard matchesBundlePrefix else { continue }
            if requirePlistExtension, entry.pathExtension.lowercased() != "plist" {
                continue
            }
            onMatch(entry)
        }
    }

    private func validatedThirdPartyAppBundleURL(for item: LaunchItem) throws -> URL {
        if let bundleURL = item.bundleURL {
            return try validatedAppDeletionURL(bundleURL)
        }
        if let appPath = item.appPath, appPath.isEmpty == false {
            return try validatedAppDeletionURL(URL(fileURLWithPath: appPath))
        }
        throw AppUninstallerError.missingAppPath
    }

    private func validatedAppDeletionURL(_ candidate: URL) throws -> URL {
        let normalized = canonicalizedURL(candidate)
        guard normalized.isFileURL else {
            throw AppUninstallerError.invalidAppPath
        }
        guard normalized.pathExtension.lowercased() == "app" else {
            throw AppUninstallerError.invalidAppPath
        }

        let path = normalizedPath(normalized.path)
        guard isProtectedSystemPath(path) == false else {
            throw AppUninstallerError.unsafePath
        }
        guard isWithin(path: path, allowedRoots: appRootPaths) else {
            throw AppUninstallerError.thirdPartyOnly
        }
        guard fileManager.fileExists(atPath: path) else {
            throw AppUninstallerError.missingAppPath
        }
        return normalized
    }

    private func validatedRelatedPreviewURL(_ candidate: URL) -> URL? {
        let normalized = canonicalizedURL(candidate)
        let path = normalizedPath(normalized.path)
        guard isProtectedSystemPath(path) == false else {
            return nil
        }
        guard isWithin(path: path, allowedRoots: relatedRootPaths) else {
            return nil
        }
        return normalized
    }

    private func validatedRelatedDeletionURL(_ candidate: URL) throws -> URL {
        guard let validated = validatedRelatedPreviewURL(candidate) else {
            throw AppUninstallerError.unsafePath
        }
        return validated
    }

    private func deleteItem(at targetURL: URL) async throws {
        let normalizedTarget = canonicalizedURL(targetURL)
        guard fileManager.fileExists(atPath: normalizedTarget.path) else { return }

        do {
            try await recycle(url: normalizedTarget)
        } catch {
            do {
                try fileManager.removeItem(at: normalizedTarget)
            } catch {
                throw AppUninstallerError.removeFailed(error.localizedDescription)
            }
        }
    }

    private func recycle(url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workspace.recycle([url]) { _, error in
                if let error {
                    continuation.resume(throwing: AppUninstallerError.recycleFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func canonicalizedURL(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        return standardized.resolvingSymlinksInPath()
    }

    private func normalizedPath(_ path: String) -> String {
        NSString(string: path).standardizingPath
    }

    private func isProtectedSystemPath(_ path: String) -> Bool {
        isWithin(path: path, allowedRoots: protectedRootPaths)
    }

    private func isWithin(path: String, allowedRoots: [String]) -> Bool {
        let normalized = normalizedPath(path).lowercased()
        return allowedRoots.contains { root in
            let normalizedRoot = normalizedPath(root).lowercased()
            return normalized == normalizedRoot || normalized.hasPrefix(normalizedRoot + "/")
        }
    }
}
