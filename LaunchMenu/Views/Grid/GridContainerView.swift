import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum GridDisplayMode: String, CaseIterable {
    case paged
    case scroll

    var title: String {
        switch self {
        case .paged:
            return L10n.t("grid.display.paged")
        case .scroll:
            return L10n.t("grid.display.scroll")
        }
    }
}

enum GridDisplayItem: Identifiable, Hashable {
    case app(App)
    case folder(Folder)

    struct App: Identifiable, Hashable {
        let item: LaunchItem

        init(item: LaunchItem) {
            self.item = item
        }

        var id: String {
            item.stableIdentifier
        }
    }

    struct Folder: Identifiable, Hashable {
        let folderID: UUID
        var name: String
        var items: [LaunchItem]

        init(folderID: UUID, name: String, items: [LaunchItem] = []) {
            self.folderID = folderID
            self.name = name
            self.items = items
        }

        var id: String {
            "folder:\(folderID.uuidString.lowercased())"
        }

        var itemCount: Int {
            items.count
        }
    }

    var id: String {
        stableIdentifier
    }

    var stableIdentifier: String {
        switch self {
        case .app(let app):
            return app.item.stableIdentifier
        case .folder(let folder):
            return folder.id
        }
    }

    var isApp: Bool {
        switch self {
        case .app:
            return true
        case .folder:
            return false
        }
    }
}

struct GridContainerView: View {
    var items: [GridDisplayItem]
    var displayMode: GridDisplayMode
    @Binding private var currentPage: Int
    var pageSize: Int
    var columnCount: Int
    var iconSize: CGFloat
    var showsAppNames: Bool
    var isEditing: Bool
    var onEnterEditing: () -> Void
    var onExitEditingByBackground: () -> Void
    var onMoveItem: (String, String) -> Void
    var onLaunch: (LaunchItem) -> Void
    var onRevealInFinder: (LaunchItem) -> Void
    var onAddToDock: (LaunchItem) -> Void
    var onUninstallItem: (LaunchItem) -> Void
    var onHideItem: (LaunchItem) -> Void
    var onRenameItem: (LaunchItem) -> Void
    var onOpenFolder: (GridDisplayItem.Folder) -> Void
    var onCreateFolder: ((String, String) -> Void)?
    var iconProvider: (LaunchItem) -> NSImage?

    @State private var draggingIdentifier: String?
    @State private var draggingIsApp = false
    @State private var pendingFolderCreation: DispatchWorkItem?
    @State private var folderCreationSourceIdentifier: String?
    @State private var folderCreationTargetIdentifier: String?
    @State private var inputMonitor: Any?
    @State private var horizontalScrollAccumulator: CGFloat = 0
    @State private var pageTransitionDirection: Int = 1

    init(
        items: [GridDisplayItem] = [],
        displayMode: GridDisplayMode = .paged,
        currentPage: Binding<Int> = .constant(0),
        pageSize: Int = 24,
        columnCount: Int = 6,
        iconSize: CGFloat = 56,
        showsAppNames: Bool = true,
        isEditing: Bool = false,
        onEnterEditing: @escaping () -> Void = {},
        onExitEditingByBackground: @escaping () -> Void = {},
        onMoveItem: @escaping (String, String) -> Void = { _, _ in },
        onLaunch: @escaping (LaunchItem) -> Void = { _ in },
        onRevealInFinder: @escaping (LaunchItem) -> Void = { _ in },
        onAddToDock: @escaping (LaunchItem) -> Void = { _ in },
        onUninstallItem: @escaping (LaunchItem) -> Void = { _ in },
        onHideItem: @escaping (LaunchItem) -> Void = { _ in },
        onRenameItem: @escaping (LaunchItem) -> Void = { _ in },
        onOpenFolder: @escaping (GridDisplayItem.Folder) -> Void = { _ in },
        onCreateFolder: ((String, String) -> Void)? = nil,
        iconProvider: @escaping (LaunchItem) -> NSImage? = { _ in nil }
    ) {
        self.items = items
        self.displayMode = displayMode
        _currentPage = currentPage
        self.pageSize = max(pageSize, 1)
        self.columnCount = min(max(columnCount, 4), 10)
        self.iconSize = min(max(iconSize, 48), 96)
        self.showsAppNames = showsAppNames
        self.isEditing = isEditing
        self.onEnterEditing = onEnterEditing
        self.onExitEditingByBackground = onExitEditingByBackground
        self.onMoveItem = onMoveItem
        self.onLaunch = onLaunch
        self.onRevealInFinder = onRevealInFinder
        self.onAddToDock = onAddToDock
        self.onUninstallItem = onUninstallItem
        self.onHideItem = onHideItem
        self.onRenameItem = onRenameItem
        self.onOpenFolder = onOpenFolder
        self.onCreateFolder = onCreateFolder
        self.iconProvider = iconProvider
    }

