import AppKit
import SwiftUI

struct FolderIconView: View {
    var folderName: String
    var items: [LaunchItem]
    var iconProvider: (LaunchItem) -> NSImage?
    var showsName: Bool

    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    init(
        folderName: String,
        items: [LaunchItem],
        iconProvider: @escaping (LaunchItem) -> NSImage? = { _ in nil },
        showsName: Bool = true
    ) {
        self.folderName = folderName
        self.items = items
        self.iconProvider = iconProvider
        self.showsName = showsName
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)

                LazyVGrid(columns: gridColumns, spacing: 4) {
                    ForEach(0..<9, id: \.self) { index in
                        miniIconCell(at: index)
                    }
                }
                .padding(8)
            }
            .frame(width: 76, height: 76)

            if showsName {
                Text(folderName)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 88)
            }
        }
    }

    @ViewBuilder
    private func miniIconCell(at index: Int) -> some View {
        if index < items.count, let icon = iconProvider(items[index]) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 16, height: 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else if index < items.count {
            Image(systemName: "app.fill")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.quaternary.opacity(0.2))
        }
    }
}
