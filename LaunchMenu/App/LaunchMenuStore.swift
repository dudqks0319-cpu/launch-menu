import AppKit
import Foundation

@MainActor
final class LaunchMenuStore: ObservableObject {
    @Published private(set) var allItems: [LaunchItem] = []
    @Published private(set) var visibleItems: [LaunchItem] = []
    @Published private(set) var tabs: [SmartTabModel] = [.all, .recent, .frequent, .newlyInstalled]
    @Published private(set) var isLoading = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var settings: LaunchSettings

    @Published var selectedTabID: String {
        didSet {
            guard oldValue != selectedTabID else { return }
            scheduleFiltering(immediate: true)
        }
    }

    @Published var searchQuery: String = "" {
        didSet {
            guard oldValue != searchQuery else { return }
            scheduleFiltering(immediate: false)
        }
    }

    private let appScanner: AppScanner
    private let searchService: SearchService
    private let smartTabsService: SmartTabsService
    private let launchingService: AppLaunchingService
    private let settingsStorage: SettingsStorage
    private let iconCache: AppIconCaching

    private var searchTask: Task<Void, Never>?
    private var isStarted = false

    init(
        settingsStorage: SettingsStorage = UserDefaultsSettingsStorage(),
        recentItemsStorage: RecentItemsStorage = UserDefaultsRecentItemsStorage()
    ) {
        self.settingsStorage = settingsStorage

        let loadedSettings = settingsStorage.load()
        self.settings = loadedSettings

        let iconCache = AppIconCache(
            itemLimit: loadedSettings.iconCacheItemLimit,
            memoryLimitBytes: loadedSettings.iconCacheMemoryLimitBytes
        )
        self.iconCache = iconCache

        self.appScanner = DefaultAppScanner(iconCache: iconCache)
        self.searchService = BasicSearchService()
        self.smartTabsService = DefaultSmartTabsService(
            recentItemsStorage: recentItemsStorage,
            settingsStorage: settingsStorage
        )
        self.launchingService = WorkspaceAppLaunchingService(recentItemsStorage: recentItemsStorage)

        self.selectedTabID = SmartTabModel.all.id
    }

    deinit {
        searchTask?.cancel()
    }

    func start() {
        guard isStarted == false else { return }
        isStarted = true

        Task {
            await refreshApps()
        }
    }

    func refreshApps() async {
        isLoading = true
        lastErrorMessage = nil

        let scannedItems = await appScanner.scanApplications(includeHiddenApps: settings.showHiddenApps)
        allItems = scannedItems

        let availableTabs = smartTabsService.availableTabs(for: scannedItems)
        tabs = availableTabs
        if tabs.contains(where: { $0.id == selectedTabID }) == false {
            selectedTabID = tabs.first?.id ?? SmartTabModel.all.id
        }

        isLoading = false
        scheduleFiltering(immediate: true)
    }

    func selectTab(with id: String) {
        guard selectedTabID != id else { return }
        selectedTabID = id
    }

    func launch(_ item: LaunchItem) {
        Task {
            do {
                try await launchingService.launch(item: item)
                // 최근/자주 실행 탭을 즉시 반영
                scheduleFiltering(immediate: true)
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func icon(for item: LaunchItem) -> NSImage? {
        iconCache.icon(for: item)
    }

    func applySettings(_ newSettings: LaunchSettings) {
        let shouldRescan = settings.showHiddenApps != newSettings.showHiddenApps

        settings = newSettings
        settingsStorage.save(newSettings)

        if let configurableCache = iconCache as? AppIconCache {
            configurableCache.configureLimits(
                itemLimit: newSettings.iconCacheItemLimit,
                memoryLimitBytes: newSettings.iconCacheMemoryLimitBytes
            )
        }

        if shouldRescan {
            Task {
                await refreshApps()
            }
        } else {
            scheduleFiltering(immediate: true)
        }
    }

    func resetSettings() {
        settingsStorage.reset()
        let reloaded = settingsStorage.load()
        applySettings(reloaded)
    }

    func clearError() {
        lastErrorMessage = nil
    }

    private var selectedTab: SmartTabModel {
        tabs.first(where: { $0.id == selectedTabID }) ?? tabs.first ?? .all
    }

    private func scheduleFiltering(immediate: Bool) {
        searchTask?.cancel()

        let tab = selectedTab
        let items = allItems
        let query = searchQuery
        let debounceMs = max(0, settings.searchDebounceMilliseconds)

        searchTask = Task { [weak self] in
            guard let self else { return }

            if immediate == false, query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                let nanos = UInt64(debounceMs) * 1_000_000
                try? await Task.sleep(nanoseconds: nanos)
                guard Task.isCancelled == false else { return }
            }

            let scopedItems = smartTabsService.items(for: tab, from: items)
            let filteredItems = await searchService.search(query: query, in: scopedItems)
            guard Task.isCancelled == false else { return }

            await MainActor.run {
                self.visibleItems = filteredItems
            }
        }
    }
}
