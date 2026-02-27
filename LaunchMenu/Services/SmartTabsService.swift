import Foundation

protocol SmartTabsService {
    func availableTabs(for items: [LaunchItem]) -> [SmartTabModel]
    func items(for tab: SmartTabModel, from items: [LaunchItem]) -> [LaunchItem]
    func tabSections(for items: [LaunchItem]) -> [SmartTabSection]
}

struct DefaultSmartTabsService: SmartTabsService {
    private let recentItemsStorage: RecentItemsStorage?
    private let settingsStorage: SettingsStorage?
    private let now: () -> Date

    init(
        recentItemsStorage: RecentItemsStorage? = nil,
        settingsStorage: SettingsStorage? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.recentItemsStorage = recentItemsStorage
        self.settingsStorage = settingsStorage
        self.now = now
    }

    func availableTabs(for items: [LaunchItem]) -> [SmartTabModel] {
        return [.all, .recent, .frequent, .newlyInstalled]
    }

    func items(for tab: SmartTabModel, from items: [LaunchItem]) -> [LaunchItem] {
        switch tab.kind {
        case .all:
            return sortedAllItems(items)
        case .recent:
            return recentItemsStorage?.recentItems(from: items, limit: currentSettings.maxRecentItems) ?? []
        case .frequent:
            return recentItemsStorage?.frequentItems(from: items, limit: currentSettings.maxFrequentItems) ?? []
        case .newlyInstalled:
            return newlyInstalledItems(from: items)
        }
    }

    func tabSections(for items: [LaunchItem]) -> [SmartTabSection] {
        availableTabs(for: items).map { tab in
            SmartTabSection(tab: tab, items: self.items(for: tab, from: items))
        }
    }

    private var currentSettings: LaunchSettings {
        settingsStorage?.load() ?? .default
    }

    private func sortedAllItems(_ items: [LaunchItem]) -> [LaunchItem] {
        items.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    private func newlyInstalledItems(from items: [LaunchItem]) -> [LaunchItem] {
        let day = TimeInterval(24 * 60 * 60)
        let cutoff = now().addingTimeInterval(-day * Double(max(1, currentSettings.newInstallWindowDays)))
        return items
            .filter { item in
                if let installedAt = item.installedAt {
                    return installedAt >= cutoff
                }
                if let lastModifiedAt = item.lastModifiedAt {
                    return lastModifiedAt >= cutoff
                }
                return false
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.installedAt ?? lhs.lastModifiedAt ?? .distantPast
                let rhsDate = rhs.installedAt ?? rhs.lastModifiedAt ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }
}
