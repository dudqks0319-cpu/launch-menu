import AppKit
import SwiftUI

struct FolderContainerView: View {
    var folder: LaunchFolder
    var iconProvider: (LaunchItem) -> NSImage?
    var onLaunch: (LaunchItem) -> Void
    var onRename: (LaunchFolder.ID, String) -> Void
    var onRemoveItem: (LaunchFolder.ID, LaunchItem) -> Void

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(minimum: 96, maximum: 150), spacing: 12), count: 3)

    init(
        folder: LaunchFolder = LaunchFolder(),
        iconProvider: @escaping (LaunchItem) -> NSImage? = { _ in nil },
        onLaunch: @escaping (LaunchItem) -> Void = { _ in },
        onRename: @escaping (LaunchFolder.ID, String) -> Void = { _, _ in },
        onRemoveItem: @escaping (LaunchFolder.ID, LaunchItem) -> Void = { _, _ in }
    ) {
        self.folder = folder
        self.iconProvider = iconProvider
        self.onLaunch = onLaunch
        self.onRename = onRename
        self.onRemoveItem = onRemoveItem
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FolderHeaderView(
                folder: folder,
                iconProvider: iconProvider,
                onRename: { newName in
                    onRename(folder.id, newName)
                }
            )

            if visibleItems.isEmpty {
                Text(L10n.t("folder.empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 120)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visibleItems) { item in
                        appCell(for: item)
                    }
                }

                if folder.items.count > visibleItems.count {
                    Text(L10n.f("folder.more.apps", folder.items.count - visibleItems.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }

    private var visibleItems: [LaunchItem] {
        Array(folder.items.prefix(9))
    }

    private func appCell(for item: LaunchItem) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                onLaunch(item)
            } label: {
                VStack(spacing: 8) {
                    appIcon(for: item)

                    Text(item.title)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 96)
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                onRemoveItem(folder.id, item)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(8)
            .help(L10n.t("folder.remove.from.folder"))
        }
        .onDrag {
            NSItemProvider(object: item.stableIdentifier as NSString)
        }
    }

    @ViewBuilder
    private func appIcon(for item: LaunchItem) -> some View {
        if let icon = iconProvider(item) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 44, height: 44)
        } else {
            Image(systemName: "app.fill")
                .font(.title3)
                .frame(width: 44, height: 44)
                .foregroundStyle(.secondary)
        }
    }
}
