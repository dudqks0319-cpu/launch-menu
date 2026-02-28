import AppKit
import Foundation

enum LaunchMenuTopLevelDisplayEntry: Identifiable, Hashable {
    case app(LaunchItem)
    case folder(LaunchFolder)

    var id: String {
        switch self {
        case let .app(item):
            return "app:\(item.stableIdentifier)"
        case let .folder(folder):
            return "folder:\(folder.id.uuidString.lowercased())"
        }
    }
}

extension Notification.Name {
    static let launchMenuSettingsDidChange = Notification.Name("launchMenu.settingsDidChange")
}

@MainActor
final class LaunchMenuStore: ObservableObject {
    @Published private(set) var allItems: [LaunchItem] = []
    @Published private(set) var visibleItems: [LaunchItem] = []
    @Published private(set) var topLevelDisplayEntries: [LaunchMenuTopLevelDisplayEntry] = []
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
    private let appUninstaller: AppUninstalling
    private let dockIntegration: DockIntegrating
    private let settingsStorage: SettingsStorage
    private let layoutStore: LayoutStore
    private let backupManager: BackupManaging
    private let launchpadImporter: LaunchpadImporting
    private let iconCache: AppIconCaching
    private let userDefaults: UserDefaults

    private var searchTask: Task<Void, Never>?
    private var isStarted = false
    private var topLevelEntries: [PersistedTopLevelEntry] = []
    private var itemsByIdentifier: [String: LaunchItem] = [:]
    private var hiddenItemIdentifiers: Set<String>
    private var customTitlesByIdentifier: [String: String]

    private let hiddenItemsKey = "launchmenu.hiddenItemIdentifiers"
    private let customTitlesKey = "launchmenu.customTitlesByIdentifier"

    init(
        settingsStorage: SettingsStorage = UserDefaultsSettingsStorage(),
        recentItemsStorage: RecentItemsStorage = UserDefaultsRecentItemsStorage(),
        layoutStore: LayoutStore = FileLayoutStore(),
        backupManager: BackupManaging? = nil,
        launchpadImporter: LaunchpadImporting = LaunchpadImporter(),
        appUninstaller: AppUninstalling = AppUninstaller(),
        dockIntegration: DockIntegrating = AppleScriptDockIntegration(),
        userDefaults: UserDefaults = .standard
    ) {
        self.settingsStorage = settingsStorage
        self.layoutStore = layoutStore
        self.backupManager = backupManager ?? BackupManager()
        self.launchpadImporter = launchpadImporter
        self.appUninstaller = appUninstaller
        self.dockIntegration = dockIntegration
        self.userDefaults = userDefaults

        let hiddenIdentifiers = userDefaults.array(forKey: hiddenItemsKey) as? [String] ?? []
        self.hiddenItemIdentifiers = Set(hiddenIdentifiers)
        self.customTitlesByIdentifier = userDefaults.dictionary(forKey: customTitlesKey) as? [String: String] ?? [:]

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
        if let monitor = appScanner as? AppScanMonitoring {
            monitor.stopMonitoring()
        }
        searchTask?.cancel()
    }

    func start() {
        guard isStarted == false else { return }
        isStarted = true

        if let monitor = appScanner as? AppScanMonitoring {
            monitor.startMonitoring { [weak self] in
                Task { @MainActor in
                    await self?.refreshApps()
                }
            }
        }

        Task {
            await refreshApps()
        }
    }

