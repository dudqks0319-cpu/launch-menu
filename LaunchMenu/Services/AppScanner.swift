import AppKit
import CoreServices
import Foundation

protocol AppScanner {
    func scanApplications(includeHiddenApps: Bool) async -> [LaunchItem]
}

protocol AppScanMonitoring {
    func startMonitoring(onChange: @escaping () -> Void)
    func stopMonitoring()
}

final class DefaultAppScanner: AppScanner, AppScanMonitoring {
    private let fileManager: FileManager
    private let workspace: NSWorkspace
    private let iconCache: AppIconCaching?
    private let scanRoots: [URL]
    private var eventStream: FSEventStreamRef?
    private let monitorQueue = DispatchQueue(label: "launchmenu.appscanner.fsevents")
    private var onMonitorChange: (() -> Void)?
    private var pendingChangeNotification: DispatchWorkItem?

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

    deinit {
        stopMonitoring()
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

    func startMonitoring(onChange: @escaping () -> Void) {
        stopMonitoring()
        onMonitorChange = onChange

        let monitorPaths = scanRoots
            .filter { fileManager.fileExists(atPath: $0.path) }
            .map(\.path) as CFArray
        guard CFArrayGetCount(monitorPaths) > 0 else {
            return
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let stream = FSEventStreamCreate(
            nil,
            { _, callbackInfo, _, _, _, _ in
                guard let callbackInfo else { return }
                let scanner = Unmanaged<DefaultAppScanner>.fromOpaque(callbackInfo).takeUnretainedValue()
                scanner.notifyMonitorChanged()
            },
            &context,
            monitorPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.8,
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagFileEvents |
                kFSEventStreamCreateFlagUseCFTypes |
                kFSEventStreamCreateFlagNoDefer
            )
        )

        guard let stream else {
            return
        }

        eventStream = stream
        FSEventStreamSetDispatchQueue(stream, monitorQueue)
        FSEventStreamStart(stream)
    }

    func stopMonitoring() {
        pendingChangeNotification?.cancel()
        pendingChangeNotification = nil
        onMonitorChange = nil

        guard let eventStream else { return }
        FSEventStreamStop(eventStream)
        FSEventStreamInvalidate(eventStream)
        FSEventStreamRelease(eventStream)
        self.eventStream = nil
    }

    private func notifyMonitorChanged() {
        pendingChangeNotification?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.onMonitorChange?()
        }
        pendingChangeNotification = workItem
        monitorQueue.asyncAfter(deadline: .now() + 0.5, execute: workItem)
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
