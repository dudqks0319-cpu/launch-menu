import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RootContentView: View {
    @ObservedObject var store: LaunchMenuStore
    let onCloseRequest: () -> Void

    @State private var displayMode: GridDisplayMode = .paged
    @State private var currentPage = 0
    @State private var showSettings = false
    @State private var isEditing = false
    @State private var presentedFolderID: UUID?
    @State private var optionMonitor: Any?
    @State private var optionKeyWasDown = false
    @State private var isFolderDropTargeted = false
    @State private var pendingDockItem: LaunchItem?
    @State private var showDockConfirmation = false
    @State private var pendingUninstallPreview: AppUninstallPreview?
    @State private var showUninstallConfirmation = false
    @State private var renameTargetItem: LaunchItem?
    @State private var renameDraftName = ""
    @State private var selectedCategory: SmartCategory = .all

    var body: some View {
        ZStack {
            VisualEffectBlurView(
                material: blurMaterial,
                blendingMode: .behindWindow,
                state: .active
            )
            .overlay(backgroundOverlayColor.opacity(store.settings.backgroundOpacity))
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                header

                SmartTabsContainerView(
                    tabs: store.tabs,
                    selectedPredicate: Binding(
                        get: { store.selectedTabID },
                        set: { store.selectTab(with: $0) }
                    )
                )

                SearchContainerView(
                    query: $store.searchQuery,
                    results: categoryFilteredVisibleItems,
                    showsResultList: isSearching,
                    onLaunch: { item in
                        store.launch(item)
                    },
                    iconProvider: { item in
                        store.icon(for: item)
                    }
                )

                SmartCategoryChipsView(selectedCategory: $selectedCategory)

                controlsRow

                GridContainerView(
                    items: gridItems,
                    displayMode: displayMode,
                    currentPage: $currentPage,
                    pageSize: 24,
                    columnCount: store.settings.gridColumnCount,
                    iconSize: CGFloat(store.settings.iconSize),
                    showsAppNames: store.settings.showsAppNames,
                    isEditing: isEditing,
                    onEnterEditing: {
                        if canEnterEditing {
                            isEditing = true
                        }
                    },
                    onExitEditingByBackground: {
                        isEditing = false
                    },
                    onMoveItem: { draggedIdentifier, targetIdentifier in
                        store.moveItem(draggedIdentifier: draggedIdentifier, before: targetIdentifier)
                    },
                    onLaunch: { item in
                        store.launch(item)
                    },
                    onRevealInFinder: { item in
                        guard let appPath = item.appPath else { return }
                        NSWorkspace.shared.selectFile(appPath, inFileViewerRootedAtPath: "")
                    },
                    onAddToDock: { item in
                        pendingDockItem = item
                        showDockConfirmation = true
                    },
                    onUninstallItem: { item in
                        do {
                            pendingUninstallPreview = try store.previewUninstall(for: item)
                            showUninstallConfirmation = true
                        } catch {
                            store.reportError(error.localizedDescription)
                        }
                    },
                    onHideItem: { item in
                        store.hideItem(identifier: item.stableIdentifier)
                    },
                    onRenameItem: { item in
                        renameTargetItem = item
                        renameDraftName = item.title
                    },
                    onOpenFolder: { folder in
                        withAnimation(.easeInOut(duration: 0.16)) {
                            presentedFolderID = folder.folderID
                        }
                    },
                    onCreateFolder: { sourceIdentifier, targetIdentifier in
                        guard canEnterEditing else { return }
                        if let createdFolder = store.createFolder(
                            from: sourceIdentifier,
                            and: targetIdentifier,
                            name: L10n.t("folder.default.name")
                        ) {
                            presentedFolderID = createdFolder.id
                        }
                    },
                    iconProvider: { item in
                        store.icon(for: item)
                    }
                )
            }
            .padding(22)

            if let presentedFolder {
                folderOverlay(for: presentedFolder)
            }
        }
        .frame(minWidth: 960, minHeight: 700)
        .preferredColorScheme(preferredColorScheme)
        .onAppear(perform: setupOptionMonitor)
        .onDisappear(perform: teardownOptionMonitor)
        .onExitCommand {
            if presentedFolder != nil {
                closePresentedFolder()
            } else if isEditing {
                isEditing = false
            } else {
                onCloseRequest()
            }
        }
        .onChange(of: store.searchQuery) { _, _ in
            currentPage = 0
            if canEnterEditing == false {
                isEditing = false
            }
            presentedFolderID = nil
        }
        .onChange(of: store.selectedTabID) { _, _ in
            currentPage = 0
            if canEnterEditing == false {
                isEditing = false
            }
            presentedFolderID = nil
        }
        .onChange(of: store.topLevelDisplayEntries) { _, _ in
            if let presentedFolderID, filteredFolder(with: presentedFolderID) == nil {
                self.presentedFolderID = nil
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            currentPage = 0
            if canEnterEditing == false {
                isEditing = false
            }
            if let presentedFolderID, filteredFolder(with: presentedFolderID) == nil {
                self.presentedFolderID = nil
            }
        }
        .onChange(of: showUninstallConfirmation) { _, newValue in
            if newValue == false {
                pendingUninstallPreview = nil
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsContainerView(
                settings: Binding(
                    get: { store.settings },
                    set: { store.applySettings($0) }
                ),
                onReset: {
                    store.resetSettings()
                },
                onRefreshApps: {
                    Task {
                        await store.refreshApps()
                    }
                },
                onImportLaunchpad: {
                    try store.importSystemLaunchpadLayout()
                },
                onExportBackup: {
                    try store.exportBackup()
                },
                onRestoreBackup: {
                    try store.restoreBackup()
                }
            )
            .frame(minWidth: 480, minHeight: 420)
        }
        .sheet(item: $renameTargetItem) { item in
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("context.rename.app"))
                    .font(.headline)
                TextField(L10n.t("rename.new.name.placeholder"), text: $renameDraftName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button(L10n.t("common.cancel"), role: .cancel) {
                        renameTargetItem = nil
                    }
                    Button(L10n.t("common.save")) {
                        store.renameItem(identifier: item.stableIdentifier, newTitle: renameDraftName)
                        renameTargetItem = nil
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(width: 320)
        }
        .confirmationDialog(
            L10n.t("dock.add.confirm"),
            isPresented: $showDockConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.t("common.add"), role: .destructive) {
                if let pendingDockItem {
                    do {
                        try store.addItemToDock(pendingDockItem)
                    } catch {
                        store.reportError(error.localizedDescription)
                    }
                }
                pendingDockItem = nil
            }
            Button(L10n.t("common.cancel"), role: .cancel) {
                pendingDockItem = nil
            }
        }
        .confirmationDialog(
            uninstallConfirmationTitle,
            isPresented: $showUninstallConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.t("common.delete"), role: .destructive) {
                guard let preview = pendingUninstallPreview else { return }
                Task {
                    do {
                        try await store.uninstallApp(using: preview)
                    } catch {
                        store.reportError(error.localizedDescription)
                    }
                    pendingUninstallPreview = nil
                }
            }
            Button(L10n.t("common.cancel"), role: .cancel) {
                pendingUninstallPreview = nil
            }
        }
        .alert(L10n.t("error.execution.title"), isPresented: Binding(
            get: { store.lastErrorMessage != nil },
            set: { newValue in
                if newValue == false {
                    store.clearError()
                }
            }
        )) {
            Button(L10n.t("common.confirm"), role: .cancel) {
                store.clearError()
            }
        } message: {
            Text(store.lastErrorMessage ?? L10n.t("error.unknown"))
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t("app.title"))
                    .font(.system(size: 30, weight: .semibold))

                Text(L10n.f("app.subtitle.hotkeys.format", store.settings.toggleHotkey.displayText))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                if isEditing {
                    Text(L10n.t("edit.mode"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task {
                    await store.refreshApps()
                }
            } label: {
                Label(L10n.t("action.refresh"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Button {
                showSettings = true
            } label: {
                Label(L10n.t("action.settings"), systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)

            Button(L10n.t("action.close"), action: onCloseRequest)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.cancelAction)
        }
    }

    private var controlsRow: some View {
        HStack {
            Picker(L10n.t("grid.display.mode"), selection: $displayMode) {
                ForEach(GridDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 190)

            Stepper(value: Binding(
                get: { store.settings.gridColumnCount },
                set: { newValue in
                    var updated = store.settings
                    updated.gridColumnCount = min(max(newValue, 4), 10)
                    store.applySettings(updated)
                }
            ), in: 4...10) {
                Text(L10n.f("settings.grid.columns", store.settings.gridColumnCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if canEnterEditing == false {
                Text(L10n.t("edit.mode.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(L10n.f("grid.item.count", gridItems.count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var gridItems: [GridDisplayItem] {
        if isDefaultAllView {
            return categoryFilteredTopLevelDisplayEntries.map(makeGridItem)
        }
        return categoryFilteredVisibleItems.map { .app(.init(item: $0)) }
    }

    private var isSearching: Bool {
        store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var blurMaterial: NSVisualEffectView.Material {
        switch store.settings.backgroundStyle {
        case .liquidGlass:
            return .hudWindow
        case .solidBlack, .customColor:
            return .underWindowBackground
        }
    }

    private var backgroundOverlayColor: Color {
        switch store.settings.backgroundStyle {
        case .liquidGlass:
            return .black
        case .solidBlack:
            return .black
        case .customColor:
            return Color(hex: store.settings.customBackgroundHex) ?? .black
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.settings.appearanceMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private var isDefaultAllView: Bool {
        store.selectedTabID == SmartTabModel.all.id && isSearching == false
    }

    private var canEnterEditing: Bool {
        isDefaultAllView && selectedCategory == .all
    }

    private var uninstallConfirmationTitle: String {
        guard let preview = pendingUninstallPreview else {
            return L10n.t("uninstall.confirm.generic")
        }
        return L10n.f("uninstall.confirm.detail", preview.appDisplayName, preview.relatedFileCount)
    }

    private var presentedFolder: LaunchFolder? {
        guard let presentedFolderID else { return nil }
        return filteredFolder(with: presentedFolderID)
    }

    private var categoryFilteredVisibleItems: [LaunchItem] {
        guard selectedCategory != .all else {
            return store.visibleItems
        }
        return store.visibleItems.filter(isVisibleInSelectedCategory)
    }

    private var categoryFilteredTopLevelDisplayEntries: [LaunchMenuTopLevelDisplayEntry] {
        guard selectedCategory != .all else {
            return store.visibleTopLevelDisplayEntries
        }

        return store.visibleTopLevelDisplayEntries.compactMap { entry in
            switch entry {
            case let .app(item):
                return isVisibleInSelectedCategory(item) ? .app(item) : nil

            case let .folder(folder):
                let filteredItems = folder.items.filter(isVisibleInSelectedCategory)
                guard filteredItems.isEmpty == false else { return nil }
                return .folder(LaunchFolder(id: folder.id, name: folder.name, items: filteredItems))
            }
        }
    }

    private func isVisibleInSelectedCategory(_ item: LaunchItem) -> Bool {
        if selectedCategory == .all {
            return true
        }
        return SmartCategorizer.category(for: item) == selectedCategory
    }

    private func filteredFolder(with id: UUID) -> LaunchFolder? {
        for entry in categoryFilteredTopLevelDisplayEntries {
            if case let .folder(folder) = entry, folder.id == id {
                return folder
            }
        }
        return nil
    }

    private func makeGridItem(from entry: LaunchMenuTopLevelDisplayEntry) -> GridDisplayItem {
        switch entry {
        case let .app(item):
            return .app(.init(item: item))
        case let .folder(folder):
            return .folder(
                .init(
                    folderID: folder.id,
                    name: folder.name,
                    items: folder.items
                )
            )
        }
    }

    private func setupOptionMonitor() {
        guard optionMonitor == nil else { return }
        optionMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let optionDown = event.modifierFlags.contains(.option)
            if optionDown && optionKeyWasDown == false {
                if canEnterEditing {
                    isEditing.toggle()
                }
            }
            optionKeyWasDown = optionDown
            return event
        }
    }

    private func teardownOptionMonitor() {
        if let optionMonitor {
            NSEvent.removeMonitor(optionMonitor)
            self.optionMonitor = nil
        }
        optionKeyWasDown = false
    }

    private func closePresentedFolder() {
        withAnimation(.easeInOut(duration: 0.16)) {
            presentedFolderID = nil
        }
    }

    private func refreshPresentedFolderState(folderID: UUID) {
        if filteredFolder(with: folderID) == nil {
            presentedFolderID = nil
        }
    }

    private func handleFolderDropOut(providers: [NSItemProvider], folderID: UUID) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let identifier = object as? NSString else { return }
            Task { @MainActor in
                _ = store.removeAppFromFolder(appIdentifier: identifier as String, folderID: folderID)
                refreshPresentedFolderState(folderID: folderID)
            }
        }

        return true
    }

    @ViewBuilder
    private func folderOverlay(for folder: LaunchFolder) -> some View {
        ZStack {
            Color.black.opacity(isFolderDropTargeted ? 0.42 : 0.34)
                .ignoresSafeArea()
                .onTapGesture {
                    closePresentedFolder()
                }
                .onDrop(of: [UTType.text], isTargeted: $isFolderDropTargeted) { providers in
                    handleFolderDropOut(providers: providers, folderID: folder.id)
                }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(folder.name)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button {
                        closePresentedFolder()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }

                FolderContainerView(
                    folder: folder,
                    iconProvider: { item in
                        store.icon(for: item)
                    },
                    onLaunch: { item in
                        store.launch(item)
                        closePresentedFolder()
                    },
                    onRename: { folderID, newName in
                        _ = store.renameFolder(folderID: folderID, to: newName)
                        refreshPresentedFolderState(folderID: folderID)
                    },
                    onRemoveItem: { folderID, item in
                        _ = store.removeAppFromFolder(appIdentifier: item.stableIdentifier, folderID: folderID)
                        refreshPresentedFolderState(folderID: folderID)
                    }
                )
            }
            .padding(16)
            .frame(width: 420)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 8)
        }
        .transition(.opacity)
        .zIndex(2)
    }
}

private extension Color {
    init?(hex: String) {
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard sanitized.count == 6, let value = Int(sanitized, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self = Color(red: red, green: green, blue: blue)
    }
}

private enum SmartCategory: String, CaseIterable, Identifiable {
    case all
    case developmentTools
    case design
    case game
    case social
    case productivity
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return L10n.t("category.all")
        case .developmentTools:
            return L10n.t("category.development")
        case .design:
            return L10n.t("category.design")
        case .game:
            return L10n.t("category.game")
        case .social:
            return L10n.t("category.social")
        case .productivity:
            return L10n.t("category.productivity")
        case .other:
            return L10n.t("category.other")
        }
    }
}

private struct SmartCategorizer {
    static func category(for item: LaunchItem) -> SmartCategory {
        guard let categoryKeyword = item.keywords.first(where: isLSApplicationCategoryKeyword) else {
            return .other
        }
        return category(forLSApplicationCategoryKeyword: categoryKeyword)
    }

    static func category(forLSApplicationCategoryKeyword rawKeyword: String) -> SmartCategory {
        let suffix = normalizedCategorySuffix(from: rawKeyword)

        if developmentCategorySuffixes.contains(suffix) {
            return .developmentTools
        }
        if designCategorySuffixes.contains(suffix) {
            return .design
        }
        if suffix == "games" || suffix.hasSuffix("-games") {
            return .game
        }
        if socialCategorySuffixes.contains(suffix) {
            return .social
        }
        if productivityCategorySuffixes.contains(suffix) {
            return .productivity
        }

        return .other
    }

    private static let lsCategoryPrefix = "public.app-category."

    private static let developmentCategorySuffixes: Set<String> = [
        "developer-tools"
    ]

    private static let designCategorySuffixes: Set<String> = [
        "graphics-design",
        "photography",
        "video"
    ]

    private static let socialCategorySuffixes: Set<String> = [
        "social-networking"
    ]

    private static let productivityCategorySuffixes: Set<String> = [
        "productivity",
        "business",
        "education",
        "finance",
        "reference",
        "utilities"
    ]

    private static func isLSApplicationCategoryKeyword(_ keyword: String) -> Bool {
        keyword
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .contains("app-category")
    }

    private static func normalizedCategorySuffix(from rawKeyword: String) -> String {
        let normalized = rawKeyword
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        if let range = normalized.range(of: lsCategoryPrefix) {
            return String(normalized[range.upperBound...])
        }

        return normalized
    }
}

private struct SmartCategoryChipsView: View {
    var categories: [SmartCategory]
    @Binding private var selectedCategory: SmartCategory

    init(
        categories: [SmartCategory] = SmartCategory.allCases,
        selectedCategory: Binding<SmartCategory>
    ) {
        self.categories = categories
        _selectedCategory = selectedCategory
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.title)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(
                                selectedCategory == category
                                    ? Color.white
                                    : Color.primary
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        selectedCategory == category
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.12)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