    func refreshApps() async {
        isLoading = true
        lastErrorMessage = nil

        let scannedItems = await appScanner.scanApplications(includeHiddenApps: settings.showHiddenApps)
        let customizedItems = applyUserCustomizations(to: scannedItems)
        itemsByIdentifier = Dictionary(
            uniqueKeysWithValues: customizedItems.map { ($0.stableIdentifier, $0) }
        )

        let persistedEntries = layoutStore.loadTopLevelEntries()
        let resolvedLayout = resolveLayout(
            entries: persistedEntries,
            itemsByIdentifier: itemsByIdentifier
        )
        topLevelEntries = resolvedLayout.entries
        allItems = resolvedLayout.orderedItems
        topLevelDisplayEntries = resolvedLayout.displayEntries
        persistTopLevelLayout()

        let availableTabs = smartTabsService.availableTabs(for: customizedItems)
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

    func moveItem(draggedIdentifier: String, before targetIdentifier: String) {
        guard draggedIdentifier != targetIdentifier else { return }
        guard let sourceIndex = indexOfTopLevelApp(with: draggedIdentifier) else {
            return
        }
        guard let targetIndex = indexOfTopLevelApp(with: targetIdentifier) else {
            return
        }

        var updated = topLevelEntries
        let movedItem = updated.remove(at: sourceIndex)
        let insertionIndex = sourceIndex < targetIndex ? max(0, targetIndex - 1) : targetIndex
        updated.insert(movedItem, at: insertionIndex)
        topLevelEntries = updated

        applyCurrentTopLevelLayout()
        persistTopLevelLayout()
        scheduleFiltering(immediate: true)
    }

    @discardableResult
    func createFolder(
        from firstTopLevelAppIdentifier: String,
        and secondTopLevelAppIdentifier: String,
        name: String = ""
    ) -> LaunchFolder? {
        guard firstTopLevelAppIdentifier != secondTopLevelAppIdentifier else {
            return nil
        }
        guard let firstIndex = indexOfTopLevelApp(with: firstTopLevelAppIdentifier) else {
            return nil
        }
        guard let secondIndex = indexOfTopLevelApp(with: secondTopLevelAppIdentifier) else {
            return nil
        }

        let insertionIndex = min(firstIndex, secondIndex)
        let orderedIdentifiers: [String]
        if firstIndex < secondIndex {
            orderedIdentifiers = [firstTopLevelAppIdentifier, secondTopLevelAppIdentifier]
        } else {
            orderedIdentifiers = [secondTopLevelAppIdentifier, firstTopLevelAppIdentifier]
        }

        let folder = PersistedLayoutFolder(
            name: normalizedFolderName(name),
            itemIdentifiers: orderedIdentifiers
        )

        var updated = topLevelEntries
        for index in [firstIndex, secondIndex].sorted(by: >) {
            updated.remove(at: index)
        }
        updated.insert(.folder(folder), at: insertionIndex)
        topLevelEntries = updated

        applyCurrentTopLevelLayout()
        persistTopLevelLayout()
        scheduleFiltering(immediate: true)

        for entry in topLevelDisplayEntries {
            if case let .folder(displayFolder) = entry, displayFolder.id == folder.id {
                return displayFolder
            }
        }
        return nil
    }

    @discardableResult
    func renameFolder(folderID: UUID, to newName: String) -> Bool {
        guard let folderIndex = indexOfTopLevelFolder(with: folderID) else {
            return false
        }
        guard case var .folder(folder) = topLevelEntries[folderIndex] else {
            return false
        }

        folder.name = normalizedFolderName(newName)
        var updated = topLevelEntries
        updated[folderIndex] = .folder(folder)
        topLevelEntries = updated

        applyCurrentTopLevelLayout()
        persistTopLevelLayout()
        return true
    }

    @discardableResult
    func removeAppFromFolder(appIdentifier: String, folderID: UUID) -> Bool {
        guard let folderIndex = indexOfTopLevelFolder(with: folderID) else {
            return false
        }
        guard case var .folder(folder) = topLevelEntries[folderIndex] else {
            return false
        }
        guard let removalIndex = folder.itemIdentifiers.firstIndex(of: appIdentifier) else {
            return false
        }

        folder.itemIdentifiers.remove(at: removalIndex)

        var replacementEntries: [PersistedTopLevelEntry] = []
        switch folder.itemIdentifiers.count {
        case 2...:
            replacementEntries.append(.folder(folder))
            replacementEntries.append(.app(identifier: appIdentifier))
        case 1:
            replacementEntries.append(.app(identifier: folder.itemIdentifiers[0]))
            replacementEntries.append(.app(identifier: appIdentifier))
        default:
            replacementEntries.append(.app(identifier: appIdentifier))
        }

        var updated = topLevelEntries
        updated.remove(at: folderIndex)
        updated.insert(contentsOf: replacementEntries, at: folderIndex)
        topLevelEntries = updated

        applyCurrentTopLevelLayout()
        persistTopLevelLayout()
        scheduleFiltering(immediate: true)
        return true
    }

    func folder(with id: UUID) -> LaunchFolder? {
        for entry in topLevelDisplayEntries {
            if case let .folder(folder) = entry, folder.id == id {
                let visibleItems = settings.showHiddenApps
                    ? folder.items
                    : folder.items.filter { $0.isHidden == false }
                guard visibleItems.isEmpty == false else { return nil }
                return LaunchFolder(id: folder.id, name: folder.name, items: visibleItems)
            }
        }
        return nil
    }

    var visibleTopLevelDisplayEntries: [LaunchMenuTopLevelDisplayEntry] {
        if settings.showHiddenApps {
            return topLevelDisplayEntries
        }

        return topLevelDisplayEntries.compactMap { entry in
            switch entry {
            case let .app(item):
                return item.isHidden ? nil : .app(item)
            case let .folder(folder):
                let visibleItems = folder.items.filter { $0.isHidden == false }
                guard visibleItems.isEmpty == false else { return nil }
                return .folder(LaunchFolder(id: folder.id, name: folder.name, items: visibleItems))
            }
        }
    }

    func hideItem(identifier: String) {
        hiddenItemIdentifiers.insert(identifier)
        persistUserCustomizations()
        Task {
            await refreshApps()
        }
    }

    func renameItem(identifier: String, newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            customTitlesByIdentifier.removeValue(forKey: identifier)
        } else {
            customTitlesByIdentifier[identifier] = trimmedTitle
        }
        persistUserCustomizations()
        Task {
            await refreshApps()
        }
    }

