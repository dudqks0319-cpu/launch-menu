import AppKit
import Foundation

protocol AppLaunchingService {
    func launch(item: LaunchItem) async throws
}

struct NoopAppLaunchingService: AppLaunchingService {
    func launch(item: LaunchItem) async throws {
        _ = item
    }
}

enum AppLaunchingError: LocalizedError {
    case missingLaunchTarget
    case invalidLaunchTarget

    var errorDescription: String? {
        switch self {
        case .missingLaunchTarget:
            return L10n.t("error.launch.missing.target")
        case .invalidLaunchTarget:
            return L10n.t("error.launch.invalid.target")
        }
    }
}

final class WorkspaceAppLaunchingService: AppLaunchingService {
    private let workspace: NSWorkspace
    private let recentItemsStorage: RecentItemsStorage?
    private let fileManager: FileManager
    private let allowedRoots: [String]

    init(
        workspace: NSWorkspace = .shared,
        recentItemsStorage: RecentItemsStorage? = nil,
        fileManager: FileManager = .default,
        allowedRoots: [String]? = nil
    ) {
        self.workspace = workspace
        self.recentItemsStorage = recentItemsStorage
        self.fileManager = fileManager
        self.allowedRoots = allowedRoots ?? [
            "/Applications",
            "/System/Applications",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true).path
        ]
    }

    func launch(item: LaunchItem) async throws {
        if let directURL = item.bundleURL,
           let validatedURL = validatedApplicationURL(directURL) {
            try await openApplication(at: validatedURL)
            recentItemsStorage?.markLaunched(item, at: Date())
            return
        }

        if let bundleIdentifier = item.bundleIdentifier,
           let resolvedURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier),
           let validatedURL = validatedApplicationURL(resolvedURL) {
            try await openApplication(at: validatedURL)
            recentItemsStorage?.markLaunched(item, at: Date())
            return
        }

        if item.bundleURL != nil {
            throw AppLaunchingError.invalidLaunchTarget
        }
        throw AppLaunchingError.missingLaunchTarget
    }

    private func validatedApplicationURL(_ candidate: URL) -> URL? {
        let normalized = candidate.standardizedFileURL.resolvingSymlinksInPath()

        guard normalized.isFileURL else { return nil }
        guard normalized.pathExtension.lowercased() == "app" else { return nil }

        let path = normalized.path
        guard allowedRoots.contains(where: { root in
            path == root || path.hasPrefix(root + "/")
        }) else {
            return nil
        }

        guard fileManager.fileExists(atPath: path) else { return nil }
        return normalized
    }

    private func openApplication(at appURL: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workspace.openApplication(at: appURL, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