    var body: some View {
        VStack(spacing: 12) {
            if items.isEmpty {
                placeholder
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(visibleItems) { item in
                            gridCell(for: item)
                        }
                    }
                    .id(displayMode == .paged ? "page-\(currentPage)" : "scroll")
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: pageTransitionDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: pageTransitionDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
                        )
                    )
                    .animation(
                        .spring(response: 0.22, dampingFraction: 0.82),
                        value: visibleItems.map(\.stableIdentifier)
                    )
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEditing {
                        onExitEditingByBackground()
                    }
                }
            }

            if displayMode == .paged {
                paginationControls
            }
        }
        .padding(16)
        .onAppear {
            clampCurrentPage()
            setupInputMonitor()
        }
        .onChange(of: items.count) { _, _ in
            clampCurrentPage()
        }
        .onChange(of: displayMode) { _, _ in
            clampCurrentPage()
            horizontalScrollAccumulator = 0
        }
        .onChange(of: isEditing) { _, newValue in
            if newValue == false {
                resetDragState()
            }
        }
        .onDisappear {
            resetDragState()
            teardownInputMonitor()
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 110, maximum: 180), spacing: 12), count: columnCount)
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.title2)
            Text(L10n.t("grid.empty"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                onExitEditingByBackground()
            }
        }
    }

    private var visibleItems: [GridDisplayItem] {
        switch displayMode {
        case .scroll:
            return items
        case .paged:
            let start = min(currentPage * pageSize, items.count)
            let end = min(start + pageSize, items.count)
            guard start < end else { return [] }
            return Array(items[start..<end])
        }
    }

    private var totalPages: Int {
        guard items.isEmpty == false else { return 1 }
        return ((items.count - 1) / pageSize) + 1
    }

    @ViewBuilder
    private func gridCell(for item: GridDisplayItem) -> some View {
        let identifier = item.stableIdentifier

        if isEditing {
            cellContent(for: item, isEditing: true)
            .opacity(draggingIdentifier == identifier ? 0.45 : 1.0)
            .onDrag {
                startDragging(item)
                return NSItemProvider(object: identifier as NSString)
            }
            .onDrop(
                of: [UTType.text],
                delegate: GridItemDropDelegate(
                    targetIdentifier: identifier,
                    targetIsApp: item.isApp,
                    draggingIdentifier: $draggingIdentifier,
                    draggingIsApp: $draggingIsApp,
                    pendingFolderCreation: $pendingFolderCreation,
                    folderCreationSourceIdentifier: $folderCreationSourceIdentifier,
                    folderCreationTargetIdentifier: $folderCreationTargetIdentifier,
                    onMoveItem: onMoveItem,
                    onCreateFolder: onCreateFolder
                )
            )
        } else {
            cellContent(for: item, isEditing: false)
        }
    }

    @ViewBuilder
    private func cellContent(for item: GridDisplayItem, isEditing: Bool) -> some View {
        switch item {
        case .app(let app):
            GridItemCellView(
                item: app.item,
                icon: iconProvider(app.item),
                isEditing: isEditing,
                onEnterEditing: onEnterEditing,
                onLaunch: onLaunch,
                onRevealInFinder: onRevealInFinder,
                onAddToDock: onAddToDock,
                onUninstall: onUninstallItem,
                onHide: onHideItem,
                onRename: onRenameItem,
                iconSize: iconSize,
                showsAppName: showsAppNames
            )
        case .folder(let folder):
            FolderGridCellView(
                folder: folder,
                isEditing: isEditing,
                onEnterEditing: onEnterEditing,
                iconProvider: iconProvider,
                showsName: showsAppNames,
                onOpenFolder: {
                    onOpenFolder(folder)
                }
            )
        }
    }

    private var paginationControls: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(totalPages, 1), id: \.self) { page in
                Button {
                    moveToPage(page)
                } label: {
                    Circle()
                        .fill(page == currentPage ? Color.white : Color.white.opacity(0.35))
                        .frame(width: 8, height: 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.f("grid.page.accessibility", page + 1))
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    private func clampCurrentPage() {
        if displayMode == .scroll {
            currentPage = 0
            return
        }

        let maxPage = max(totalPages - 1, 0)
        currentPage = min(max(currentPage, 0), maxPage)
    }

    private func startDragging(_ item: GridDisplayItem) {
        draggingIdentifier = item.stableIdentifier
        draggingIsApp = item.isApp
        cancelPendingFolderCreation()
    }

    private func moveToNextPage() {
        guard displayMode == .paged else { return }
        let target = min(currentPage + 1, totalPages - 1)
        guard target != currentPage else { return }
        pageTransitionDirection = 1
        withAnimation(.easeInOut(duration: 0.22)) {
            currentPage = target
        }
    }

    private func moveToPreviousPage() {
        guard displayMode == .paged else { return }
        let target = max(currentPage - 1, 0)
        guard target != currentPage else { return }
        pageTransitionDirection = -1
        withAnimation(.easeInOut(duration: 0.22)) {
            currentPage = target
        }
    }

    private func moveToPage(_ page: Int) {
        guard displayMode == .paged else { return }
        let target = min(max(page, 0), max(totalPages - 1, 0))
        guard target != currentPage else { return }
        pageTransitionDirection = target >= currentPage ? 1 : -1
        withAnimation(.easeInOut(duration: 0.22)) {
            currentPage = target
        }
    }

    private func setupInputMonitor() {
        guard inputMonitor == nil else { return }
        inputMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { event in
            switch event.type {
            case .scrollWheel:
                handleHorizontalScroll(event)
                return event
            case .keyDown:
                return handleKeyboardPageSwitch(event) ? nil : event
            default:
                return event
            }
        }
    }

    private func teardownInputMonitor() {
        if let inputMonitor {
            NSEvent.removeMonitor(inputMonitor)
            self.inputMonitor = nil
        }
        horizontalScrollAccumulator = 0
    }

    private func handleHorizontalScroll(_ event: NSEvent) {
        guard displayMode == .paged else { return }

        let deltaX = event.scrollingDeltaX
        let threshold: CGFloat = 30

        if abs(deltaX) < 0.5 {
            return
        }

        horizontalScrollAccumulator += deltaX

        if horizontalScrollAccumulator >= threshold {
            moveToPreviousPage()
            horizontalScrollAccumulator = 0
        } else if horizontalScrollAccumulator <= -threshold {
            moveToNextPage()
            horizontalScrollAccumulator = 0
        }
    }

    private func handleKeyboardPageSwitch(_ event: NSEvent) -> Bool {
        guard displayMode == .paged else { return false }
        guard event.modifierFlags.contains(.command) else { return false }

        switch event.keyCode {
        case 123:
            moveToPreviousPage()
            return true
        case 124:
            moveToNextPage()
            return true
        default:
            return false
        }
    }

    private func cancelPendingFolderCreation() {
        pendingFolderCreation?.cancel()
        pendingFolderCreation = nil
        folderCreationSourceIdentifier = nil
        folderCreationTargetIdentifier = nil
    }

    private func resetDragState() {
        draggingIdentifier = nil
        draggingIsApp = false
        cancelPendingFolderCreation()
    }
}

private struct GridItemDropDelegate: DropDelegate {
    let targetIdentifier: String
    let targetIsApp: Bool
    @Binding var draggingIdentifier: String?
    @Binding var draggingIsApp: Bool
    @Binding var pendingFolderCreation: DispatchWorkItem?
    @Binding var folderCreationSourceIdentifier: String?
    @Binding var folderCreationTargetIdentifier: String?
    let onMoveItem: (String, String) -> Void
    let onCreateFolder: ((String, String) -> Void)?

    func dropEntered(info: DropInfo) {
        guard let draggingIdentifier else { return }
        guard draggingIdentifier != targetIdentifier else { return }

        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
            onMoveItem(draggingIdentifier, targetIdentifier)
        }
        scheduleFolderCreationIfNeeded(sourceIdentifier: draggingIdentifier)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if let draggingIdentifier {
            scheduleFolderCreationIfNeeded(sourceIdentifier: draggingIdentifier)
        }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        clearDragState()
        return true
    }

    func dropExited(info: DropInfo) {
        if folderCreationTargetIdentifier == targetIdentifier {
            cancelFolderCreation()
        }
    }

    private func clearDragState() {
        draggingIdentifier = nil
        draggingIsApp = false
        cancelFolderCreation()
    }

    private func cancelFolderCreation() {
        pendingFolderCreation?.cancel()
        pendingFolderCreation = nil
        folderCreationSourceIdentifier = nil
        folderCreationTargetIdentifier = nil
    }

    private func scheduleFolderCreationIfNeeded(sourceIdentifier: String) {
        guard let onCreateFolder else {
            cancelFolderCreation()
            return
        }
        guard draggingIsApp, targetIsApp else {
            cancelFolderCreation()
            return
        }
        guard sourceIdentifier != targetIdentifier else {
            cancelFolderCreation()
            return
        }

        let alreadyScheduledForTarget =
            pendingFolderCreation != nil &&
            folderCreationSourceIdentifier == sourceIdentifier &&
            folderCreationTargetIdentifier == targetIdentifier

        guard alreadyScheduledForTarget == false else { return }

        cancelFolderCreation()
        folderCreationSourceIdentifier = sourceIdentifier
        folderCreationTargetIdentifier = targetIdentifier

        let workItem = DispatchWorkItem {
            guard draggingIdentifier == sourceIdentifier else { return }
            guard folderCreationSourceIdentifier == sourceIdentifier else { return }
            guard folderCreationTargetIdentifier == targetIdentifier else { return }
            onCreateFolder(sourceIdentifier, targetIdentifier)
            clearDragState()
        }

        pendingFolderCreation = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }
}

private struct FolderGridCellView: View {
    let folder: GridDisplayItem.Folder
    var isEditing: Bool
    var onEnterEditing: () -> Void
    var iconProvider: (LaunchItem) -> NSImage?
    var showsName: Bool
    var onOpenFolder: () -> Void

    @State private var jigglePhase = false
    @State private var jiggleDelay = Double.random(in: 0...0.08)

    var body: some View {
        FolderIconView(
            folderName: folder.name,
            items: folder.items,
            iconProvider: iconProvider,
            showsName: showsName
        )
        .frame(maxWidth: .infinity, minHeight: 88)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .rotationEffect(isEditing ? .degrees(jigglePhase ? 2 : -2) : .zero)
        .animation(
            isEditing
            ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true).delay(jiggleDelay)
            : .easeOut(duration: 0.12),
            value: jigglePhase
        )
        .onTapGesture {
            guard isEditing == false else { return }
            onOpenFolder()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            onEnterEditing()
        }
        .onAppear {
            jigglePhase = isEditing
        }
        .onChange(of: isEditing) { _, newValue in
            jigglePhase = newValue
            if newValue == false {
                jiggleDelay = Double.random(in: 0...0.08)
            }
        }
    }
}