    func addItemToDock(_ item: LaunchItem) throws {
        guard let appPath = item.appPath else {
            throw DockIntegrationError.invalidAppPath
        }
        try dockIntegration.addAppToDock(appPath: appPath)
    }

    func previewUninstall(for item: LaunchItem) throws -> AppUninstallPreview {
        try appUninstaller.previewUninstall(for: item)
    }

    func uninstallApp(using preview: AppUninstallPreview) async throws {
        try await appUninstaller.uninstall(using: preview)

        hiddenItemIdentifiers.remove(preview.itemStableIdentifier)
        customTitlesByIdentifier.removeValue(forKey: preview.itemStableIdentifier)
        persistUserCustomizations()

        await refreshApps()
    }

    @discardableResult
    func importSystemLaunchpadLayout() throws -> Int {
        let importedEntries = try launchpadImporter.importTopLevelEntries()
        guard importedEntries.isEmpty == false else {
            throw LaunchpadImportError.noImportableEntries
        }

        topLevelEntries = importedEntries
        applyCurrentTopLevelLayout()
        persistTopLevelLayout()
        scheduleFiltering(immediate: true)
        return importedEntries.count
    }

    @discardableResult
    func exportBackup() throws -> URL {
        try backupManager.exportBackup(layout: topLevelEntries, settings: settings)
    }

    @discardableResult
    func restoreBackup() throws -> Int {
        let payload = try backupManager.importBackup()

        topLevelEntries = payload.layout
        applyCurrentTopLevelLayout()
        persistTopLevelLayout()
        applySettings(payload.settings)
        scheduleFiltering(immediate: true)

        return topLevelEntries.count
    }

    func icon(for item: LaunchItem) -> NSImage? {
        iconCache.icon(for: item)
    }

