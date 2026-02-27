import Foundation

struct LaunchSettings: Equatable, Codable {
    var showHiddenApps: Bool
    var searchDebounceMilliseconds: Int
    var gridColumnCount: Int
    var maxRecentItems: Int
    var maxFrequentItems: Int
    var newInstallWindowDays: Int
    var iconCacheItemLimit: Int
    var iconCacheMemoryLimitBytes: Int

    init(
        showHiddenApps: Bool = false,
        searchDebounceMilliseconds: Int = 200,
        gridColumnCount: Int = 4,
        maxRecentItems: Int = 12,
        maxFrequentItems: Int = 12,
        newInstallWindowDays: Int = 14,
        iconCacheItemLimit: Int = 240,
        iconCacheMemoryLimitBytes: Int = 64 * 1024 * 1024
    ) {
        self.showHiddenApps = showHiddenApps
        self.searchDebounceMilliseconds = searchDebounceMilliseconds
        self.gridColumnCount = gridColumnCount
        self.maxRecentItems = maxRecentItems
        self.maxFrequentItems = maxFrequentItems
        self.newInstallWindowDays = newInstallWindowDays
        self.iconCacheItemLimit = iconCacheItemLimit
        self.iconCacheMemoryLimitBytes = iconCacheMemoryLimitBytes
    }

    static let `default` = LaunchSettings()
}

extension LaunchSettings {
    private enum CodingKeys: String, CodingKey {
        case showHiddenApps
        case searchDebounceMilliseconds
        case gridColumnCount
        case maxRecentItems
        case maxFrequentItems
        case newInstallWindowDays
        case iconCacheItemLimit
        case iconCacheMemoryLimitBytes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showHiddenApps = try container.decodeIfPresent(Bool.self, forKey: .showHiddenApps) ?? false
        searchDebounceMilliseconds = try container.decodeIfPresent(Int.self, forKey: .searchDebounceMilliseconds) ?? 200
        gridColumnCount = try container.decodeIfPresent(Int.self, forKey: .gridColumnCount) ?? 4
        maxRecentItems = try container.decodeIfPresent(Int.self, forKey: .maxRecentItems) ?? 12
        maxFrequentItems = try container.decodeIfPresent(Int.self, forKey: .maxFrequentItems) ?? 12
        newInstallWindowDays = try container.decodeIfPresent(Int.self, forKey: .newInstallWindowDays) ?? 14
        iconCacheItemLimit = try container.decodeIfPresent(Int.self, forKey: .iconCacheItemLimit) ?? 240
        iconCacheMemoryLimitBytes = try container.decodeIfPresent(Int.self, forKey: .iconCacheMemoryLimitBytes) ?? 64 * 1024 * 1024
    }
}
