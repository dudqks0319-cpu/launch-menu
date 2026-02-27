import AppKit
import Foundation

protocol AppScanner {
    func scanApplications(includeHiddenApps: Bool) async -> [LaunchItem]
}

struct DefaultAppScanner: AppScanner {
    private let fileManager: FileManager
    private let workspace: NSWorkspace
    private let iconCache: AppIconCaching?
    private let scanRoots: [URL]

    init(
        fileManager: FileManager = .default,
        workspace: NSWorkspace = .shared,
        iconCache: AppIconCaching? = nil,
        scanRoots: [URL]? = nil
    ) {
        self.fileManager = fileManager
        self.workspace = workspace
        self.iconCache = iconCache
        self.scanRoots = scanRoots ?? Self.defaultScanRoots(fileManager: fileManager)
    }

    func scanApplications(includeHiddenApps: Bool = false) async -> [LaunchItem] {
        let appURLs = scanRoots.flatMap { appBundleURLs(in: $0, includeHiddenApps: includeHiddenApps) }
        var seenIdentifiers: Set<String> = []
        var items: [LaunchItem] = []
        items.reserveCapacity(appURLs.count)

        for appURL in appURLs {
            guard let item = makeLaunchItem(from: appURL, includeHiddenApps: includeHiddenApps) else {
                continue
            }

            if seenIdentifiers.insert(item.stableIdentifier).inserted {
                iconCache?.prefetchIcon(for: item)
                if iconCache == nil {
                    _ = workspace.icon(forFile: appURL.path)
                }
                items.append(item)
            }
        }

        return items.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    private func appBundleURLs(in root: URL, includeHiddenApps: Bool) -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else {
            return []
        }

        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if includeHiddenApps == false {
            options.insert(.skipsHiddenFiles)
        }

        let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .isHiddenKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(resourceKeys),
            options: options
        ) else {
            return []
        }

        var appURLs: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "app" else {
                continue
            }
            appURLs.append(url)
        }
        return appURLs
    }

    private func makeLaunchItem(from appURL: URL, includeHiddenApps: Bool) -> LaunchItem? {
        let resourceKeys: Set<URLResourceKey> = [
            .isHiddenKey,
            .localizedNameKey,
            .nameKey,
            .creationDateKey,
            .contentModificationDateKey
        ]
        let resourceValues = try? appURL.resourceValues(forKeys: resourceKeys)
        let isHidden = resourceValues?.isHidden ?? false
        if includeHiddenApps == false, isHidden {
            return nil
        }

        let bundle = Bundle(url: appURL)
        let bundleIdentifier = bundle?.bundleIdentifier
        let executableName = bundle?.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
        let category = bundle?.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
        let displayName = resolveDisplayName(
            appURL: appURL,
            bundle: bundle,
            resourceValues: resourceValues
        )
        let keywords = [displayName, bundleIdentifier, executableName, category]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        return LaunchItem(
            title: displayName,
            bundleIdentifier: bundleIdentifier,
            bundleURL: appURL,
            executableName: executableName,
            installedAt: resourceValues?.creationDate,
            lastModifiedAt: resourceValues?.contentModificationDate,
            isSystemApp: appURL.path.hasPrefix("/System/Applications/"),
            isHidden: isHidden,
            keywords: Array(Set(keywords))
        )
    }

    private func resolveDisplayName(
        appURL: URL,
        bundle: Bundle?,
        resourceValues: URLResourceValues?
    ) -> String {
        if let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           displayName.isEmpty == false {
            return displayName
        }
        if let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String,
           bundleName.isEmpty == false {
            return bundleName
        }
        if let localizedName = resourceValues?.localizedName, localizedName.isEmpty == false {
            return localizedName
        }
        if let fileName = resourceValues?.name, fileName.isEmpty == false {
            return URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        }
        return appURL.deletingPathExtension().lastPathComponent
    }

    private static func defaultScanRoots(fileManager: FileManager) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
    }
}