    func applySettings(_ newSettings: LaunchSettings) {
        let shouldRescan = settings.showHiddenApps != newSettings.showHiddenApps

        settings = newSettings
        settingsStorage.save(newSettings)
        NotificationCenter.default.post(name: .launchMenuSettingsDidChange, object: newSettings)

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

    func reportError(_ message: String) {
        lastErrorMessage = message
    }

    private var selectedTab: SmartTabModel {
        tabs.first(where: { $0.id == selectedTabID }) ?? tabs.first ?? .all
    }

    private func resolveLayout(
        entries: [PersistedTopLevelEntry],
        itemsByIdentifier: [String: LaunchItem]
    ) -> (
        entries: [PersistedTopLevelEntry],
        orderedItems: [LaunchItem],
        displayEntries: [LaunchMenuTopLevelDisplayEntry]
    ) {
        var remainingItems = itemsByIdentifier
        var resolvedEntries: [PersistedTopLevelEntry] = []
        var orderedItems: [LaunchItem] = []
        var displayEntries: [LaunchMenuTopLevelDisplayEntry] = []

        for entry in entries {
            switch entry {
            case let .app(identifier):
                guard let item = remainingItems.removeValue(forKey: identifier) else {
                    continue
                }

                resolvedEntries.append(.app(identifier: identifier))
                orderedItems.append(item)
                displayEntries.append(.app(item))

            case let .folder(folder):
                var resolvedIdentifiers: [String] = []
                var folderItems: [LaunchItem] = []

                for identifier in folder.itemIdentifiers {
                    guard let item = remainingItems.removeValue(forKey: identifier) else {
                        continue
                    }

                    resolvedIdentifiers.append(identifier)
                    folderItems.append(item)
                    orderedItems.append(item)
                }

                if folderItems.isEmpty {
                    continue
                }

                if folderItems.count == 1 {
                    resolvedEntries.append(.app(identifier: resolvedIdentifiers[0]))
                    displayEntries.append(.app(folderItems[0]))
                    continue
                }

                let resolvedFolder = PersistedLayoutFolder(
                    id: folder.id,
                    name: normalizedFolderName(folder.name),
                    itemIdentifiers: resolvedIdentifiers
                )
                resolvedEntries.append(.folder(resolvedFolder))
                displayEntries.append(
                    .folder(
                        LaunchFolder(
                            id: resolvedFolder.id,
                            name: resolvedFolder.name,
                            items: folderItems
                        )
                    )
                )
            }
        }

        let sortedRemainingItems = remainingItems.values.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        for item in sortedRemainingItems {
            let identifier = item.stableIdentifier
            resolvedEntries.append(.app(identifier: identifier))
            orderedItems.append(item)
            displayEntries.append(.app(item))
        }

        return (
            entries: resolvedEntries,
            orderedItems: orderedItems,
            displayEntries: displayEntries
        )
    }

    private func applyCurrentTopLevelLayout() {
        let resolvedLayout = resolveLayout(
            entries: topLevelEntries,
            itemsByIdentifier: itemsByIdentifier
        )
        topLevelEntries = resolvedLayout.entries
        allItems = resolvedLayout.orderedItems
        topLevelDisplayEntries = resolvedLayout.displayEntries
    }

    private func persistTopLevelLayout() {
        layoutStore.saveTopLevelEntries(topLevelEntries)
    }

    private func indexOfTopLevelApp(with identifier: String) -> Int? {
        topLevelEntries.firstIndex { entry in
            if case let .app(appIdentifier) = entry {
                return appIdentifier == identifier
            }
            return false
        }
    }

    private func indexOfTopLevelFolder(with folderID: UUID) -> Int? {
        topLevelEntries.firstIndex { entry in
            if case let .folder(folder) = entry {
                return folder.id == folderID
            }
            return false
        }
    }

    private func applyUserCustomizations(to scannedItems: [LaunchItem]) -> [LaunchItem] {
        scannedItems.map { item in
            var updatedItem = item
            let identifier = item.stableIdentifier

            if let customTitle = customTitlesByIdentifier[identifier], customTitle.isEmpty == false {
                updatedItem.title = customTitle
            }
            updatedItem.isHidden = hiddenItemIdentifiers.contains(identifier)
            return updatedItem
        }
    }

    private func persistUserCustomizations() {
        let hiddenIdentifiers = Array(hiddenItemIdentifiers).sorted()
        userDefaults.set(hiddenIdentifiers, forKey: hiddenItemsKey)
        userDefaults.set(customTitlesByIdentifier, forKey: customTitlesKey)
    }

    private func normalizedFolderName(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return L10n.t("folder.default.name")
        }
        return trimmed
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
            let searchedItems = await searchService.search(query: query, in: scopedItems)
            let filteredItems: [LaunchItem]
            if settings.showHiddenApps {
                filteredItems = searchedItems
            } else {
                filteredItems = searchedItems.filter { $0.isHidden == false }
            }
            guard Task.isCancelled == false else { return }

            await MainActor.run {
                self.visibleItems = filteredItems
            }
        }
    }
}
