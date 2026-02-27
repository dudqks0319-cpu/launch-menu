import AppKit
import SwiftUI

enum GridDisplayMode: String, CaseIterable {
    case paged
    case scroll

    var title: String {
        switch self {
        case .paged:
            return "페이지"
        case .scroll:
            return "스크롤"
        }
    }
}

struct GridContainerView: View {
    var items: [LaunchItem]
    var displayMode: GridDisplayMode
    @Binding private var currentPage: Int
    var pageSize: Int
    var columnCount: Int
    var onLaunch: (LaunchItem) -> Void
    var iconProvider: (LaunchItem) -> NSImage?

    init(
        items: [LaunchItem] = [],
        displayMode: GridDisplayMode = .paged,
        currentPage: Binding<Int> = .constant(0),
        pageSize: Int = 24,
        columnCount: Int = 6,
        onLaunch: @escaping (LaunchItem) -> Void = { _ in },
        iconProvider: @escaping (LaunchItem) -> NSImage? = { _ in nil }
    ) {
        self.items = items
        self.displayMode = displayMode
        _currentPage = currentPage
        self.pageSize = max(pageSize, 1)
        self.columnCount = min(max(columnCount, 4), 10)
        self.onLaunch = onLaunch
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
                            GridItemCellView(
                                item: item,
                                icon: iconProvider(item),
                                onLaunch: onLaunch
                            )
                        }
                    }
                }
            }

            if displayMode == .paged {
                paginationControls
            }
        }
        .padding(16)
        .onAppear(perform: clampCurrentPage)
        .onChange(of: items.count) { _, _ in
            clampCurrentPage()
        }
        .onChange(of: displayMode) { _, _ in
            clampCurrentPage()
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 110, maximum: 180), spacing: 12), count: columnCount)
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.title2)
            Text("표시할 앱이 없습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var visibleItems: [LaunchItem] {
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

    private var paginationControls: some View {
        HStack(spacing: 10) {
            Button {
                currentPage = max(currentPage - 1, 0)
            } label: {
                Label("이전", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(currentPage <= 0)

            Text("\(currentPage + 1) / \(totalPages)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                currentPage = min(currentPage + 1, totalPages - 1)
            } label: {
                Label("다음", systemImage: "chevron.right")
            }
            .buttonStyle(.bordered)
            .disabled(currentPage >= totalPages - 1)
        }
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
}
