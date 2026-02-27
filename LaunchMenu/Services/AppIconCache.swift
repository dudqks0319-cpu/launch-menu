import AppKit
import Foundation

protocol AppIconCaching: AnyObject {
    func icon(for item: LaunchItem) -> NSImage?
    func icon(forAppPath appPath: String) -> NSImage?
    func prefetchIcon(for item: LaunchItem)
    func clear()
}

final class AppIconCache: AppIconCaching {
    private let workspace: NSWorkspace
    private let cache = NSCache<NSString, NSImage>()
    private let lock = NSLock()
    private let iconSize: NSSize

    init(
        workspace: NSWorkspace = .shared,
        itemLimit: Int = 240,
        memoryLimitBytes: Int = 64 * 1024 * 1024,
        iconSize: NSSize = NSSize(width: 64, height: 64)
    ) {
        self.workspace = workspace
        self.iconSize = iconSize
        cache.countLimit = max(1, itemLimit)
        cache.totalCostLimit = max(1, memoryLimitBytes)
    }

    func icon(for item: LaunchItem) -> NSImage? {
        guard let appPath = item.appPath else {
            return nil
        }
        let key = cacheKey(for: item.stableIdentifier)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        return storeAndReturnIcon(forAppPath: appPath, key: key)
    }

    func icon(forAppPath appPath: String) -> NSImage? {
        let key = cacheKey(for: "path:\(appPath.lowercased())")
        if let cached = cache.object(forKey: key) {
            return cached
        }
        return storeAndReturnIcon(forAppPath: appPath, key: key)
    }

    func prefetchIcon(for item: LaunchItem) {
        _ = icon(for: item)
    }

    func clear() {
        cache.removeAllObjects()
    }

    func configureLimits(itemLimit: Int, memoryLimitBytes: Int) {
        lock.lock()
        defer { lock.unlock() }
        cache.countLimit = max(1, itemLimit)
        cache.totalCostLimit = max(1, memoryLimitBytes)
    }

    private func storeAndReturnIcon(forAppPath appPath: String, key: NSString) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let icon = workspace.icon(forFile: appPath)
        icon.size = iconSize
        cache.setObject(icon, forKey: key, cost: estimatedCost(for: icon))
        return icon
    }

    private func cacheKey(for value: String) -> NSString {
        NSString(string: value)
    }

    private func estimatedCost(for image: NSImage) -> Int {
        max(1, Int(image.size.width * image.size.height * 4))
    }
}
